import PencilKit
import SwiftUI

/// The Pencil surface laid over the presenter's current slide.
///
/// Two things come out of it: the committed `PKDrawing`, published when PencilKit
/// finishes a stroke, and a live polyline of the stroke still under the pencil. Both are
/// reported in `MarkupSpace` coordinates so the audience display can replay them at its
/// own size.
struct MarkupCanvas: UIViewRepresentable {

    /// Committed marks for this slide, in canonical coordinates.
    var drawing: PKDrawing
    /// Bumped by the model when the canvas must reload rather than publish.
    var revision: Int
    var tool: MarkupTool
    var color: MarkupColor
    var pencilOnly: Bool

    var onCommit: (PKDrawing) -> Void
    var onLiveStroke: (LiveStroke?) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.delegate = context.coordinator
        // The canvas is exactly slide-sized; nothing should scroll or zoom inside it.
        canvas.isScrollEnabled = false
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 1
        canvas.contentInsetAdjustmentBehavior = .never
        // Ink colours are chosen against a white slide, so they must not be remapped for
        // dark mode the way PencilKit does by default.
        canvas.overrideUserInterfaceStyle = .light

        let observer = StrokeObserverGesture()
        observer.onChange = { [weak canvas] phase, points in
            guard let canvas else { return }
            context.coordinator.handleObservedTouches(phase: phase, points: points, in: canvas)
        }
        canvas.addGestureRecognizer(observer)

        context.coordinator.configure(canvas: canvas, from: self)
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        canvas.drawingPolicy = pencilOnly ? .pencilOnly : .anyInput
        canvas.tool = tool.pkTool(color: color, canvasWidth: canvas.bounds.width)
        context.coordinator.reloadIfNeeded(canvas: canvas, from: self)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate {

        var parent: MarkupCanvas

        private var appliedRevision: Int?
        private var appliedWidth: CGFloat = 0
        /// Suppresses the delegate callback caused by our own write to `canvas.drawing`.
        private var isReloading = false

        private var strokePoints: [CGPoint] = []

        init(parent: MarkupCanvas) {
            self.parent = parent
        }

        func configure(canvas: PKCanvasView, from parent: MarkupCanvas) {
            self.parent = parent
            apply(parent.drawing, to: canvas)
            appliedRevision = parent.revision
        }

        /// Reloads the canvas when the model changed underneath it, or when the canvas
        /// resized and the stored strokes need rescaling to the new width.
        func reloadIfNeeded(canvas: PKCanvasView, from parent: MarkupCanvas) {
            let width = canvas.bounds.width
            guard width > 0 else { return }

            let revisionChanged = appliedRevision != parent.revision
            let widthChanged = abs(width - appliedWidth) > 0.5
            guard revisionChanged || widthChanged else { return }

            apply(parent.drawing, to: canvas)
            appliedRevision = parent.revision
        }

        private func apply(_ canonical: PKDrawing, to canvas: PKCanvasView) {
            let width = canvas.bounds.width
            guard width > 0 else { return }
            isReloading = true
            canvas.drawing = canonical.transformed(
                using: MarkupSpace.transform(toWidth: width)
            )
            appliedWidth = width
            isReloading = false
        }

        // MARK: PKCanvasViewDelegate

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isReloading else { return }
            let width = canvasView.bounds.width
            guard width > 0 else { return }
            let canonical = canvasView.drawing.transformed(
                using: MarkupSpace.transformToCanonical(fromWidth: width)
            )
            appliedWidth = width
            strokePoints.removeAll()
            parent.onCommit(canonical)
            // Bump our own marker so the committed drawing coming back does not look
            // like an external change and trigger a reload.
            appliedRevision = parent.revision
        }

        // MARK: Live stroke

        func handleObservedTouches(phase: StrokeObserverGesture.Phase, points: [CGPoint], in canvas: PKCanvasView) {
            let width = canvas.bounds.width
            guard width > 0 else { return }
            let toCanonical = MarkupSpace.width / width

            switch phase {
            case .began:
                strokePoints = points.map { CGPoint(x: $0.x * toCanonical, y: $0.y * toCanonical) }
            case .moved:
                strokePoints.append(contentsOf: points.map {
                    CGPoint(x: $0.x * toCanonical, y: $0.y * toCanonical)
                })
            case .ended:
                // The committed drawing takes over from here.
                strokePoints.removeAll()
                parent.onLiveStroke(nil)
                return
            }

            guard parent.tool != .eraser else { return }
            parent.onLiveStroke(
                LiveStroke(
                    points: strokePoints,
                    tool: parent.tool,
                    color: parent.color,
                    width: parent.tool.canonicalWidth
                )
            )
        }
    }
}

/// Watches the same touches PencilKit is drawing with, without taking them.
///
/// It never advances past `.possible`, so it never recognises and never cancels the
/// canvas's own drawing gesture; it exists purely to report where the pencil is while
/// the stroke is still in flight.
final class StrokeObserverGesture: UIGestureRecognizer {

    enum Phase { case began, moved, ended }

    var onChange: ((Phase, [CGPoint]) -> Void)?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        requiresExclusiveTouchType = false
    }

    convenience init() {
        self.init(target: nil, action: nil)
    }

    private func report(_ phase: Phase, _ touches: Set<UITouch>, _ event: UIEvent) {
        guard let view, let touch = touches.first else { return }
        // Coalesced touches carry the full-rate Pencil samples between display frames,
        // which is what keeps the mirrored line smooth rather than faceted.
        let samples = event.coalescedTouches(for: touch) ?? [touch]
        onChange?(phase, samples.map { $0.location(in: view) })
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        report(.began, touches, event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        report(.moved, touches, event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        report(.ended, touches, event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        report(.ended, touches, event)
    }
}
