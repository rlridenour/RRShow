import CoreGraphics
import Foundation

/// Where the speaker-notes half of a dual-screen page sits relative to the slide half.
///
/// Beamer's `\setbeameroption{show notes on second screen=<position>}` supports
/// `right` (the default and by far the most common), `left`, `bottom` and `top`.
enum NotesPosition: String, CaseIterable, Codable, Sendable, Identifiable {
    case right
    case left
    case bottom
    case top

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .right: "Notes on Right"
        case .left: "Notes on Left"
        case .bottom: "Notes on Bottom"
        case .top: "Notes on Top"
        }
    }

    /// True when the split runs down the page (slide and notes sit side by side).
    var isHorizontal: Bool {
        self == .right || self == .left
    }
}

/// How a single PDF page maps onto the audience slide and the presenter's notes.
enum SlideLayout: Hashable, Codable, Sendable {
    /// One page is one slide. There are no notes.
    case standard
    /// One page holds two panes: the slide and the notes frame.
    case split(notes: NotesPosition)

    /// The layout produced by `show notes on second screen=right` — the default assumption.
    static let beamerDualScreen = SlideLayout.split(notes: .right)

    var hasNotes: Bool {
        if case .split = self { return true }
        return false
    }

    var notesPosition: NotesPosition? {
        if case let .split(position) = self { return position }
        return nil
    }

    var displayName: String {
        switch self {
        case .standard: "Standard (one slide per page)"
        case let .split(position): "Split page · \(position.displayName)"
        }
    }
}

/// A pane of a PDF page.
enum SlideRegion: String, CaseIterable, Sendable, Codable {
    /// The whole page, exactly as authored.
    case full
    /// The part the audience sees.
    case slide
    /// The presenter's notes frame.
    case notes
}

extension SlideLayout {
    /// The portion of a page occupied by `region`, in normalized page coordinates
    /// with the origin at the **top left** and both axes running 0...1.
    ///
    /// Returns `nil` when the layout has no such region (notes on a standard PDF).
    func normalizedRect(for region: SlideRegion) -> CGRect? {
        let unit = CGRect(x: 0, y: 0, width: 1, height: 1)

        switch (self, region) {
        case (_, .full):
            return unit

        case (.standard, .slide):
            return unit

        case (.standard, .notes):
            return nil

        case let (.split(position), .slide):
            return Self.rect(for: position, takingNotes: false)

        case let (.split(position), .notes):
            return Self.rect(for: position, takingNotes: true)
        }
    }

    private static func rect(for position: NotesPosition, takingNotes: Bool) -> CGRect {
        switch position {
        case .right:
            CGRect(x: takingNotes ? 0.5 : 0.0, y: 0, width: 0.5, height: 1)
        case .left:
            CGRect(x: takingNotes ? 0.0 : 0.5, y: 0, width: 0.5, height: 1)
        case .bottom:
            CGRect(x: 0, y: takingNotes ? 0.5 : 0.0, width: 1, height: 0.5)
        case .top:
            CGRect(x: 0, y: takingNotes ? 0.0 : 0.5, width: 1, height: 0.5)
        }
    }
}
