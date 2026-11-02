import Foundation
import SwiftUI
import AppKit
import Combine
import EventKit

// MARK: - Models

enum CalendarAccess: Equatable {
    case notDetermined, granted, denied, restricted
}

struct CalEvent: Identifiable {
    var id: String
    var title: String
    var start: Date
    var end: Date
    var allDay: Bool
    var location: String
    var notes: String
    var calendarName: String
    var color: Color
    var url: URL?
    var joinURL: URL?
    var externalID: String?
    var localID: UUID?

    var isLocal: Bool { localID != nil }
}

struct LocalCalEvent: Codable, Identifiable {
    var id = UUID()
    var title: String
    var start: Date
    var end: Date
    var allDay: Bool
    var meetingURL: String?
}

// MARK: - Engine

final class CalendarEngine: ObservableObject {
    static let shared = CalendarEngine()

    @Published var access: CalendarAccess = .notDetermined
    @Published var events: [CalEvent] = []
    @Published var selectedDate = Date()
    @Published var visibleMonth = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: Date())
    ) ?? Date()
    @Published private(set) var localEvents: [LocalCalEvent] = []

    private let store = EKEventStore()
    private let localKey = "localCalendarEvents"
    private var observer: NSObjectProtocol?
    private var started = false

    private init() {
        loadLocal()
        access = CalendarEngine.map(EKEventStore.authorizationStatus(for: .event))
    }

    func start() {
        guard !started else { return }
        started = true
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            self?.reload()
        }
        reload()
    }

    func requestAccess() {
        store.requestFullAccessToEvents { [weak self] granted, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.access = granted ? .granted : .denied
                self.reload()
            }
        }
    }

    func reload() {
        let cal = Calendar.current
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: visibleMonth)) ?? visibleMonth
        let start = cal.date(byAdding: .day, value: -7, to: monthStart) ?? monthStart
        let end = cal.date(byAdding: .day, value: 45, to: monthStart) ?? monthStart

        var result: [CalEvent] = []
        if access == .granted {
            let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
            for event in store.events(matching: predicate) {
                result.append(CalendarEngine.mapEvent(event))
            }
        }
        for event in localEvents where event.start >= start && event.start < end {
            result.append(CalendarEngine.mapLocal(event))
        }

        events = result.sorted {
            if $0.allDay != $1.allDay { return $0.allDay }
            return $0.start < $1.start
        }
    }

    func events(on date: Date) -> [CalEvent] {
        let cal = Calendar.current
        return events.filter { event in
            if event.allDay {
                return cal.isDate(event.start, inSameDayAs: date)
            }
            return cal.isDate(event.start, inSameDayAs: date)
        }
    }

    func hasEvents(on date: Date) -> Bool {
        let cal = Calendar.current
        return events.contains { cal.isDate($0.start, inSameDayAs: date) }
    }

    func eventsStarting(within interval: TimeInterval) -> [CalEvent] {
        let now = Date()
        let end = now.addingTimeInterval(interval)
        var result: [CalEvent] = []
        if access == .granted {
            let predicate = store.predicateForEvents(
                withStart: now.addingTimeInterval(-60), end: end, calendars: nil
            )
            for event in store.events(matching: predicate) where !event.isAllDay {
                result.append(CalendarEngine.mapEvent(event))
            }
        }
        for event in localEvents where !event.allDay && event.start >= now && event.start <= end {
            result.append(CalendarEngine.mapLocal(event))
        }
        return result.sorted { $0.start < $1.start }
    }

    @discardableResult
    func addEvent(_ text: String, on date: Date) -> CalEvent? {
        guard let parsed = EventParser.parse(text) else { return nil }
        let startMinutes = parsed.startMinutes ?? 0
        let start = CalendarEngine.combine(date, minutes: startMinutes)
        var end = CalendarEngine.combine(date, minutes: parsed.endMinutes ?? startMinutes + 60)
        if end <= start { end = start.addingTimeInterval(3600) }
        let allDay = parsed.startMinutes == nil
        let actualStart = allDay ? Calendar.current.startOfDay(for: date) : start
        let actualEnd = allDay ? Calendar.current.date(byAdding: .day, value: 1, to: actualStart) ?? actualStart.addingTimeInterval(86400) : end
        let link = parsed.meetingURL

        if access == .granted {
            let ek = EKEvent(eventStore: store)
            ek.title = parsed.title
            ek.startDate = actualStart
            ek.endDate = actualEnd
            ek.isAllDay = allDay
            ek.calendar = store.defaultCalendarForNewEvents
            if let link { ek.url = link }
            do {
                try store.save(ek, span: .thisEvent)
                reload()
                return CalendarEngine.mapEvent(ek)
            } catch {
                NSLog("Inertia calendar save failed: \(error)")
            }
        }

        let local = LocalCalEvent(title: parsed.title, start: actualStart, end: actualEnd,
                                  allDay: allDay, meetingURL: link?.absoluteString)
        localEvents.append(local)
        saveLocal()
        reload()
        return CalendarEngine.mapLocal(local)
    }

    func remove(_ event: CalEvent) {
        if let id = event.localID {
            localEvents.removeAll { $0.id == id }
            saveLocal()
            reload()
            return
        }
        if let externalID = event.externalID,
           let ek = store.event(withIdentifier: externalID) {
            try? store.remove(ek, span: .thisEvent)
            reload()
        }
    }

    func eraseLocalEvents() {
        localEvents.removeAll()
        UserDefaults.standard.removeObject(forKey: localKey)
        reload()
    }

    // MARK: Mapping

    private static func map(_ status: EKAuthorizationStatus) -> CalendarAccess {
        switch status {
        case .fullAccess: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        case .writeOnly: return .denied
        @unknown default: return .notDetermined
        }
    }

    private static func mapEvent(_ event: EKEvent) -> CalEvent {
        let text = [event.location, event.notes, event.url?.absoluteString]
            .compactMap { $0 }
            .joined(separator: "\n")
        return CalEvent(
            id: event.eventIdentifier ?? UUID().uuidString,
            title: event.title ?? "Untitled event",
            start: event.startDate,
            end: event.endDate,
            allDay: event.isAllDay,
            location: event.location ?? "",
            notes: event.notes ?? "",
            calendarName: event.calendar?.title ?? "Calendar",
            color: event.calendar.map { Color(nsColor: $0.color) } ?? IslandTab.calendar.tint,
            url: event.url,
            joinURL: CalendarEngine.meetingLink(in: text),
            externalID: event.eventIdentifier,
            localID: nil
        )
    }

    private static func mapLocal(_ event: LocalCalEvent) -> CalEvent {
        CalEvent(
            id: "local-\(event.id.uuidString)",
            title: event.title,
            start: event.start,
            end: event.end,
            allDay: event.allDay,
            location: "",
            notes: "",
            calendarName: "Inertia",
            color: IslandTab.calendar.tint,
            url: event.meetingURL.flatMap(URL.init(string:)),
            joinURL: event.meetingURL.flatMap(URL.init(string:)),
            externalID: nil,
            localID: event.id
        )
    }

    private static func combine(_ date: Date, minutes: Int) -> Date {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        return cal.date(byAdding: .minute, value: minutes, to: start) ?? date
    }

    static func meetingLink(in text: String) -> URL? {
        guard let regex = try? NSRegularExpression(pattern: #"https?://[^\s<>"']+"#, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        let hosts = ["meet.google.com", "zoom.us", "teams.microsoft.com", "teams.live.com",
                     "webex.com", "whereby.com", "meet.jit.si", "discord.gg"]
        for match in regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length)) {
            var raw = ns.substring(with: match.range)
            while raw.hasSuffix(".") || raw.hasSuffix(",") || raw.hasSuffix(")") { raw.removeLast() }
            guard let url = URL(string: raw), let host = url.host?.lowercased() else { continue }
            if hosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) {
                return url
            }
        }
        return nil
    }

    // MARK: Local persistence

    private func loadLocal() {
        guard let data = UserDefaults.standard.data(forKey: localKey),
              let saved = try? JSONDecoder().decode([LocalCalEvent].self, from: data) else { return }
        localEvents = saved
    }

    private func saveLocal() {
        if let data = try? JSONEncoder().encode(localEvents) {
            UserDefaults.standard.set(data, forKey: localKey)
        }
    }
}

// MARK: - Simple natural-language event parser
// Port of isle-core/src/calendar.rs: "Dinner 8:00 pm", "Standup 9:00-9:15",
// "Gym at 7pm" or "Holiday" (all day).

enum EventParser {
    struct Parsed {
        var title: String
        var startMinutes: Int?
        var endMinutes: Int?
        var meetingURL: URL?
    }

    private static let prepWords: Set<String> = ["at", "@", "from", "jam", "pukul", "pkl", "dari", "mulai"]
    private static let rangeWords = #"(?:-|–|—|to|until|till|sampai|hingga)"#
    private static let clockPattern = #"(\d{1,2})(?::|\.)(\d{2})\s*(am|pm)?"#
    private static let hourPattern = #"(\d{1,2})\s*(am|pm)"#
    private static let bareHourPattern = #"(?i)\b(?:at|@|jam|pukul|from)\s+(\d{1,2})\b"#

    static func parse(_ text: String) -> Parsed? {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let ns = raw as NSString
        let full = NSRange(location: 0, length: ns.length)

        let rangePattern = #"(\d{1,2})(?:(?::|\.)(\d{2}))?\s*(am|pm)?\s*"# + rangeWords + #"\s*(\d{1,2})(?:(?::|\.)(\d{2}))?\s*(am|pm)?"#
        if let regex = try? NSRegularExpression(pattern: rangePattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: raw, options: [], range: full) {
            let h1 = int(ns, match, 1), m1 = int(ns, match, 2), mer1 = string(ns, match, 3)
            let h2 = int(ns, match, 4), m2 = int(ns, match, 5), mer2 = string(ns, match, 6)
            let prefix = ns.substring(to: match.range.location).trimmingCharacters(in: .whitespaces)
            let hasPrep = prefix.split(whereSeparator: { $0.isWhitespace }).last
                .map { prepWords.contains(String($0).lowercased()) } ?? false
            if m1 != nil || m2 != nil || mer1 != nil || mer2 != nil || hasPrep {
                var start = clock(h1, m1 ?? 0, mer1)
                var end = clock(h2, m2 ?? 0, mer2)
                if mer1 == nil, let mer2, let e = end {
                    if let same = clock(h1, m1 ?? 0, mer2), same < e {
                        start = same
                    } else if let am = clock(h1, m1 ?? 0, "am"), am < e {
                        start = am
                    } else {
                        start = clock(h1, m1 ?? 0, "pm")
                    }
                } else if mer1 != nil, mer2 == nil {
                    let other = mer1?.lowercased() == "am" ? "pm" : "am"
                    if let s = start, let e = end, e <= s, let flipped = clock(h2, m2 ?? 0, other) {
                        end = flipped
                    }
                }
                if let s = start, var e = end {
                    if e <= s { e += 24 * 60 }
                    if e - s <= 24 * 60 { return finish(raw, ns, match.range, s, e) }
                }
            }
        }

        if let regex = try? NSRegularExpression(pattern: clockPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: raw, options: [], range: full),
           let start = clock(int(ns, match, 1), int(ns, match, 2) ?? 0, string(ns, match, 3)) {
            return finish(raw, ns, match.range, start, nil)
        }

        if let regex = try? NSRegularExpression(pattern: hourPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: raw, options: [], range: full),
           let start = clock(int(ns, match, 1), 0, string(ns, match, 2)) {
            return finish(raw, ns, match.range, start, nil)
        }

        if let regex = try? NSRegularExpression(pattern: bareHourPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: raw, options: [], range: full),
           let hour = int(ns, match, 1), (0...23).contains(hour) {
            return finish(raw, ns, match.range, hour * 60, nil)
        }

        let title = raw.trimmingCharacters(in: CharacterSet(charactersIn: " ,-–—"))
        guard !title.isEmpty else { return nil }
        return Parsed(title: String(title.prefix(200)), startMinutes: nil, endMinutes: nil,
                      meetingURL: CalendarEngine.meetingLink(in: raw))
    }

    private static func finish(_ raw: String, _ ns: NSString, _ range: NSRange,
                               _ start: Int, _ end: Int?) -> Parsed? {
        var removeStart = range.location
        let prefix = ns.substring(to: range.location).trimmingCharacters(in: .whitespaces)
        if let last = prefix.split(whereSeparator: { $0.isWhitespace }).last,
           prepWords.contains(String(last).lowercased()) {
            removeStart = max(0, range.location - (String(last).count + 1))
        }
        let removeEnd = range.location + range.length
        var title = ns.substring(to: removeStart) + ns.substring(from: min(removeEnd, ns.length))
        title = title.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        title = title.trimmingCharacters(in: CharacterSet(charactersIn: " ,-–—;"))
        guard !title.isEmpty else { return nil }
        return Parsed(title: String(title.prefix(200)), startMinutes: start,
                      endMinutes: end, meetingURL: CalendarEngine.meetingLink(in: raw))
    }

    private static func clock(_ hour: Int?, _ minute: Int, _ meridiem: String?) -> Int? {
        guard var hour, (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        if let meridiem = meridiem?.lowercased() {
            guard (1...12).contains(hour) else { return nil }
            hour = hour % 12 + (meridiem == "pm" ? 12 : 0)
        }
        return hour * 60 + minute
    }

    private static func int(_ ns: NSString, _ match: NSTextCheckingResult, _ group: Int) -> Int? {
        guard group < match.numberOfRanges else { return nil }
        let range = match.range(at: group)
        guard range.location != NSNotFound else { return nil }
        return Int(ns.substring(with: range))
    }

    private static func string(_ ns: NSString, _ match: NSTextCheckingResult, _ group: Int) -> String? {
        guard group < match.numberOfRanges else { return nil }
        let range = match.range(at: group)
        guard range.location != NSNotFound else { return nil }
        return ns.substring(with: range)
    }
}
