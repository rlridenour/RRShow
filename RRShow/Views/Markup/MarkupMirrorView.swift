import PencilKit
import SwiftUI

/// Replays the presenter's marks on another surface — the projector.
///
/// Two layers: the committed `PKDrawing`, rendered by a non-interactive `PKCanvasView`
/// so it keeps PencilKit's own ink, and the in-flight polyline on top of it.
struct MarkupMirrorView: View {

    var drawing: PKDrawing
    var liveStroke: LiveStroke?

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack {
                if width > 0 {
                    DrawingLayer(
                        drawing: drawing.transformed(
                            using: MarkupSpace.transform(toWidth: width)
                        )
                    )

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

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isUserInteractionEnabled = false
        canvas.isScrollEnabled = false
        // Match the authoring canvas so ink is not remapped for dark mode.
        canvas.overrideUserInterfaceStyle = .light
        canvas.drawing = drawing
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        canvas.drawing = drawing
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
