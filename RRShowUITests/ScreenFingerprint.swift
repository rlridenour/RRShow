import XCTest

/// A coarse summary of what a screen is showing, for comparing one moment to another.
///
/// Pixel-exact comparison is useless here — antialiasing and PDF rasterisation differ
/// run to run — and a screenshot alone cannot tell you *what* a slide says. What it can
/// tell you reliably is whether the picture changed, stayed put, or went uniformly dark.
///
/// Measurements are taken over the **content region** — the bounding box of everything
/// that is not black — rather than the whole framebuffer. That matters because the
/// audience window does not always fill the screen: the iOS Simulator sometimes reports
/// an external display's geometry as the port's default (720×480) while its framebuffer
/// is 1920×1080, leaving correctly rendered content in one corner. UIKit reports the
/// same wrong size to the app, so nothing in-process can compensate. Measuring the
/// content region makes these assertions independent of that, and of ordinary
/// letterboxing.
struct ScreenFingerprint {

    /// Mean brightness per cell of a `gridSize` × `gridSize` grid, row-major, 0...1.
    let cells: [Double]

    static let gridSize = 64

    /// Cells at or below this luminance count as background rather than content.
    private static let contentThreshold = 0.06

    init(_ screenshot: XCUIScreenshot) {
        guard let cgImage = screenshot.image.cgImage else {
            cells = []
            return
        }

        let side = Self.gridSize
        var pixels = [UInt8](repeating: 0, count: side * side * 4)

        // Redrawing into a small context *is* the downsample — Core Graphics averages
        // for us, at a cost independent of the screen's real size.
        pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue
            ) else { return }
            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
        }

        cells = stride(from: 0, to: pixels.count, by: 4).map { offset in
            let blue = Double(pixels[offset])
            let green = Double(pixels[offset + 1])
            let red = Double(pixels[offset + 2])
            return (0.299 * red + 0.587 * green + 0.114 * blue) / 255
        }
    }

    var isEmpty: Bool { cells.isEmpty }

    // MARK: - Content region

    /// Indices of the grid cells forming the bounding box of everything non-black,
    /// or `nil` when the screen is entirely dark.
    private var contentBox: (minX: Int, minY: Int, maxX: Int, maxY: Int)? {
        guard !cells.isEmpty else { return nil }
        let side = Self.gridSize
        var minX = side, minY = side, maxX = -1, maxY = -1

        for index in cells.indices where cells[index] > Self.contentThreshold {
            let x = index % side
            let y = index / side
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
        }
        guard maxX >= 0 else { return nil }
        return (minX, minY, maxX, maxY)
    }

    var hasContent: Bool { contentBox != nil }

    /// Fraction of the screen the content occupies, 0...1. Well under 1 means the
    /// audience window is not filling its display.
    var contentCoverage: Double {
        guard let box = contentBox else { return 0 }
        let area = Double((box.maxX - box.minX + 1) * (box.maxY - box.minY + 1))
        return area / Double(Self.gridSize * Self.gridSize)
    }

    /// Mean brightness inside the content region — what the audience actually sees,
    /// regardless of how much black surrounds it.
    var contentBrightness: Double {
        guard let box = interiorBox else { return 0 }
        let values = indices(in: box).map { cells[$0] }
        return values.reduce(0, +) / Double(values.count)
    }

    /// True when the content region is a flat field — a blanked screen.
    var contentIsUniform: Bool {
        guard let box = interiorBox else { return true }
        let values = indices(in: box).map { cells[$0] }
        let mean = values.reduce(0, +) / Double(values.count)
        return values.allSatisfy { abs($0 - mean) < 0.08 }
    }

    /// The content box minus its border ring.
    ///
    /// Downsampling blends the edge of the picture against whatever surrounds it, so
    /// boundary cells are neither one thing nor the other. Brightness and uniformity are
    /// properties of the interior.
    private var interiorBox: (minX: Int, minY: Int, maxX: Int, maxY: Int)? {
        guard let box = contentBox else { return nil }
        guard box.maxX - box.minX >= 2, box.maxY - box.minY >= 2 else { return box }
        return (box.minX + 1, box.minY + 1, box.maxX - 1, box.maxY - 1)
    }

    private func indices(in box: (minX: Int, minY: Int, maxX: Int, maxY: Int)) -> [Int] {
        var result: [Int] = []
        for y in box.minY ... box.maxY {
            for x in box.minX ... box.maxX {
                result.append(y * Self.gridSize + x)
            }
        }
        return result
    }

    // MARK: - Comparison

    /// Mean absolute difference per cell across the content region of either frame,
    /// 0...1. Restricting to the content makes the measure independent of how much
    /// dead space surrounds the picture.
    func distance(to other: ScreenFingerprint) -> Double {
        guard !cells.isEmpty, cells.count == other.cells.count else { return .infinity }

        let region: [Int]
        switch (contentBox, other.contentBox) {
        case let (lhs?, rhs?):
            region = indices(in: (
                minX: min(lhs.minX, rhs.minX), minY: min(lhs.minY, rhs.minY),
                maxX: max(lhs.maxX, rhs.maxX), maxY: max(lhs.maxY, rhs.maxY)
            ))
        case let (lhs?, nil):
            region = indices(in: lhs)
        case let (nil, rhs?):
            region = indices(in: rhs)
        case (nil, nil):
            return 0  // both dark
        }

        let total = region.reduce(0.0) { $0 + abs(cells[$1] - other.cells[$1]) }
        return total / Double(region.count)
    }
}
