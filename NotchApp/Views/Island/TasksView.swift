import SwiftUI

struct TasksView: View {
    @ObservedObject var store = Store.shared
    @State private var draft = ""
    @State private var prio = 1
    @State private var filter = 0
    private let tint = IslandTab.tasks.tint

    private var shown: [TodoItem] {
        let f = store.todos.filter { filter == 0 || (filter == 1 ? !$0.done : $0.done) }
        // finished tasks sink to the bottom, otherwise keep the user's order
        return f.enumerated().sorted { a, b in
            if a.element.done != b.element.done { return !a.element.done }
            return a.offset < b.offset
        }.map { $0.element }
    }
    private var doneCount: Int { store.todos.filter { $0.done }.count }
    private var progress: CGFloat { store.todos.isEmpty ? 0 : CGFloat(doneCount) / CGFloat(store.todos.count) }

    var body: some View {
        // Horizontal padding is owned by OpenPanel (IslandLayout.contentInset).
        // Adding padding here would double-inset the row/list/input again.
        VStack(spacing: IslandLayout.verticalSpacing) {
            todayRow
            Group {
                if shown.isEmpty {
                    emptyState
                } else {
                    taskList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            inputRow
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var todayRow: some View {
        HStack(alignment: .center, spacing: 10) {
            progressRing
            VStack(alignment: .leading, spacing: 0) {
                Text("Today").font(.system(size: 14, weight: .semibold))
                Text("\(doneCount) of \(store.todos.count) done")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
            Chip(text: "All", on: filter == 0, tint: tint) { filter = 0 }
            Chip(text: "Active", on: filter == 1, tint: tint) { filter = 1 }
            Chip(text: "Done", on: filter == 2, tint: tint) { filter = 2 }
        }
        .frame(maxWidth: .infinity)
    }

    private var progressRing: some View {
        ZStack {
            Circle().strokeBorder(.white.opacity(0.12), lineWidth: 4)
            // The track is strokeBorder (inside the 28pt frame). The progress arc
            // is a normal centered stroke, so inset its path by half the line width
            // to keep the whole ring inside the same 28pt layout bounds.
            Circle()
                .inset(by: 2)
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 28, height: 28)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: "sparkles").font(.system(size: 20)).foregroundStyle(tint)
            Text(store.todos.isEmpty ? "A clean slate. Add your first task." : "Nothing here.")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
        }
        // Fills only the space between the Today row and the input field.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var taskList: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(shown) { TodoRow(item: $0) }
            }
            // FIX 2B: 8pt top padding so the first row is never clipped.
            .padding(.top, 8)
            .padding(.bottom, 16)
            .animation(.inertiaLiquid(speed: store.animSpeed, reduceMotion: false), value: store.todos)
            .frame(maxWidth: .infinity)
        }
    }

    private var inputRow: some View {
        HStack(spacing: 8) {
            Button { prio = (prio + 1) % 3 } label: {
                Circle().fill(prioColor(prio)).frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 0.6))
                    .padding(5).contentShape(Circle())
            }.buttonStyle(.plain).help("Priority")
            TextField("Add a task", text: $draft).textFieldStyle(.plain).font(.system(size: 13)).onSubmit(add)
            if doneCount > 0 {
                Button("Clear done") { withAnimation { store.todos.removeAll { $0.done } } }
                    .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
            }
            Button(action: add) {
                Image(systemName: "arrow.up").font(.system(size: 11, weight: .heavy)).foregroundStyle(.black)
                    .frame(width: 26, height: 26).background(Circle().fill(tint)).contentShape(Circle())
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .inertiaGlassBackground(cornerRadius: 16, showsStroke: true, tint: tint, gloss: 0.7)
    }

    private func add() {
        let s = draft.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { store.todos.insert(TodoItem(title: s, prio: prio), at: 0) }
        draft = ""
    }
}

struct TodoRow: View {
    let item: TodoItem
    @ObservedObject var store = Store.shared
    @State private var editing = false
    @State private var text = ""
    @FocusState private var focused: Bool
    private let tint = IslandTab.tasks.tint

    var body: some View {
        HStack(spacing: 0) {
            Capsule().fill(prioColor(item.prio)).frame(width: 3).padding(.vertical, 7)
            HStack(spacing: 8) {
                // Big, fully clickable checkbox. The old one only reacted on the thin ring.
                Button(action: toggle) {
                    ZStack {
                        Circle().fill(item.done ? AnyShapeStyle(LinearGradient(colors: [tint, .white], startPoint: .topLeading, endPoint: .bottomTrailing))
                                                : AnyShapeStyle(Color.white.opacity(0.001)))
                        Circle().strokeBorder(.white.opacity(item.done ? 0 : 0.45), lineWidth: 1.5)
                        if item.done {
                            Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(.black)
                        }
                    }
                    .frame(width: 20, height: 20)
                    .frame(width: 32, height: 34)
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)

                if editing {
                    TextField("Task", text: $text).textFieldStyle(.plain)
                        .focused($focused)
                        .onSubmit(commit)
                        .onExitCommand(perform: cancel)
                    IconButton(symbol: "checkmark", size: 24, tint: tint, action: commit)
                } else {
                    Text(item.title).strikethrough(item.done).lineLimit(1)
                        .foregroundStyle(.white.opacity(item.done ? 0.4 : 0.95))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: beginEdit)          // click the text to edit it
                    Button {
                        store.updateTodo(item.id) { $0.prio = ($0.prio + 1) % 3 }
                    } label: {
                        Text(["Low", "Med", "High"][min(max(item.prio, 0), 2)]).font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .foregroundStyle(prioColor(item.prio))
                            .background(Capsule().fill(prioColor(item.prio).opacity(0.16)))
                            .contentShape(Capsule())
                    }.buttonStyle(.plain)
                    rowIcon("pencil", .white.opacity(0.6), beginEdit)
                    rowIcon("trash", .red.opacity(0.85)) {
                        withAnimation { store.todos.removeAll { $0.id == item.id } }
                    }
                }
            }
            .font(.system(size: 13)).padding(.horizontal, 6)
        }
        .frame(height: 48)
        .inertiaGlassBackground(cornerRadius: 12, showsStroke: true, tint: tint, gloss: 0.7)
    }

    private func rowIcon(_ name: String, _ color: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 11)).foregroundStyle(color)
                .frame(width: 24, height: 28).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func toggle() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { store.updateTodo(item.id) { $0.done.toggle() } }
    }
    private func beginEdit() {
        text = item.title
        editing = true
        DispatchQueue.main.async { focused = true }
    }
    private func commit() {
        let s = text.trimmingCharacters(in: .whitespaces)
        if !s.isEmpty { store.updateTodo(item.id) { $0.title = s } }
        editing = false
    }
    private func cancel() { editing = false }
}
