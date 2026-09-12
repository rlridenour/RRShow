import Foundation

/// How the presenter's own screen is arranged. Independent of `SlideLayout`, which
/// describes how a *page* is split; this describes how the panes are laid out for the
/// person talking.
enum PresenterLayoutMode: String, CaseIterable, Identifiable, Codable, Sendable {
    /// Current slide beside the current notes.
    case sideBySide
    /// Current slide large, with the next slide and the notes stacked alongside.
    case threePane
    /// Notes dominate; the current and next slides ride along as thumbnails.
    case speakerFocused
    /// Slide fills the screen, notes tuck into a collapsible drawer.
    case fullSlide

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sideBySide: "Side by Side"
        case .threePane: "Three Pane"
        case .speakerFocused: "Speaker Focused"
        case .fullSlide: "Full Slide"
        }
    }

    var subtitle: String {
        switch self {
        case .sideBySide: "Slide and notes, equal billing"
        case .threePane: "Slide, next slide, notes"
        case .speakerFocused: "Large notes, small slides"
        case .fullSlide: "Slide only, notes in a drawer"
        }
    }

    var systemImage: String {
        switch self {
        case .sideBySide: "rectangle.split.2x1"
        case .threePane: "rectangle.split.3x1"
        case .speakerFocused: "text.justify.left"
        case .fullSlide: "rectangle"
        }
    }

    /// A deck with no notes frame has nothing to put in the second pane, so these
    /// modes quietly fall back to `.fullSlide`.
    var requiresNotes: Bool { self != .fullSlide }

    /// 1-based index used for the ⌘1…⌘4 shortcuts.
    var shortcutNumber: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }
}

extension PresenterLayoutMode {
    private static let defaultsKey = "presenter.layoutMode"

    /// The mode the presenter last chose, so reopening the app lands where they left off.
    static var restored: PresenterLayoutMode {
        guard let raw = UserDefaults.standard.string(forKey: defaultsKey) else { return .sideBySide }
        return PresenterLayoutMode(rawValue: raw) ?? .sideBySide
    }

    static func store(_ mode: PresenterLayoutMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: defaultsKey)
    }
}
