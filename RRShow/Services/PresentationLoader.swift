import Foundation

/// A deck that has been imported, opened and inspected.
struct LoadedPresentation: Sendable {
    let service: PDFDocumentService
    let document: PresentationDocument
}

/// Turns a URL from the outside world into a `LoadedPresentation`.
enum PresentationLoader {

    /// Imports (copies) then opens a picked or dropped file.
    static func load(from sourceURL: URL) throws -> LoadedPresentation {
        let localURL = try DocumentImporter.importDocument(at: sourceURL)
        return try open(localURL)
    }

    /// Opens a file that already lives in the container — no copy.
    static func open(_ url: URL) throws -> LoadedPresentation {
        let service = try PDFDocumentService(url: url)
        let geometries = service.pageGeometries
        let document = PresentationDocument(
            url: url,
            title: url.deletingPathExtension().lastPathComponent,
            pageGeometries: geometries,
            detectedLayout: SlideLayoutDetector.detectLayout(for: geometries)
        )
        return LoadedPresentation(service: service, document: document)
    }
}
