import CoreGraphics
import Foundation

/// A rendered page region, ready to hand to SwiftUI.
///
/// `CGImage` is immutable once created, so carrying it across isolation domains is safe.
struct SlideImage: @unchecked Sendable, Equatable, Identifiable {
    let id: SlideRenderRequest
    let cgImage: CGImage
    /// The scale the bitmap was rendered at, for `Image(decorative:scale:)`.
    let scale: CGFloat

    var pixelSize: CGSize {
        CGSize(width: cgImage.width, height: cgImage.height)
    }

    var pointSize: CGSize {
        CGSize(width: CGFloat(cgImage.width) / scale, height: CGFloat(cgImage.height) / scale)
    }

    static func == (lhs: SlideImage, rhs: SlideImage) -> Bool {
        lhs.id == rhs.id && lhs.cgImage === rhs.cgImage
    }
}

/// Everything that determines the pixels of a render. Doubles as the cache key.
struct SlideRenderRequest: Hashable, Sendable {
    var pageIndex: Int
    var region: SlideRegion
    var layout: SlideLayout
    /// Width of the output bitmap in pixels. Height follows from the region's aspect ratio.
    var pixelWidth: Int
}
