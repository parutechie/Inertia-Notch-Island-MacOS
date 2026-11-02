import SwiftUI
import AppKit

// MARK: - Calendar tab
struct CalendarView: View {
    @ObservedObject private var engine = CalendarEngine.shared
    @State private var draft = ""
    @FocusState private var adding: Bool

    private let tint = IslandTab.calendar.tint

    var body: some View {
        VStack(spacing: IslandLayout.verticalSpacing) {
            if engine.access != .granted { accessBanner }
            HStack(spacing: 12) {
                monthPanel
                Rectangle().fill(.white.opacity(0.08)).frame(width: 1)
                dayPanel
            }
        }
        // Clear the panel's rounded bottom corners so the input row never sits
        // flush against the curve.
        .padding(.bottom, IslandLayout.contentInset)
        .onAppear {
            engine.selectedDate = Date()
            engine.visibleMonth = Calendar.current.date(
                from: Calendar.current.dateComponents([.year, .month], from: Date())
            ) ?? Date()
            engine.reload()
        }
    }

    // MARK: Month grid

    private var monthPanel: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text(engine.visibleMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 13.5, weight: .semibold))
                Spacer(minLength: 2)
                monthButton("chevron.left") { shiftMonth(-1) }
                monthButton("arrow.uturn.backward") { goToday() }.help("Today")
                monthButton("chevron.right") { shiftMonth(1) }
            }

            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: dayRowHeight)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(width: 238)
    }

    private func dayCell(_ day: Date) -> some View {
        let cal = Calendar.current
        let selected = cal.isDate(day, inSameDayAs: engine.selectedDate)
        let today = cal.isDateInToday(day)
        let events = engine.events(on: day)
        return Button {
            engine.selectedDate = day
        } label: {
            VStack(spacing: 1) {
                Text("\(cal.component(.day, from: day))")
                    .font(.system(size: 11, weight: today ? .bold : .medium, design: .rounded))
                    .foregroundStyle(today && !selected ? tint : Color.white.opacity(selected ? 1 : 0.78))
                HStack(spacing: 2) {
                    ForEach(Array(events.prefix(3))) { event in
                        Circle().fill(event.color).frame(width: 3, height: 3)
                    }
                }
                .frame(height: 3)
            }
            .frame(maxWidth: .infinity).frame(height: dayRowHeight)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? tint.opacity(0.22) : (today ? .white.opacity(0.06) : .clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(selected ? tint.opacity(0.7) : .clear, lineWidth: 0.8)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Day panel

    private var dayPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(engine.selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
                Spacer(minLength: 0)
                if engine.access == .granted {
                    Image(systemName: "checkmark.icloud")
                        .font(.system(size: 9.5)).foregroundStyle(.white.opacity(0.3))
                        .help("Apple Calendar connected")
                } else {
                    Text("Local").font(.system(size: 9, weight: .bold))
                        .foregroundStyle(tint.opacity(0.8))
                }
            }

            if dayEvents.isEmpty {
                VStack(spacing: 5) {
                    Spacer()
                    Image(systemName: "calendar.badge.plus").font(.system(size: 20)).foregroundStyle(tint.opacity(0.8))
                    Text("Nothing scheduled").font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.5))
                    Text("Type below, e.g. “Dinner 8:00 pm”.").font(.system(size: 9.5)).foregroundStyle(.white.opacity(0.3))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 5) {
                        ForEach(dayEvents) { event in
                            eventRow(event)
                        }
                    }
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "plus").font(.system(size: 9, weight: .bold)).foregroundStyle(tint)
                TextField("Dinner 8:00 pm", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                    .focused($adding)
                    .onSubmit(add)
                if !draft.isEmpty {
                    Button(action: add) {
                        Image(systemName: "arrow.turn.down.left")
                            .font(.system(size: 9, weight: .bold)).foregroundStyle(.black)
                            .frame(width: 20, height: 20).background(Circle().fill(tint))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9).padding(.vertical, 6).glass(12)
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(adding ? tint.opacity(0.5) : .white.opacity(0.07), lineWidth: 0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func eventRow(_ event: CalEvent) -> some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 2).fill(event.color).frame(width: 2.5)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title).font(.system(size: 11.5, weight: .semibold)).lineLimit(1)
                Text(event.allDay ? "All day" : "\(event.start.formatted(date: .omitted, time: .shortened)) – \(event.end.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                if !event.location.isEmpty {
                    Text(event.location).font(.system(size: 9)).foregroundStyle(.white.opacity(0.32)).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if let join = event.joinURL {
                Button {
                    NSWorkspace.shared.open(join)
                } label: {
                    Text("Join").font(.system(size: 9.5, weight: .bold)).foregroundStyle(.black)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(tint))
                }.buttonStyle(.plain).help(join.absoluteString)
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.white.opacity(0.055)))
        .contextMenu {
            if let join = event.joinURL {
                Button("Join meeting") { NSWorkspace.shared.open(join) }
            }
            Button("Delete", role: .destructive) { engine.remove(event) }
        }
    }

    // MARK: Banner

    private var accessBanner: some View {
        HStack(spacing: 7) {
            Image(systemName: "calendar").font(.system(size: 12, weight: .semibold)).foregroundStyle(tint)
            Text(engine.access == .denied
                 ? "Calendar access is off. Events you add here stay local."
                 : "Connect Apple Calendar to see your schedule.")
                .font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.6)).lineLimit(2)
            Spacer(minLength: 0)
            Button(engine.access == .notDetermined ? "Connect" : "Open Settings") {
                if engine.access == .notDetermined {
                    engine.requestAccess()
                } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 10.5, weight: .bold)).foregroundStyle(tint)
        }
        .padding(.horizontal, 10).padding(.vertical, 6).glass(11)
    }

    // MARK: Helpers

    /// Keep the month grid the same overall height whether the month spans five
    /// or six weeks, so the input row always clears the new bottom padding.
    private var dayRowHeight: CGFloat { monthDays.count > 35 ? 23 : 28 }

    private var dayEvents: [CalEvent] {
        engine.events(on: engine.selectedDate)
    }

    private var monthDays: [Date?] {
        let cal = Calendar.current
        guard let first = cal.dateInterval(of: .month, for: engine.visibleMonth)?.start,
              let range = cal.range(of: .day, in: .month, for: first) else { return [] }
        let leading = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        var days = [Date?](repeating: nil, count: leading)
        for d in range {
            days.append(cal.date(byAdding: .day, value: d - 1, to: first))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private var weekdaySymbols: [String] {
        let cal = Calendar.current
        let symbols = cal.veryShortWeekdaySymbols
        return (0..<7).map { symbols[(cal.firstWeekday - 1 + $0) % 7] }
    }

    private func monthButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.65))
                .frame(width: 22, height: 22).glass(11)
                .contentShape(Circle())
        }.buttonStyle(.plain)
    }

    private func shiftMonth(_ delta: Int) {
        engine.visibleMonth = Calendar.current.date(byAdding: .month, value: delta, to: engine.visibleMonth) ?? engine.visibleMonth
        engine.reload()
    }

    private func goToday() {
        let now = Date()
        engine.selectedDate = now
        engine.visibleMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now)) ?? now
        engine.reload()
    }

    private func add() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if engine.addEvent(text, on: engine.selectedDate) != nil {
            draft = ""
        }
    }
}
