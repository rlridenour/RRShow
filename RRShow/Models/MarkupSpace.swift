import CoreGraphics

/// The coordinate space markup is stored in.
///
/// Strokes are drawn on a pane a few hundred points wide and replayed on a projector a
/// couple of thousand pixels wide. Storing them against a fixed canonical width — rather
/// than against whichever view happened to capture them — means one drawing lands in the
/// same place, at the same relative thickness, on every surface, and survives rotation
/// and layout changes in between.
enum MarkupSpace {

    /// Canonical slide width. The height follows from the slide's aspect ratio.
    static let width: CGFloat = 1000

    static func size(aspectRatio: CGFloat) -> CGSize {
        CGSize(width: width, height: aspectRatio > 0 ? width / aspectRatio : width)
    }

    /// Factor converting canonical units to a surface `targetWidth` points across.
    static func scale(toWidth targetWidth: CGFloat) -> CGFloat {
        guard targetWidth > 0 else { return 1 }
        return targetWidth / width
    }

    /// Transform from canonical space onto a surface `targetWidth` points across.
    static func transform(toWidth targetWidth: CGFloat) -> CGAffineTransform {
        let scale = scale(toWidth: targetWidth)
        return CGAffineTransform(scaleX: scale, y: scale)
    }

    /// Transform from a surface `sourceWidth` points across back into canonical space.
    static func transformToCanonical(fromWidth sourceWidth: CGFloat) -> CGAffineTransform {
        guard sourceWidth > 0 else { return .identity }
        let scale = width / sourceWidth
        return CGAffineTransform(scaleX: scale, y: scale)
    }
}
