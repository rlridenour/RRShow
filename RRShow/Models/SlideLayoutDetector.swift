import CoreGraphics
import Foundation

/// Guesses whether a PDF is a dual-screen (slide + notes) deck from page geometry alone.
///
/// Beamer's second-screen option doubles the page along one axis, so a 16:9 deck with
/// notes on the right is authored at 32:9 (≈3.56). Anything appreciably wider than a
/// normal slide is therefore a horizontal split.
///
/// Vertical splits are *not* auto-detected: a 16:9 deck stacked vertically is 8:9 (≈0.89),
/// which is indistinguishable from an ordinary portrait document. Those decks need the
/// layout set by hand.
enum SlideLayoutDetector {
    /// Widest aspect ratio still considered a single slide. A 21:9 cinematic slide is
    /// 2.33, so the threshold sits just above it; a doubled 4:3 deck is 2.67.
    static let horizontalSplitThreshold: CGFloat = 2.4

    static func detectLayout(for geometry: PageGeometry) -> SlideLayout {
        geometry.aspectRatio >= horizontalSplitThreshold ? .beamerDualScreen : .standard
    }

    /// Detects from a whole document, using the first page that reports a usable size.
    static func detectLayout(for geometries: [PageGeometry]) -> SlideLayout {
        guard let first = geometries.first(where: { $0.displaySize.height > 0 }) else {
            return .standard
        }
        return detectLayout(for: first)
    }
}
