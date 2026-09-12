import PencilKit
import SwiftUI

/// The minimal set of marks a lecturer actually makes on a slide.
enum MarkupTool: String, CaseIterable, Identifiable, Sendable {
    case pen
    case highlighter
    case eraser

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pen: "Pen"
        case .highlighter: "Highlighter"
        case .eraser: "Eraser"
        }
    }

    var systemImage: String {
        switch self {
        case .pen: "pencil.tip"
        case .highlighter: "highlighter"
        case .eraser: "eraser"
        }
    }

    var usesColor: Bool { self != .eraser }

    /// Stroke width in canonical markup units (see `MarkupSpace`).
    var canonicalWidth: CGFloat {
        switch self {
        case .pen: 5
        case .highlighter: 26
        case .eraser: 0
        }
    }

    /// Builds the PencilKit tool for a canvas of `canvasWidth` points.
    ///
    /// Widths are declared in canonical units and scaled to the canvas, so a pen stroke
    /// covers the same fraction of the slide on a small pane and on a projector.
    func pkTool(color: MarkupColor, canvasWidth: CGFloat) -> PKTool {
        let scale = MarkupSpace.scale(toWidth: canvasWidth)
        switch self {
        case .pen:
            return PKInkingTool(.pen, color: color.uiColor, width: canonicalWidth * scale)
        case .highlighter:
            // The marker ink is already translucent; it lays over slide text rather than
            // hiding it.
            return PKInkingTool(.marker, color: color.uiColor, width: canonicalWidth * scale)
        case .eraser:
            // Vector erasing removes a whole stroke at a time, which is the right
            // granularity for marks that only need to survive a sentence or two.
            return PKEraserTool(.vector)
        }
    }
}

/// A short palette chosen to stay legible over white Beamer slides and to survive
/// projector colour shift.
enum MarkupColor: String, CaseIterable, Identifiable, Sendable {
    case red
    case blue
    case green
    case yellow

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .red: Color(red: 0.90, green: 0.13, blue: 0.18)
        case .blue: Color(red: 0.11, green: 0.40, blue: 0.93)
        case .green: Color(red: 0.05, green: 0.62, blue: 0.30)
        case .yellow: Color(red: 0.98, green: 0.78, blue: 0.05)
        }
    }

    var uiColor: UIColor { UIColor(color) }
}

/// What happens to marks when the presenter moves on.
enum MarkupPersistence: String, CaseIterable, Identifiable, Sendable {
    /// Marks vanish when the slide changes. The default: they are annotations on speech,
    /// not on the document.
    case clearOnAdvance
    /// Marks stay put for the length of the session, so going back shows them again.
    case keepForSession

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .clearOnAdvance: "Clear on Advance"
        case .keepForSession: "Keep for Session"
        }
    }
}
