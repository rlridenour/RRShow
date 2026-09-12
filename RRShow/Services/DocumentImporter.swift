import Foundation

/// Copies picked or dropped PDFs into the app container.
///
/// Files handed over by the document picker, by drag-and-drop, or by "Open in…" arrive
/// as security-scoped URLs whose access window closes as soon as the callback returns.
/// A presentation is read from disk continuously for the length of a lecture, so the
/// file is copied somewhere stable up front rather than fought over later.
enum DocumentImporter {

    enum Failure: LocalizedError {
        case accessDenied(URL)
        case copyFailed(URL, underlying: Error)
        case containerUnavailable

        var errorDescription: String? {
            switch self {
            case let .accessDenied(url):
                "RRShow does not have permission to read “\(url.lastPathComponent)”."
            case let .copyFailed(url, underlying):
                "Could not import “\(url.lastPathComponent)”: \(underlying.localizedDescription)"
            case .containerUnavailable:
                "RRShow could not find its documents folder."
            }
        }
    }

    static let folderName = "Presentations"

    /// `Documents/Presentations`, created on demand. Lives in `Documents` so imported
    /// decks show up over File Sharing and in the Files app.
    static func presentationsDirectory() throws -> URL {
        guard let documents = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else {
            throw Failure.containerUnavailable
        }
        let directory = documents.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true
            )
        }
        return directory
    }

    /// Copies `sourceURL` into the container and returns the stable local URL.
    ///
    /// A file already inside the container is returned untouched.
    static func importDocument(at sourceURL: URL) throws -> URL {
        let directory = try presentationsDirectory()

        if sourceURL.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL {
            return sourceURL
        }

        let destination = directory.appendingPathComponent(sourceURL.lastPathComponent)

        let needsScope = sourceURL.startAccessingSecurityScopedResource()
        defer { if needsScope { sourceURL.stopAccessingSecurityScopedResource() } }

        var coordinatorError: NSError?
        var copyError: Error?

        // Coordinated read so files still downloading from iCloud Drive are materialized.
        NSFileCoordinator().coordinate(
            readingItemAt: sourceURL, options: .withoutChanges, error: &coordinatorError
        ) { readableURL in
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: readableURL, to: destination)
            } catch {
                copyError = error
            }
        }

        if let coordinatorError {
            throw Failure.copyFailed(sourceURL, underlying: coordinatorError)
        }
        if let copyError {
            throw Failure.copyFailed(sourceURL, underlying: copyError)
        }
        return destination
    }

    /// Previously imported decks, newest first.
    static func importedDocuments() -> [URL] {
        guard let directory = try? presentationsDirectory() else { return [] }
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return contents
            .filter { $0.pathExtension.lowercased() == "pdf" }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                return lhsDate > rhsDate
            }
    }

    static func removeImportedDocument(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}
