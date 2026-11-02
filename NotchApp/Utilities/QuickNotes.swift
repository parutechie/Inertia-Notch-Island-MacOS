import SwiftUI
import Combine

final class QuickNotesManager: ObservableObject {
    static let shared = QuickNotesManager()
    @Published var snippets: [String] = []
    
    private init() {
        snippets = UserDefaults.standard.stringArray(forKey: "quickSnippets") ?? []
    }
    
    func add(_ text: String) {
        guard !text.isEmpty else { return }
        snippets.insert(text, at: 0)
        if snippets.count > 50 { snippets = Array(snippets.prefix(50)) }
        UserDefaults.standard.set(snippets, forKey: "quickSnippets")
    }
    
    func remove(at index: Int) {
        guard index < snippets.count else { return }
        snippets.remove(at: index)
        UserDefaults.standard.set(snippets, forKey: "quickSnippets")
    }
}
