import SwiftUI

/// Tools that can be pinned to the Launcher grid.
/// Removed: files, calculator, emoji, homeControls, shortcuts.
enum LauncherTool: String, CaseIterable, Identifiable, Codable {
    case clipboard
    case notes
    case tasks
    case reminders
    case calendar
    case focus
    case music

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clipboard: return "Clipboard"
        case .notes: return "Notes"
        case .tasks: return "Tasks"
        case .reminders: return "Reminders"
        case .calendar: return "Calendar"
        case .focus: return "Focus"
        case .music: return "Music"
        }
    }

    var icon: String {
        switch self {
        case .clipboard: return "doc.on.clipboard.fill"
        case .notes: return "note.text"
        case .tasks: return "checkmark.circle.fill"
        case .reminders: return "bell.fill"
        case .calendar: return "calendar"
        case .focus: return "timer"
        case .music: return "music.note"
        }
    }

    var color: Color {
        switch self {
        case .clipboard: return Color(red: 0.55, green: 0.56, blue: 0.60)
        case .notes: return Color(red: 0.98, green: 0.78, blue: 0.24)
        case .tasks: return Color(red: 0.35, green: 0.95, blue: 0.80)
        case .reminders: return Color(red: 0.65, green: 0.40, blue: 0.98)
        case .calendar: return Color(red: 0.98, green: 0.42, blue: 0.31)
        case .focus: return Color(red: 0.32, green: 0.62, blue: 0.98)
        case .music: return Color(red: 0.98, green: 0.32, blue: 0.48)
        }
    }

    /// Existing tab reused when the tool is opened.
    var tab: IslandTab {
        switch self {
        case .notes: return .notes
        case .tasks: return .tasks
        case .reminders: return .remind
        case .calendar: return .calendar
        case .focus: return .focus
        case .clipboard: return .shelf
        case .music: return .music
        }
    }

    /// Rows shown in the "..." menu, in reference order.
    static let menuOrder: [LauncherTool] = [
        .clipboard, .notes,
        .tasks, .reminders, .calendar,
        .focus, .music
    ]

    static let defaultPins: [LauncherTool] = [
        .notes, .music, .reminders, .calendar, .focus, .clipboard, .tasks
    ]
}
