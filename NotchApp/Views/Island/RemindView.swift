import SwiftUI

struct RemindView: View {
    @ObservedObject var store = Store.shared
    @State private var composing = false
    @State private var editID: UUID?
    private let tint = IslandTab.remind.tint

    private var sorted: [Reminder] {
        store.reminders.sorted { a, b in
            if a.active != b.active { return a.active }
            return a.date < b.date
        }
    }
    private var next: Reminder? { store.reminders.filter { $0.active }.min { $0.date < $1.date } }

    var body: some View {
        ZStack {
            if composing {
                ReminderComposer(editing: editID) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { composing = false; editID = nil }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                list.transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
    }

    private var list: some View {
        VStack(spacing: IslandLayout.verticalSpacing) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(tint.opacity(0.18)).frame(width: 34, height: 34)
                    Image(systemName: "bell.fill").font(.system(size: 14)).foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(next == nil ? "Nothing scheduled" : "Next up").font(.system(size: 14, weight: .semibold))
                    TimelineView(.periodic(from: .now, by: 15)) { _ in
                        Text(next.map { "\($0.title) · \(countdown(to: $0.date))" } ?? "Tap New to add a reminder")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                    }
                }
                Spacer()
                Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { editID = nil; composing = true } } label: {
                    Label("New", systemImage: "plus").font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 13).padding(.vertical, 7)
                        .foregroundStyle(.black).background(Capsule().fill(tint))
                        .contentShape(Capsule())
                }.buttonStyle(.plain)
            }
            if store.reminders.isEmpty {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "bell.badge").font(.system(size: 24)).foregroundStyle(tint)
                    Text("No reminders. Pick a time with the wheels, done in seconds.")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 7) {
                        ForEach(sorted) { r in
                            ReminderCard(r: r) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { editID = r.id; composing = true }
                            }
                        }
                    }
                    // FIX 2B: 16pt bottom so last card clears the panel's rounded corners.
                    .padding(.bottom, 16)
                    .animation(.inertiaLiquid(speed: store.animSpeed, reduceMotion: false), value: store.reminders.map { $0.id })
                }
            }
        }
    }
}

struct ReminderCard: View {
    let r: Reminder
    let onEdit: () -> Void
    @ObservedObject var store = Store.shared
    private let tint = IslandTab.remind.tint

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(r.time.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 17, weight: .semibold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(r.active ? tint : Color.white.opacity(0.35))
                TimelineView(.periodic(from: .now, by: 15)) { _ in
                    Text(r.active ? countdown(to: r.date) : (r.kind == .once && r.date <= Date() ? "Done" : "Off"))
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(width: 86, alignment: .leading)
            Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: r.kind == .once ? "calendar" : "repeat").font(.system(size: 9))
                    Text(r.summary).lineLimit(1)
                    if !r.sound { Image(systemName: "speaker.slash.fill").font(.system(size: 9)) }
                }
                .font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Toggle("", isOn: Binding(get: { r.active }, set: { _ in store.toggleReminder(r.id) }))
                .toggleStyle(.switch).controlSize(.mini).labelsHidden().tint(tint)
            IconButton(symbol: "trash", size: 24, danger: true) {
                withAnimation { store.reminders.removeAll { $0.id == r.id } }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .inertiaGlassBackground(cornerRadius: 14, showsStroke: true, tint: tint, gloss: 0.7)
        .opacity(r.active ? 1 : 0.6)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }
}

// MARK: - Composer
struct ReminderComposer: View {
    let editing: UUID?
    let close: () -> Void
    @ObservedObject var store = Store.shared
    @State private var title = ""
    @State private var hour = 9          // 1...12
    @State private var minute = 0
    @State private var pm = false
    @State private var kind = RemindKind.once
    @State private var days: Set<Int> = [2, 3, 4, 5, 6]
    @State private var day = Date()
    @State private var sound = true
    @FocusState private var titleFocus: Bool
    private let tint = IslandTab.remind.tint
    private let cal = Calendar.current
    private let order = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        let when = resolved()
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                IconButton(symbol: "chevron.left", size: 28) { close() }
                TextField("What should I remind you about?", text: $title)
                    .textFieldStyle(.plain).font(.system(size: 14, weight: .medium))
                    .focused($titleFocus).onSubmit(save)
                    .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .glass(14)
                IconButton(symbol: sound ? "speaker.wave.2.fill" : "speaker.slash.fill", size: 28,
                           tint: sound ? tint : nil) { sound.toggle() }
                    .help("Speak the reminder aloud")
            }

            HStack(alignment: .center, spacing: 16) {
                HStack(spacing: 6) {
                    WheelPicker(value: $hour, range: 1...12, tint: tint, format: { "\($0)" })
                    Text(":").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(tint).offset(y: -2)
                    WheelPicker(value: $minute, range: 0...59, tint: tint)
                    VStack(spacing: 6) {
                        ampm("AM", !pm) { pm = false }
                        ampm("PM", pm) { pm = true }
                    }
                }
                quick
            }
            .padding(8).glass(18)

            HStack(spacing: 6) {
                ForEach(RemindKind.allCases, id: \.self) { k in
                    Chip(text: k == .days ? "Custom days" : k.label, on: kind == k, tint: tint) { withAnimation { kind = k } }
                }
                Spacer()
            }

            detail

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Image(systemName: when != nil ? "bell.badge.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 12)).foregroundStyle(when != nil ? tint : Color.orange)
                Text(previewText(when)).font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.72)).lineLimit(1)
                Spacer()
                PillButton(editing == nil ? "Add reminder" : "Save", tint: tint, action: save)
                    .disabled(when == nil).opacity(when == nil ? 0.4 : 1)
            }
        }
        .onAppear(perform: load)
    }

    // MARK: pieces
    private func ampm(_ label: String, _ on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.system(size: 11, weight: .bold))
                .frame(width: 40, height: 26)
                .foregroundStyle(on ? Color.black : Color.white.opacity(0.6))
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(on ? tint : Color.white.opacity(0.08)))
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private var quick: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("QUICK SET").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.white.opacity(0.4))
            HStack(spacing: 5) {
                Chip(text: "+10 min", tint: tint) { preset(minutes: 10) }
                Chip(text: "+30 min", tint: tint) { preset(minutes: 30) }
                Chip(text: "+1 hr", tint: tint) { preset(minutes: 60) }
            }
            HStack(spacing: 5) {
                Chip(text: "Tonight 8 PM", tint: tint) { preset(hour24: 20, tomorrow: false) }
                Chip(text: "Tomorrow 9 AM", tint: tint) { preset(hour24: 9, tomorrow: true) }
            }
            HStack(spacing: 5) {
                Text("Minute").font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                ForEach([0, 15, 30, 45], id: \.self) { m in
                    Chip(text: String(format: ":%02d", m), on: minute == m, tint: tint) { minute = m }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var detail: some View {
        switch kind {
        case .once:
            HStack(spacing: 8) {
                IconButton(symbol: "chevron.left", size: 24) { day = cal.date(byAdding: .day, value: -1, to: day) ?? day }
                Text(dayLabel).font(.system(size: 12, weight: .semibold)).frame(width: 116)
                IconButton(symbol: "chevron.right", size: 24) { day = cal.date(byAdding: .day, value: 1, to: day) ?? day }
                Chip(text: "Today", on: cal.isDateInToday(day), tint: tint) { day = Date() }
                Chip(text: "Tomorrow", on: cal.isDateInTomorrow(day), tint: tint) {
                    day = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                }
                Spacer()
            }
        case .daily:
            HStack {
                Image(systemName: "repeat").font(.system(size: 11)).foregroundStyle(tint)
                Text("Repeats every day at the chosen time.").font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.6))
                Spacer()
            }
        case .days:
            HStack(spacing: 5) {
                ForEach(order, id: \.self) { d in
                    Chip(text: cal.veryShortWeekdaySymbols[d - 1], on: days.contains(d), tint: tint) {
                        if days.contains(d) { days.remove(d) } else { days.insert(d) }
                    }
                }
                Chip(text: "Weekdays", tint: tint) { days = [2, 3, 4, 5, 6] }
                Chip(text: "Weekend", tint: tint) { days = [1, 7] }
                Spacer()
            }
        }
    }

    private var dayLabel: String {
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    // MARK: logic
    private func setTime(_ d: Date) {
        let c = cal.dateComponents([.hour, .minute], from: d)
        let h = c.hour ?? 9
        pm = h >= 12
        hour = (h % 12 == 0) ? 12 : h % 12
        minute = c.minute ?? 0
        day = d
    }
    private func preset(minutes: Int) {
        kind = .once
        setTime(Date().addingTimeInterval(Double(minutes) * 60))
    }
    private func preset(hour24: Int, tomorrow: Bool) {
        kind = .once
        var d = cal.date(bySettingHour: hour24, minute: 0, second: 0, of: Date()) ?? Date()
        if tomorrow || d <= Date() { d = cal.date(byAdding: .day, value: 1, to: d) ?? d }
        setTime(d)
    }

    private var hour24: Int { (hour % 12) + (pm ? 12 : 0) }

    private func resolved() -> Date? {
        let time = cal.date(bySettingHour: hour24, minute: minute, second: 0, of: Date()) ?? Date()
        let probe = Reminder(title: "", kind: kind, time: time, date: Date(), days: days.sorted())
        switch kind {
        case .once:
            let at = cal.date(bySettingHour: hour24, minute: minute, second: 0, of: day) ?? day
            if at > Date() { return at }
            return cal.isDateInToday(day) ? probe.nextOccurrence() : nil   // today but already passed: ring tomorrow
        case .daily:
            return probe.nextOccurrence()
        case .days:
            return days.isEmpty ? nil : probe.nextOccurrence()
        }
    }

    private func previewText(_ d: Date?) -> String {
        guard let d = d else { return kind == .days && days.isEmpty ? "Pick at least one day" : "That time has passed. Pick a later one." }
        let f = d.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
        return "Rings \(f) · \(countdown(to: d))"
    }

    private func load() {
        if let id = editing, let r = store.reminders.first(where: { $0.id == id }) {
            title = r.title; kind = r.kind; sound = r.sound
            days = Set(r.days.isEmpty ? [2, 3, 4, 5, 6] : r.days)
            let c = cal.dateComponents([.hour, .minute], from: r.time)
            let h = c.hour ?? 9
            pm = h >= 12
            hour = (h % 12 == 0) ? 12 : h % 12
            minute = c.minute ?? 0
            day = r.date
        } else {
            setTime(Date().addingTimeInterval(30 * 60))
            DispatchQueue.main.async { titleFocus = true }
        }
    }

    private func save() {
        guard let when = resolved() else { return }
        let time = cal.date(bySettingHour: hour24, minute: minute, second: 0, of: Date()) ?? Date()
        let t = title.trimmingCharacters(in: .whitespaces)
        let r = Reminder(id: editing ?? UUID(), title: t.isEmpty ? "Reminder" : t, kind: kind, time: time, date: when,
                         days: kind == .days ? days.sorted() : [], active: true, sound: sound)
        store.upsertReminder(r)
        close()
    }
}
