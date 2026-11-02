import SwiftUI
import AppKit

let noteColors: [Color] = [
    Color(red: 1.00, green: 0.78, blue: 0.40),   // amber
    Color(red: 0.40, green: 0.90, blue: 0.75),   // mint
    Color(red: 0.45, green: 0.72, blue: 1.00),   // sky
    Color(red: 0.72, green: 0.58, blue: 1.00),   // lilac
    Color(red: 1.00, green: 0.55, blue: 0.68),   // rose
    Color(red: 0.80, green: 0.84, blue: 0.92)    // slate
]
func noteColor(_ i: Int) -> Color { noteColors[min(max(i, 0), noteColors.count - 1)] }

struct NotesView: View {
    @ObservedObject var store = Store.shared
    @State private var editing: UUID?
    @State private var query = ""
    private let tint = IslandTab.notes.tint

    private var shown: [Note] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return store.notes
            .filter { q.isEmpty || $0.text.lowercased().contains(q) }
            .sorted { a, b in a.pinned != b.pinned ? a.pinned : a.updated > b.updated }
    }

    var body: some View {
        ZStack {
            if let id = editing, store.notes.contains(where: { $0.id == id }) {
                NoteEditor(id: id) { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { editing = nil } }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                grid.transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
    }

    private var grid: some View {
        VStack(spacing: IslandLayout.verticalSpacing) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                    TextField("Search notes", text: $query).textFieldStyle(.plain).font(.system(size: 12.5))
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .glass(14)
                Button(action: newNote) {
                    Label("New", systemImage: "plus").font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .foregroundStyle(.black).background(Capsule().fill(tint))
                        .contentShape(Capsule())
                }.buttonStyle(.plain)
            }
            if shown.isEmpty {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: query.isEmpty ? "square.and.pencil" : "magnifyingglass")
                        .font(.system(size: 22)).foregroundStyle(tint)
                    Text(query.isEmpty ? "No notes yet. Capture a thought." : "No notes match “\(query)”.")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible())],
                              spacing: 8) {
                        ForEach(shown) { n in
                            NoteCard(note: n) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { editing = n.id }
                            }
                            .contextMenu {
                                Button(n.pinned ? "Unpin" : "Pin") { store.togglePin(n.id) }
                                Button("Delete", role: .destructive) { withAnimation { store.notes.removeAll { $0.id == n.id } } }
                            }
                        }
                    }
                    .animation(.inertiaLiquid(speed: store.animSpeed, reduceMotion: false), value: store.notes)
                    // FIX 2B: 16pt bottom so last card clears the panel's rounded corners.
                    .padding(.bottom, 16)
                }
            }
        }
    }

    private func newNote() {
        var n = Note()
        n.color = store.notes.count % noteColors.count
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            store.notes.insert(n, at: 0)
            editing = n.id
        }
    }
}

struct NoteCard: View {
    let note: Note
    let action: () -> Void

    var body: some View {
        let c = noteColor(note.color)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 4) {
                    Text(note.title).font(.system(size: 12.5, weight: .bold)).lineLimit(1)
                    Spacer(minLength: 0)
                    if note.pinned { Image(systemName: "pin.fill").font(.system(size: 9)).foregroundStyle(c) }
                }
                Text(note.preview.isEmpty ? "No additional text" : note.preview)
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.62)).lineLimit(3)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Text(note.updated.formatted(.relative(presentation: .named)))
                    .font(.system(size: 9.5, weight: .medium)).foregroundStyle(c.opacity(0.9))
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 100, alignment: .topLeading)
            .inertiaGlassBackground(cornerRadius: 14, showsStroke: true, tint: IslandTab.notes.tint, gloss: 0.7)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct NoteEditor: View {
    let id: UUID
    let close: () -> Void
    @ObservedObject var store = Store.shared
    @FocusState private var focused: Bool
    @State private var confirmDelete = false

    private var note: Note? { store.notes.first(where: { $0.id == id }) }

    var body: some View {
        let n = note ?? Note()
        let c = noteColor(n.color)
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button(action: finish) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold))
                        Text("Notes").font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6).glass(14).contentShape(Rectangle())
                }.buttonStyle(.plain)
                Spacer()
                HStack(spacing: 7) {
                    ForEach(0..<noteColors.count, id: \.self) { i in
                        Button { setColor(i) } label: {
                            Circle().fill(noteColors[i]).frame(width: 15, height: 15)
                                .overlay(Circle().strokeBorder(.white, lineWidth: n.color == i ? 2 : 0))
                                .padding(3).contentShape(Circle())
                        }.buttonStyle(.plain)
                    }
                }
                IconButton(symbol: n.pinned ? "pin.fill" : "pin", size: 26, tint: n.pinned ? c : nil) { store.togglePin(id) }
                IconButton(symbol: "doc.on.doc", size: 26) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(n.text, forType: .string)
                }
                if confirmDelete {
                    PillButton("Delete?", tint: .red) { remove() }
                } else {
                    IconButton(symbol: "trash", size: 26, danger: true) {
                        withAnimation { confirmDelete = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { confirmDelete = false }
                    }
                }
            }
            TextEditor(text: binding())
                .scrollContentBackground(.hidden)
                .font(.system(size: 14))
                .focused($focused)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(
                    LinearGradient(colors: [c.opacity(0.24), c.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(c.opacity(0.45), lineWidth: 0.7))
            HStack {
                Text("First line becomes the title").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text("\(wordCount(n.text)) words · \(n.text.count) chars")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
            }
        }
        .onAppear { DispatchQueue.main.async { focused = true } }
    }

    private func wordCount(_ s: String) -> Int {
        s.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
    private func binding() -> Binding<String> {
        Binding(get: { note?.text ?? "" },
                set: { v in
                    if let i = store.notes.firstIndex(where: { $0.id == id }) {
                        store.notes[i].text = v
                        store.notes[i].updated = Date()
                    }
                })
    }
    private func setColor(_ i: Int) {
        if let k = store.notes.firstIndex(where: { $0.id == id }) { withAnimation { store.notes[k].color = i } }
    }
    private func finish() {
        // an empty note is just clutter, so drop it
        if let n = note, n.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            store.notes.removeAll { $0.id == id }
        }
        close()
    }
    private func remove() {
        store.notes.removeAll { $0.id == id }
        close()
    }
}

extension Store {
    func togglePin(_ id: UUID) {
        if let i = notes.firstIndex(where: { $0.id == id }) { notes[i].pinned.toggle() }
    }
}
