import PencilKit
import SwiftUI

/// Replays the presenter's marks on another surface — the projector.
///
/// Two layers: the committed `PKDrawing`, rendered by a non-interactive `PKCanvasView`
/// so it keeps PencilKit's own ink, and the in-flight polyline on top of it.
struct MarkupMirrorView: View {

    var drawing: PKDrawing
    /// Changes only when the drawing does, so the canvas can skip re-uploading.
    var version: Int
    var liveStroke: LiveStroke?

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack {
                if width > 0 {
                    // No canvas at all until something has been drawn. A `PKCanvasView`
                    // is Metal-backed, and an empty one still costs the audience display
                    // a surface to composite on every frame.
                    if !drawing.strokes.isEmpty {
                        DrawingLayer(
                            drawing: drawing.transformed(
                                using: MarkupSpace.transform(toWidth: width)
                            ),
                            version: version
                        )
                    }

                    if let liveStroke, liveStroke.isDrawable {
                        LiveStrokeShape(stroke: liveStroke, targetWidth: width)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

/// A `PKCanvasView` used purely as a renderer.
private struct DrawingLayer: UIViewRepresentable {

    var drawing: PKDrawing
    var version: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var appliedVersion: Int?
        var appliedWidth: CGFloat = 0
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isUserInteractionEnabled = false
        canvas.isScrollEnabled = false
        // Match the authoring canvas so ink is not remapped for dark mode.
        canvas.overrideUserInterfaceStyle = .light
        canvas.drawing = drawing
        context.coordinator.appliedVersion = version
        context.coordinator.appliedWidth = canvas.bounds.width
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        // Assigning `drawing` re-renders the canvas's Metal surface. Doing it on every
        // SwiftUI update — which is what happened before — meant a full re-render each
        // time anything in the session changed, marks or no marks. Over AirPlay, where
        // the whole display is being encoded, that is real cost for no change on screen.
        let width = canvas.bounds.width
        let widthChanged = abs(width - context.coordinator.appliedWidth) > 0.5
        guard context.coordinator.appliedVersion != version || widthChanged else { return }

        canvas.drawing = drawing
        context.coordinator.appliedVersion = version
        context.coordinator.appliedWidth = width
    }
}

/// The stroke still under the pencil, as a plain round-capped polyline.
///
/// It will not match PencilKit's taper exactly, but it is the same colour, width and
/// path, and it is replaced by the real stroke the moment the pencil lifts.
private struct LiveStrokeShape: View {

    var stroke: LiveStroke
    var targetWidth: CGFloat

    var body: some View {
        let scale = MarkupSpace.scale(toWidth: targetWidth)

        Path { path in
            guard let first = stroke.points.first else { return }
            path.move(to: CGPoint(x: first.x * scale, y: first.y * scale))
            for point in stroke.points.dropFirst() {
                path.addLine(to: CGPoint(x: point.x * scale, y: point.y * scale))
            }
        }
        .stroke(
            stroke.color.color.opacity(stroke.tool == .highlighter ? 0.4 : 1),
            style: StrokeStyle(
                lineWidth: stroke.width * scale,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }
}
