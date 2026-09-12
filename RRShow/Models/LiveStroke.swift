import CoreGraphics
import Foundation

/// The stroke currently under the Pencil, in `MarkupSpace` coordinates.
///
/// PencilKit keeps an in-progress stroke to itself until the pencil lifts, so the
/// audience display would otherwise see marks appear a stroke at a time — very obvious
/// when someone underlines a phrase slowly. This is a plain polyline of the same touches,
/// drawn on the projector as the hand moves and discarded the instant the real stroke
/// commits.
struct LiveStroke: Equatable, Sendable {
    var points: [CGPoint]
    var tool: MarkupTool
    var color: MarkupColor
    /// Width in canonical units.
    var width: CGFloat

    var isDrawable: Bool { points.count > 1 && tool != .eraser }
}
