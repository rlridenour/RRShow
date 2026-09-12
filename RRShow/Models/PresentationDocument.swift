import CoreGraphics
import Foundation

/// An opened deck: where it lives, how big its pages are, and how they should be split.
struct PresentationDocument: Identifiable, Sendable, Equatable {
    let id: UUID
    /// A stable URL inside the app container. Imported files are copied here so the
    /// document stays readable after the security-scoped original goes away.
    let url: URL
    let title: String
    let pageCount: Int
    let pageGeometries: [PageGeometry]

    /// What `SlideLayoutDetector` concluded when the file was opened.
    let detectedLayout: SlideLayout
    /// What the app is actually using. Starts at `detectedLayout`; the user can override it.
    var layout: SlideLayout

    init(
        id: UUID = UUID(),
        url: URL,
        title: String,
        pageGeometries: [PageGeometry],
        detectedLayout: SlideLayout
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.pageCount = pageGeometries.count
        self.pageGeometries = pageGeometries
        self.detectedLayout = detectedLayout
        self.layout = detectedLayout
    }

    var isEmpty: Bool { pageCount == 0 }

    var pageIndices: Range<Int> { 0 ..< pageCount }

    func geometry(atPageIndex index: Int) -> PageGeometry? {
        pageGeometries.indices.contains(index) ? pageGeometries[index] : nil
    }

    /// Aspect ratio of the audience slide on a given page, falling back to the first page
    /// and then to 16:9 so views always have something to lay out against.
    func slideAspectRatio(atPageIndex index: Int = 0) -> CGFloat {
        let geometry = self.geometry(atPageIndex: index) ?? pageGeometries.first
        return geometry?.aspectRatio(of: .slide, layout: layout) ?? (16.0 / 9.0)
    }

    func notesAspectRatio(atPageIndex index: Int = 0) -> CGFloat? {
        let geometry = self.geometry(atPageIndex: index) ?? pageGeometries.first
        return geometry?.aspectRatio(of: .notes, layout: layout)
    }

    var hasNotes: Bool { layout.hasNotes }
}
