import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers
import CryptoKit

// MARK: - Models (mirrors isle-core/src/clipboard.rs)
enum ClipKind: String, Codable, CaseIterable { case text, link, image, files }

struct ClipItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var kind: ClipKind
    var text: String?           // text or link content
    var imageHash: String?      // SHA256 hex of PNG data
    var imageWidth: Int?
    var imageHeight: Int?
    var fileURLs: [String]?     // file:// URIs
    var appName: String = ""
    var timestamp: Date = Date()
    var pinned: Bool = false

    var preview: String {
        switch kind {
        case .text, .link:
            return String((text ?? "").prefix(160))
        case .image:
            return "\(imageWidth ?? 0) × \(imageHeight ?? 0) image"
        case .files:
            return (fileURLs ?? []).map { URL(string: $0)?.lastPathComponent ?? $0 }.joined(separator: "\n")
        }
    }

    func contains(_ query: String) -> Bool {
        let q = query.lowercased()
        switch kind {
        case .text, .link: return (text ?? "").lowercased().contains(q)
        case .files: return preview.lowercased().contains(q) || (fileURLs ?? []).joined().lowercased().contains(q)
        case .image: return false
        }
    }
}

// MARK: - Manager
final class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    @Published var items: [ClipItem] = []
    @Published var query: String = ""

    private let maxUnpinned = 20
    private let maxPinned = 10
    private let maxTextBytes = 512 * 1024
    private let saveKey = "clipboardHistory"
    private var imageCache: [String: NSImage] = [:]
    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount

    private var imageDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Inertia", isDirectory: true)
        return base.appendingPathComponent("Clipboard", isDirectory: true)
    }

    private init() {
        load()
        let timer = Timer(timeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.poll()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    // MARK: Polling
    private func poll() {
        guard Store.shared.clipboardEnabled else {
            lastChangeCount = NSPasteboard.general.changeCount
            return
        }
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           urls.contains(where: \.isFileURL) {
            addFiles(urls, appName: appName)
        } else if let images = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage],
                  let image = images.first {
            addImage(image, appName: appName)
        } else if let strings = pasteboard.readObjects(forClasses: [NSString.self]) as? [String],
                  let text = strings.first,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard text.utf8.count <= maxTextBytes else { return }
            let kind: ClipKind = isLink(text) ? .link : .text
            add(ClipItem(kind: kind, text: text, appName: appName))
        }
    }

    func addImage(_ image: NSImage, appName: String) {
        guard let png = image.pngRepresentation else { return }
        let hash = SHA256.hash(data: png).map { String(format: "%02x", $0) }.joined()
        saveImage(png, hash: hash)
        imageCache[hash] = image
        let rep = image.representations.first
        add(ClipItem(kind: .image, imageHash: hash,
                     imageWidth: rep.map { Int($0.pixelsWide) },
                     imageHeight: rep.map { Int($0.pixelsHigh) },
                     appName: appName))
    }

    func addFiles(_ urls: [URL], appName: String) {
        let fileURIs = urls.filter(\.isFileURL).map(\.absoluteString)
        guard !fileURIs.isEmpty else { return }
        add(ClipItem(kind: .files, fileURLs: fileURIs, appName: appName))
    }

    private func isLink(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(" "), !trimmed.contains("\n") else { return false }
        return trimmed.hasPrefix("https://") || trimmed.hasPrefix("http://")
    }

    // MARK: Mutations
    func add(_ item: ClipItem) {
        if let index = items.firstIndex(where: { sameContent($0, item) }) {
            var existing = items.remove(at: index)
            existing.timestamp = Date()
            if existing.appName.isEmpty { existing.appName = item.appName }
            items.insert(existing, at: 0)
        } else {
            items.insert(item, at: 0)
            prune()
        }
        save()
        pruneImages()
    }

    func paste(_ item: ClipItem) {
        copyToClipboard(item)
        guard AXIsProcessTrusted() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            let source = CGEventSource(stateID: .hidSystemState)
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            let up = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            down?.flags = .maskCommand
            up?.flags = .maskCommand
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }

    func copyToClipboard(_ item: ClipItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch item.kind {
        case .text, .link:
            if let text = item.text { pasteboard.setString(text, forType: .string) }
        case .image:
            if let image = image(for: item) { pasteboard.writeObjects([image]) }
        case .files:
            let urls = (item.fileURLs ?? []).compactMap { URL(string: $0) } as [NSURL]
            if !urls.isEmpty { pasteboard.writeObjects(urls) }
        }
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func remove(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
        save()
        pruneImages()
    }

    func clear() {
        items.removeAll { !$0.pinned }
        save()
        pruneImages()
    }

    func eraseAll() {
        items.removeAll()
        query = ""
        save()
        imageCache.removeAll()
        try? FileManager.default.removeItem(at: imageDirectory)
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func togglePin(_ item: ClipItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let pinned = !items[index].pinned
        let pinCount = items.filter(\.pinned).count
        if pinned && pinCount >= maxPinned { return }
        items[index].pinned = pinned
        save()
    }

    func image(for item: ClipItem) -> NSImage? {
        guard let hash = item.imageHash else { return nil }
        if let cached = imageCache[hash] { return cached }
        let url = imageDirectory.appendingPathComponent("\(hash).png")
        guard let image = NSImage(contentsOf: url) else { return nil }
        imageCache[hash] = image
        return image
    }

    func fileIcon(for item: ClipItem, size: CGFloat = 22) -> NSImage? {
        guard let first = item.fileURLs?.first, let url = URL(string: first) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    var filtered: [ClipItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = q.isEmpty ? items : items.filter { $0.contains(q) }
        return matching.filter(\.pinned) + matching.filter { !$0.pinned }
    }

    var pinnedCount: Int { items.filter(\.pinned).count }

    // MARK: Image storage
    private func saveImage(_ data: Data, hash: String) {
        let fm = FileManager.default
        try? fm.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        let url = imageDirectory.appendingPathComponent("\(hash).png")
        if !fm.fileExists(atPath: url.path) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func pruneImages() {
        let referenced = Set(items.compactMap(\.imageHash))
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: imageDirectory, includingPropertiesForKeys: nil) else { return }
        for file in files where file.pathExtension == "png" {
            if !referenced.contains(file.deletingPathExtension().lastPathComponent) {
                try? fm.removeItem(at: file)
            }
        }
        imageCache = imageCache.filter { referenced.contains($0.key) }
    }

    // MARK: Private
    private func sameContent(_ a: ClipItem, _ b: ClipItem) -> Bool {
        switch (a.kind, b.kind) {
        case (.image, .image): return a.imageHash == b.imageHash
        case (.files, .files): return a.fileURLs == b.fileURLs
        default: return a.text != nil && a.text == b.text
        }
    }

    private func prune() {
        var unpinned = 0
        items = items.filter { item in
            if item.pinned { return true }
            unpinned += 1
            return unpinned <= maxUnpinned
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let saved = try? JSONDecoder().decode([ClipItem].self, from: data) else { return }
        items = saved
    }
}

// MARK: - NSImage PNG helper
extension NSImage {
    var pngRepresentation: Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
