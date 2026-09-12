import SwiftUI
import UIKit

/// Captures where the presenter is pointing on the slide.
///
/// Two input paths, both reported in `MarkupSpace` coordinates:
///
/// - **Hover** — an Apple Pencil held just above the glass on hardware that supports
///   hover, or a trackpad pointer. The dot follows without anything being touched, which
///   is the closest thing to a real laser pointer.
/// - **Touch** — a finger or Pencil on the glass, for hardware without hover.
struct LaserPointerSurface: UIViewRepresentable {

    var onMove: (CGPoint?) -> Void

    func makeUIView(context: Context) -> PointerView {
        let view = PointerView()
        view.onMove = onMove
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = false

        let hover = UIHoverGestureRecognizer(
            target: view,
            action: #selector(PointerView.handleHover(_:))
        )
        view.addGestureRecognizer(hover)
        return view
    }

    func updateUIView(_ view: PointerView, context: Context) {
        view.onMove = onMove
    }

    final class PointerView: UIView {

        var onMove: ((CGPoint?) -> Void)?

        private func report(_ location: CGPoint?) {
            guard let location else {
                onMove?(nil)
                return
            }
            let width = bounds.width
            guard width > 0 else { return }
            let scale = MarkupSpace.width / width
            onMove?(CGPoint(x: location.x * scale, y: location.y * scale))
        }

        @objc func handleHover(_ recognizer: UIHoverGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed:
                report(recognizer.location(in: self))
            default:
                report(nil)
            }
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            report(touches.first?.location(in: self))
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            report(touches.first?.location(in: self))
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            report(nil)
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            report(nil)
        }
    }
}

/// The dot itself: a saturated core inside a soft halo, sized in canonical units so it
/// covers the same fraction of the slide on the iPad and on the projector.
struct LaserDot: View {

    /// Position in `MarkupSpace` coordinates.
    var point: CGPoint
    /// Width of the surface being drawn on, in points.
    var surfaceWidth: CGFloat

    /// Core diameter in canonical units — about 1.6% of the slide width, which reads as
    /// a pointer rather than a blob from the back of a hall.
    private let canonicalDiameter: CGFloat = 16

    var body: some View {
        let scale = MarkupSpace.scale(toWidth: surfaceWidth)
        let diameter = canonicalDiameter * scale

        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.red.opacity(0.55),
                            Color.red.opacity(0.18),
                            Color.red.opacity(0),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: diameter * 1.75
                    )
                )
                .frame(width: diameter * 3.5, height: diameter * 3.5)

            Circle()
                .fill(Color(red: 1, green: 0.32, blue: 0.28))
                .frame(width: diameter, height: diameter)
                .overlay {
                    // A hot centre, the way a real laser dot blooms white.
                    Circle()
                        .fill(.white.opacity(0.85))
                        .frame(width: diameter * 0.38, height: diameter * 0.38)
                }
        }
        .position(x: point.x * scale, y: point.y * scale)
        .allowsHitTesting(false)
    }
}

/// Places the dot over a slide-sized surface.
struct LaserOverlay: View {

    var point: CGPoint?

    var body: some View {
        GeometryReader { proxy in
            if let point, proxy.size.width > 0 {
                LaserDot(point: point, surfaceWidth: proxy.size.width)
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.12), value: point == nil)
    }
}
