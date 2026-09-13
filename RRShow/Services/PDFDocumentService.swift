import CoreGraphics
import Foundation
import ImageIO

/// Opens a PDF and renders arbitrary sub-rectangles of its pages.
///
/// Rendering goes straight through Core Graphics rather than `PDFKit`'s page image
/// helpers: cropping a dual-screen page means drawing a *window* onto the page at
/// presentation resolution, and `CGPDFPage` + a raw bitmap context is both the
/// cheapest and the most precise way to do that.
///
/// The whole type is an actor because `CGPDFDocument` is not thread-safe. The document
/// is created inside the actor and never leaves it.
actor PDFDocumentService {

    enum Failure: LocalizedError {
        case cannotOpen(URL)
        case noPages(URL)
        case missingPage(Int)
        case unsupportedRegion(SlideRegion, SlideLayout)
        case renderFailed(Int)

        var errorDescription: String? {
            switch self {
            case let .cannotOpen(url):
                "Could not open “\(url.lastPathComponent)”. It may not be a valid PDF."
            case let .noPages(url):
                "“\(url.lastPathComponent)” contains no pages."
            case let .missingPage(index):
                "Page \(index + 1) is missing from the document."
            case let .unsupportedRegion(region, layout):
                "This document has no \(region.rawValue) region in \(layout.displayName)."
            case let .renderFailed(index):
                "Page \(index + 1) could not be rendered."
            }
        }
    }

    /// Largest bitmap edge we will ever allocate, as a guard against absurd target sizes.
    private static let maximumPixelDimension = 8192

    nonisolated let url: URL
    nonisolated let pageGeometries: [PageGeometry]

    nonisolated var pageCount: Int { pageGeometries.count }

    private let document: CGPDFDocument

    private var cache: [SlideRenderRequest: CGImage] = [:]
    private var cacheOrder: [SlideRenderRequest] = []
    private var cachedBytes = 0

    /// Budget for rendered pages, in bytes.
    ///
    /// Counting entries rather than bytes was the wrong measure: a slide rendered for a
    /// 1080p projector is about 8 MB, so thirty-odd of them is a quarter of a gigabyte —
    /// enough to get the app killed for memory mid-talk, which takes the AirPlay session
    /// with it. This holds the current page and its neighbours at presentation size,
    /// plus a strip of thumbnails, and no more.
    private let cacheByteBudget = 96 * 1024 * 1024

    init(url: URL) throws {
        guard let document = CGPDFDocument(url as CFURL) else {
            throw Failure.cannotOpen(url)
        }
        guard document.numberOfPages > 0 else {
            throw Failure.noPages(url)
        }
        self.url = url
        self.document = document
        self.pageGeometries = Self.geometries(in: document)
    }

    // MARK: - Geometry

    private static func geometries(in document: CGPDFDocument) -> [PageGeometry] {
        (1 ... document.numberOfPages).map { number in
            guard let page = document.page(at: number) else {
                return PageGeometry(boxSize: .zero, rotation: 0)
            }
            return geometry(of: page)
        }
    }

    private static func geometry(of page: CGPDFPage) -> PageGeometry {
        var box = page.getBoxRect(.cropBox)
        if box.isEmpty || box.isNull {
            box = page.getBoxRect(.mediaBox)
        }
        return PageGeometry(boxSize: box.size, rotation: Int(page.rotationAngle))
    }

    nonisolated func geometry(atPageIndex index: Int) -> PageGeometry? {
        pageGeometries.indices.contains(index) ? pageGeometries[index] : nil
    }

    // MARK: - Rendering

    /// Renders one region of one page.
    ///
    /// - Parameters:
    ///   - pageIndex: Zero-based page index.
    ///   - region: Which pane of the page to draw.
    ///   - layout: How the page is split.
    ///   - targetWidth: Desired width in **points**.
    ///   - scale: Points-to-pixels factor (screen scale, typically 2 on iPad).
    func image(
        pageIndex: Int,
        region: SlideRegion,
        layout: SlideLayout,
        targetWidth: CGFloat,
        scale: CGFloat
    ) throws -> SlideImage {
        let pixelWidth = Int((targetWidth * scale).rounded())
        let request = SlideRenderRequest(
            pageIndex: pageIndex,
            region: region,
            layout: layout,
            pixelWidth: max(1, min(pixelWidth, Self.maximumPixelDimension))
        )
        return try image(for: request, scale: scale)
    }

    /// The audience half of a dual-screen page.
    func slideImage(
        pageIndex: Int,
        layout: SlideLayout,
        targetWidth: CGFloat,
        scale: CGFloat
    ) throws -> SlideImage {
        try image(pageIndex: pageIndex, region: .slide, layout: layout,
                  targetWidth: targetWidth, scale: scale)
    }

    /// The presenter-notes half of a dual-screen page.
    func notesImage(
        pageIndex: Int,
        layout: SlideLayout,
        targetWidth: CGFloat,
        scale: CGFloat
    ) throws -> SlideImage {
        try image(pageIndex: pageIndex, region: .notes, layout: layout,
                  targetWidth: targetWidth, scale: scale)
    }

    func image(for request: SlideRenderRequest, scale: CGFloat) throws -> SlideImage {
        if let cached = cachedImage(for: request) {
            return SlideImage(id: request, cgImage: cached, scale: scale)
        }

        let cgImage = try render(request)
        store(cgImage, for: request)
        return SlideImage(id: request, cgImage: cgImage, scale: scale)
    }

    /// Renders without returning anything, to warm the cache for a page the presenter
    /// is about to reach.
    func prefetch(_ request: SlideRenderRequest) {
        guard cachedImage(for: request) == nil else { return }
        guard let cgImage = try? render(request) else { return }
        store(cgImage, for: request)
    }

    func clearCache() {
        cache.removeAll()
        cacheOrder.removeAll()
        cachedBytes = 0
    }

    // MARK: - Core Graphics

    private func render(_ request: SlideRenderRequest) throws -> CGImage {
        guard let page = document.page(at: request.pageIndex + 1) else {
            throw Failure.missingPage(request.pageIndex)
        }
        guard let normalizedRect = request.layout.normalizedRect(for: request.region) else {
            throw Failure.unsupportedRegion(request.region, request.layout)
        }

        let geometry = Self.geometry(of: page)
        let displaySize = geometry.displaySize
        guard displaySize.width > 0, displaySize.height > 0 else {
            throw Failure.renderFailed(request.pageIndex)
        }

        // Scale that turns the region's natural width into the requested pixel width.
        let regionPointWidth = displaySize.width * normalizedRect.width
        let regionPointHeight = displaySize.height * normalizedRect.height
        guard regionPointWidth > 0, regionPointHeight > 0 else {
            throw Failure.renderFailed(request.pageIndex)
        }

        let renderScale = CGFloat(request.pixelWidth) / regionPointWidth
        let pixelWidth = request.pixelWidth
        let pixelHeight = max(1, min(Int((regionPointHeight * renderScale).rounded()),
                                     Self.maximumPixelDimension))

        // The full page laid out at the same scale — the space the crop window sits in.
        let fullWidth = displaySize.width * renderScale
        let fullHeight = displaySize.height * renderScale

        // Core Graphics bitmaps are y-up, so flip the region's top-left origin.
        let originX = normalizedRect.minX * fullWidth
        let originY = fullHeight - (normalizedRect.minY + normalizedRect.height) * fullHeight

        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
                | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            throw Failure.renderFailed(request.pageIndex)
        }

        // Beamer slides assume a white paper background; PDF pages are transparent.
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        context.interpolationQuality = .high
        context.setRenderingIntent(.defaultIntent)

        context.saveGState()
        // Window onto the region…
        context.translateBy(x: -originX, y: -originY)
        // …then magnify. The scale is applied here rather than by asking
        // `getDrawingTransform` for a larger rect, because that transform only ever
        // scales a page *down* to fit — hand it an oversized rect and it silently
        // centers the page at 1:1 instead of enlarging it.
        context.scaleBy(x: renderScale, y: renderScale)
        // At 1:1 `getDrawingTransform` does exactly what is still needed: move the crop
        // box origin to zero and apply the page's own /Rotate.
        context.concatenate(page.getDrawingTransform(
            .cropBox,
            rect: CGRect(origin: .zero, size: displaySize),
            rotate: 0,
            preserveAspectRatio: true
        ))
        context.drawPDFPage(page)
        context.restoreGState()

        guard let image = context.makeImage() else {
            throw Failure.renderFailed(request.pageIndex)
        }
        return image
    }

    // MARK: - Cache

    private func cachedImage(for request: SlideRenderRequest) -> CGImage? {
        guard let image = cache[request] else { return nil }
        touch(request)
        return image
    }

    private func store(_ image: CGImage, for request: SlideRenderRequest) {
        if let existing = cache[request] {
            cachedBytes -= Self.byteSize(of: existing)
        }
        cache[request] = image
        cachedBytes += Self.byteSize(of: image)
        touch(request)

        // Never evict the entry just stored, however large: the caller is about to draw
        // it, and dropping it would render the same page again on the next frame.
        while cachedBytes > cacheByteBudget,
              let oldest = cacheOrder.first,
              oldest != request {
            cacheOrder.removeFirst()
            if let evicted = cache.removeValue(forKey: oldest) {
                cachedBytes -= Self.byteSize(of: evicted)
            }
        }
    }

    private static func byteSize(of image: CGImage) -> Int {
        image.bytesPerRow * image.height
    }

    private func touch(_ request: SlideRenderRequest) {
        if let existing = cacheOrder.firstIndex(of: request) {
            cacheOrder.remove(at: existing)
        }
        cacheOrder.append(request)
    }
}
