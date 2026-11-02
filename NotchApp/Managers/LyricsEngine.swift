import Foundation
import AppKit

// MARK: - Models
struct LyricLine: Equatable {
    let timeMs: Int   // -1 = plain (no timestamp)
    let text: String
}

enum LyricsStatus: Equatable {
    case none, loading, synced, plain, instrumental, notFound, error, off
}

struct LyricsResult: Equatable {
    var trackKey: String = ""
    var status: LyricsStatus = .none
    var lines: [LyricLine] = []
}

// MARK: - LRC parser (mirrors isle-core/src/lrc.rs)
enum LRC {
    static func parse(_ source: String) -> [LyricLine] {
        var offsetMs = 0
        var lines: [LyricLine] = []
        for raw in source.components(separatedBy: "\n") {
            var rest = raw.trimmingCharacters(in: .whitespaces)
            var times: [Int] = []
            while rest.hasPrefix("["), let close = rest.firstIndex(of: "]") {
                let tag = String(rest[rest.index(after: rest.startIndex)..<close])
                if let t = parseTimestamp(tag) {
                    times.append(t)
                } else if let val = tag.hasPrefix("offset:") ? String(tag.dropFirst(7)).trimmingCharacters(in: .whitespaces) : nil,
                          let off = Int(val) {
                    offsetMs = off
                }
                rest = String(rest[rest.index(after: close)...]).trimmingCharacters(in: .whitespaces)
            }
            let text = rest.trimmingCharacters(in: .whitespaces)
            for t in times {
                lines.append(LyricLine(timeMs: max(0, t - offsetMs), text: text))
            }
        }
        return lines.sorted { $0.timeMs < $1.timeMs }
    }

    static func plain(_ source: String) -> [LyricLine] {
        source.components(separatedBy: "\n").map { LyricLine(timeMs: -1, text: $0.trimmingCharacters(in: .whitespaces)) }
    }

    private static func parseTimestamp(_ tag: String) -> Int? {
        guard let colon = tag.firstIndex(of: ":") else { return nil }
        let minutes = Int(tag[tag.startIndex..<colon]) ?? -1
        let rest = String(tag[tag.index(after: colon)...])
        let parts = rest.components(separatedBy: CharacterSet(charactersIn: ".:"))
        guard parts.count >= 1, let whole = Int(parts[0]), minutes >= 0, (0..<60).contains(whole) else { return nil }
        let fraction: Int
        if parts.count >= 2 {
            let f = parts[1]
            fraction = f.count == 1 ? (Int(f) ?? 0) * 100
                     : f.count == 2 ? (Int(f) ?? 0) * 10
                     : Int(String(f.prefix(3))) ?? 0
        } else { fraction = 0 }
        guard let ms = checkedAdd(checkedMul(minutes, 60000), whole * 1000 + fraction) else { return nil }
        return ms
    }

    private static func checkedMul(_ a: Int, _ b: Int) -> Int? {
        let (result, overflow) = a.multipliedReportingOverflow(by: b)
        return overflow ? nil : result
    }
    private static func checkedAdd(_ a: Int?, _ b: Int) -> Int? {
        guard let a = a else { return nil }
        let (result, overflow) = a.addingReportingOverflow(b)
        return overflow ? nil : result
    }
}

// MARK: - LRCLIB fetch (mirrors isle-daemon/src/media/lyrics.rs)
extension Store {
    private static let lyricsQ = DispatchQueue(label: "inertia.lyrics", qos: .utility)
    private static let lyricsCache = NSCache<NSString, AnyObject>()
    private static let NOT_FOUND_RETRY: TimeInterval = 7 * 24 * 60 * 60
    private static let LRCLIB = "https://lrclib.net/api"

    func fetchLyrics(for np: NowPlaying) {
        guard showLyrics else { lyrics = LyricsResult(status: .off); return }
        let title = np.title.trimmingCharacters(in: .whitespaces)
        let artist = np.artist.trimmingCharacters(in: .whitespaces)
        let duration = np.duration
        guard !title.isEmpty, !artist.isEmpty else {
            lyrics = LyricsResult(status: .notFound); return
        }
        let key = "\(artist)\u{1f}\(title)\u{1f}\(Int(duration))"
        if lyrics.trackKey == key { return }  // already showing correct track
        lyrics = LyricsResult(trackKey: key, status: .loading)

        Store.lyricsQ.async { [weak self] in
            let result = Store.lookupLyrics(title: title, artist: artist, duration: duration, key: key)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.lyrics.trackKey == key else { return }
                self.lyrics = result
            }
        }
    }

    private static func lookupLyrics(title: String, artist: String, duration: Double, key: String) -> LyricsResult {
        // Check disk cache
        let cacheURL = lyricsCachePath(key: key)
        if let cached = loadCachedLyrics(at: cacheURL, key: key) { return cached }

        // 1. Exact match
        if duration >= 0.5 {
            if let record = lrclibGet(endpoint: "get", params: [
                "track_name": title, "artist_name": artist,
                "album_name": "", "duration": "\(Int(duration))"
            ]), hasLyrics(record) {
                return saveLyrics(fromRecord: record, key: key, cacheURL: cacheURL)
            }
        }

        // 2. Search
        if let results = lrclibSearch(params: ["track_name": title, "artist_name": artist]),
           let best = bestMatch(results, duration: duration, artist: artist, strict: false) {
            return saveLyrics(fromRecord: best, key: key, cacheURL: cacheURL)
        }

        let miss = LyricsResult(trackKey: key, status: .notFound)
        saveToDisk(miss, at: cacheURL)
        return miss
    }

    // MARK: LRCLIB HTTP
    private struct LRCRecord: Decodable {
        let artistName: String?
        let syncedLyrics: String?
        let plainLyrics: String?
        let instrumental: Bool?
        let duration: Double?
        var isInstrumental: Bool { instrumental ?? false }
    }

    private static func lrclibGet(endpoint: String, params: [String: String]) -> LRCRecord? {
        var comps = URLComponents(string: "\(LRCLIB)/\(endpoint)")!
        comps.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = comps.url else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("Inertia/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        let sem = DispatchSemaphore(value: 0)
        var result: LRCRecord?
        URLSession.shared.dataTask(with: req) { data, resp, _ in
            defer { sem.signal() }
            guard let data,
                  let code = (resp as? HTTPURLResponse)?.statusCode, code == 200 else { return }
            result = try? JSONDecoder().decode(LRCRecord.self, from: data)
        }.resume()
        sem.wait()
        return result
    }

    private static func lrclibSearch(params: [String: String]) -> [LRCRecord]? {
        var comps = URLComponents(string: "\(LRCLIB)/search")!
        comps.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = comps.url else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("Inertia/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        let sem = DispatchSemaphore(value: 0)
        var result: [LRCRecord]?
        URLSession.shared.dataTask(with: req) { data, resp, _ in
            defer { sem.signal() }
            guard let data,
                  let code = (resp as? HTTPURLResponse)?.statusCode, code == 200 else { return }
            result = try? JSONDecoder().decode([LRCRecord].self, from: data)
        }.resume()
        sem.wait()
        return result
    }

    private static func hasLyrics(_ r: LRCRecord) -> Bool {
        (r.syncedLyrics.map { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? false)
        || (r.plainLyrics.map { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? false)
        || r.isInstrumental
    }

    private static func bestMatch(_ records: [LRCRecord], duration: Double, artist: String, strict: Bool) -> LRCRecord? {
        let tolerance = 3.0
        func fits(_ r: LRCRecord) -> Bool {
            guard let d = r.duration else { return true }
            return abs(d - duration) <= tolerance
        }
        func sameArtist(_ r: LRCRecord) -> Bool {
            guard !artist.isEmpty, let a = r.artistName else { return false }
            return a.lowercased().contains(artist.lowercased())
        }
        return records
            .filter { hasLyrics($0) && (!strict || fits($0)) }
            .max { a, b in
                let sa = (sameArtist(a), fits(a), a.syncedLyrics != nil)
                let sb = (sameArtist(b), fits(b), b.syncedLyrics != nil)
                // Lexicographic compare on tuples of Bool
                if sa.0 != sb.0 { return !sa.0 }
                if sa.1 != sb.1 { return !sa.1 }
                return !sa.2 && sb.2
            }
    }

    private static func saveLyrics(fromRecord r: LRCRecord, key: String, cacheURL: URL) -> LyricsResult {
        let synced = r.syncedLyrics.map { LRC.parse($0) } ?? []
        let (status, lines): (LyricsStatus, [LyricLine])
        if !synced.isEmpty {
            status = .synced; lines = synced
        } else if let plain = r.plainLyrics, !plain.trimmingCharacters(in: .whitespaces).isEmpty {
            status = .plain; lines = LRC.plain(plain)
        } else if r.isInstrumental {
            status = .instrumental; lines = []
        } else {
            status = .notFound; lines = []
        }
        let result = LyricsResult(trackKey: key, status: status, lines: lines)
        saveToDisk(result, at: cacheURL)
        return result
    }

    // MARK: Disk cache
    private static func lyricsCachePath(key: String) -> URL {
        let hash = fnv1a(key)
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Inertia/lyrics")
        return dir.appendingPathComponent("\(hash).json")
    }

    private static func fnv1a(_ s: String) -> String {
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 { h = (h ^ UInt64(b)).multipliedReportingOverflow(by: 0x100000001b3).partialValue }
        return String(format: "%016llx", h)
    }

    private static func loadCachedLyrics(at url: URL, key: String) -> LyricsResult? {
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let statusRaw = obj["status"] as? String else { return nil }
        // Expire not-found entries after a week
        if statusRaw == "notFound",
           let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let mod = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(mod) >= NOT_FOUND_RETRY { return nil }
        let status: LyricsStatus
        switch statusRaw {
        case "synced":       status = .synced
        case "plain":        status = .plain
        case "instrumental": status = .instrumental
        case "notFound":     status = .notFound
        default:             return nil
        }
        let rawLines = obj["lines"] as? [[String: Any]] ?? []
        let lines = rawLines.compactMap { d -> LyricLine? in
            guard let t = d["timeMs"] as? Int, let text = d["text"] as? String else { return nil }
            return LyricLine(timeMs: t, text: text)
        }
        return LyricsResult(trackKey: key, status: status, lines: lines)
    }

    private static func saveToDisk(_ result: LyricsResult, at url: URL) {
        let statusRaw: String
        switch result.status {
        case .synced:       statusRaw = "synced"
        case .plain:        statusRaw = "plain"
        case .instrumental: statusRaw = "instrumental"
        case .notFound:     statusRaw = "notFound"
        default:            return  // don't cache transient states
        }
        let obj: [String: Any] = [
            "status": statusRaw,
            "lines": result.lines.map { ["timeMs": $0.timeMs, "text": $0.text] }
        ]
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(withJSONObject: obj) {
            try? data.write(to: url)
        }
    }
}
