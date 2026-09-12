import CoreGraphics
import Foundation

/// The on-screen geometry of one PDF page, after the page's own `/Rotate` entry
/// has been applied. Sizes are in PDF points.
struct PageGeometry: Hashable, Sendable {
    /// The crop box (or media box, when there is no crop box), unrotated.
    var boxSize: CGSize
    /// Page rotation in degrees, normalized to 0/90/180/270.
    var rotation: Int

    init(boxSize: CGSize, rotation: Int) {
        self.boxSize = boxSize
        self.rotation = ((rotation % 360) + 360) % 360
    }

    /// The size a viewer sees, with rotation applied.
    var displaySize: CGSize {
        rotation == 90 || rotation == 270
            ? CGSize(width: boxSize.height, height: boxSize.width)
            : boxSize
    }

    var aspectRatio: CGFloat {
        guard displaySize.height > 0 else { return 1 }
        return displaySize.width / displaySize.height
    }

    /// The size of one region of this page, given a layout.
    func size(of region: SlideRegion, layout: SlideLayout) -> CGSize? {
        guard let rect = layout.normalizedRect(for: region) else { return nil }
        return CGSize(width: displaySize.width * rect.width,
                      height: displaySize.height * rect.height)
    }

    /// The aspect ratio of one region, or `nil` when the layout has no such region.
    func aspectRatio(of region: SlideRegion, layout: SlideLayout) -> CGFloat? {
        guard let size = size(of: region, layout: layout), size.height > 0 else { return nil }
        return size.width / size.height
    }
}
