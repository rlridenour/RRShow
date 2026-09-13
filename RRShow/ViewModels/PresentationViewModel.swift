import CoreGraphics
import Foundation
import Observation
import PencilKit
import UIKit

/// Session state for the deck currently being presented.
///
/// Owns the loaded document, the current page, and the layout override; everything the
/// presenter view, the thumbnail bar and (from Phase 3) the audience window read from.
@MainActor
@Observable
final class PresentationViewModel {

    /// The one session the presenter window and the external display both read from.
    ///
    /// A shared instance rather than an injected one because the audience scene is
    /// built by a `UISceneDelegate`, outside any SwiftUI environment, and by definition
    /// shows the same deck on the same page as the presenter. One deck, one session.
    static let shared = PresentationViewModel()

    private(set) var service: PDFDocumentService?
    private(set) var document: PresentationDocument?

    private(set) var currentPageIndex: Int = 0
    private(set) var isLoading = false
    var errorMessage: String?

    /// In-flight neighbour prefetch, cancelled whenever the page changes again.
    @ObservationIgnored private var prefetchTask: Task<Void, Never>?

    /// Files already imported into the container, newest first.
    private(set) var recentDocuments: [URL] = []

    init() {
        refreshRecentDocuments()
        observeMemoryWarnings()
    }

    private func observeMemoryWarnings() {
        Task { [weak self] in
            let warnings = NotificationCenter.default.notifications(
                named: UIApplication.didReceiveMemoryWarningNotification
            )
            for await _ in warnings {
                guard let self else { return }
                await self.service?.clearCache()
            }
        }
    }

    // MARK: - Derived state

    var hasDocument: Bool { document != nil }
    var pageCount: Int { document?.pageCount ?? 0 }
    var title: String { document?.title ?? "No Presentation" }
    var layout: SlideLayout { document?.layout ?? .beamerDualScreen }
    var hasNotes: Bool { document?.hasNotes ?? false }

    var canGoToNextPage: Bool { currentPageIndex + 1 < pageCount }
    var canGoToPreviousPage: Bool { currentPageIndex > 0 }

    var nextPageIndex: Int? { canGoToNextPage ? currentPageIndex + 1 : nil }

    /// 1-based "3 / 41" style label.
    var pagePositionLabel: String {
        guard pageCount > 0 else { return "—" }
        return "\(currentPageIndex + 1) / \(pageCount)"
    }

    var slideAspectRatio: CGFloat {
        document?.slideAspectRatio(atPageIndex: currentPageIndex) ?? (16.0 / 9.0)
    }

    var notesAspectRatio: CGFloat? {
        document?.notesAspectRatio(atPageIndex: currentPageIndex)
    }

    // MARK: - Loading

    /// Imports a picked or dropped file, then opens it.
    func open(pickedURL: URL) async {
        await load { try PresentationLoader.load(from: pickedURL) }
    }

    /// Opens a deck that already lives in the app container.
    func open(localURL: URL) async {
        await load { try PresentationLoader.open(localURL) }
    }

    /// Opens the Beamer deck bundled with the app, copying it into the container the
    /// same way a picked file would be.
    func openBundledSample() async {
        guard let url = Bundle.main.url(
            forResource: Self.bundledSampleName, withExtension: "pdf"
        ) else {
            errorMessage = "The sample presentation is missing from this build."
            return
        }
        await open(pickedURL: url)
    }

    static let bundledSampleName = "Sample Presentation"

    var hasBundledSample: Bool {
        Bundle.main.url(forResource: Self.bundledSampleName, withExtension: "pdf") != nil
    }

    func open(result: Result<[URL], Error>) async {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            await open(pickedURL: url)
        case let .failure(error):
            errorMessage = error.localizedDescription
        }
    }

    private func load(_ work: @escaping @Sendable () throws -> LoadedPresentation) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let loaded = try await Task.detached(priority: .userInitiated) {
                try work()
            }.value

            service = loaded.service
            document = loaded.document
            currentPageIndex = 0
            ScreenSleepGuard.isPresenting = true
            refreshRecentDocuments()
            prefetchNeighbors()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func closeDocument() {
        ScreenSleepGuard.isPresenting = false
        prefetchTask?.cancel()
        prefetchTask = nil
        service = nil
        document = nil
        currentPageIndex = 0
        blankMode = .none
        markupByPage.removeAll()
        liveStroke = nil
        laserPoint = nil
        slideInteraction = .navigate
        markupRevision += 1
        timer.stop()
        refreshRecentDocuments()
    }

    func refreshRecentDocuments() {
        recentDocuments = DocumentImporter.importedDocuments()
    }

    func deleteRecentDocument(at url: URL) {
        do {
            try DocumentImporter.removeImportedDocument(at: url)
            if document?.url == url { closeDocument() }
            refreshRecentDocuments()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

#if DEBUG
    /// Applies `DebugLaunchOptions` on first appearance. DEBUG builds only.
    func applyDebugLaunchOptions() async {
        if DebugLaunchOptions.opensBundledSample {
            await openBundledSample()
        } else if let name = DebugLaunchOptions.documentName,
                  let directory = try? DocumentImporter.presentationsDirectory() {
            await open(localURL: directory.appendingPathComponent(name))
        } else {
            return
        }

        if let pageIndex = DebugLaunchOptions.pageIndex {
            go(to: pageIndex)
        }
        if let blankMode = DebugLaunchOptions.blankMode {
            self.blankMode = blankMode
        }
        if DebugLaunchOptions.isMarkupEnabled {
            slideInteraction = .markup
        }
        if DebugLaunchOptions.isLaserEnabled {
            slideInteraction = .laser
        }
    }
#endif

    // MARK: - Navigation

    func goToNextPage() {
        go(to: currentPageIndex + 1)
    }

    func goToPreviousPage() {
        go(to: currentPageIndex - 1)
    }

    func goToFirstPage() {
        go(to: 0)
    }

    func goToLastPage() {
        go(to: pageCount - 1)
    }

    func go(to pageIndex: Int) {
        guard pageCount > 0 else { return }
        let clamped = min(max(pageIndex, 0), pageCount - 1)
        guard clamped != currentPageIndex else { return }

        if markupPersistence == .clearOnAdvance {
            markupByPage.removeValue(forKey: currentPageIndex)
        }
        liveStroke = nil
        laserPoint = nil

        currentPageIndex = clamped
        markupRevision += 1
        prefetchNeighbors()
    }

    // MARK: - Layout

    /// Overrides the detected split. Cached renders keyed by the old layout stay valid,
    /// so there is nothing to invalidate.
    func setLayout(_ layout: SlideLayout) {
        guard var document, document.layout != layout else { return }
        document.layout = layout
        self.document = document
        prefetchNeighbors()
    }

    func resetLayoutToDetected() {
        guard let document else { return }
        setLayout(document.detectedLayout)
    }

    var isUsingDetectedLayout: Bool {
        guard let document else { return true }
        return document.layout == document.detectedLayout
    }

    // MARK: - Presenter layout

    /// How the presenter's screen is arranged. Persisted across launches.
    var layoutMode: PresenterLayoutMode = .restored {
        didSet { PresenterLayoutMode.store(layoutMode) }
    }

    /// Chrome brightness for the presenter's screen. Persisted across launches.
    var theme: PresenterTheme = .restored {
        didSet { PresenterTheme.store(theme) }
    }

    /// Elapsed time and wall clock.
    let timer = PresentationTimer()

    /// State of the notes drawer in `.fullSlide` mode.
    var isNotesDrawerExpanded = true

    var showsThumbnailBar = true

    /// Whether the audience output is currently blanked, and to what.
    var blankMode: BlankMode = .none

    var isBlanked: Bool { blankMode != .none }

    /// The mode actually in use. A deck with no notes frame has nothing to fill the
    /// second pane with, so those modes collapse to `.fullSlide`.
    var effectiveLayoutMode: PresenterLayoutMode {
        layoutMode.requiresNotes && !hasNotes ? .fullSlide : layoutMode
    }

    /// True when `effectiveLayoutMode` had to override the presenter's choice.
    var isLayoutModeOverridden: Bool { effectiveLayoutMode != layoutMode }

    /// Pressing "B" while already black returns to the slide, matching every other
    /// presentation tool.
    func toggleBlank(_ mode: BlankMode) {
        blankMode = blankMode == mode ? .none : mode
    }

    func clearBlank() {
        blankMode = .none
    }

    func toggleNotesDrawer() {
        isNotesDrawerExpanded.toggle()
    }

    func toggleThumbnailBar() {
        showsThumbnailBar.toggle()
    }

    // MARK: - Markup

    /// What a touch on the current slide does. Defaults to paging.
    var slideInteraction: SlideInteraction = .navigate

    /// Where the laser is pointing, in `MarkupSpace` coordinates, or `nil` when the
    /// presenter is not pointing at anything.
    private(set) var laserPoint: CGPoint?

    var isMarkupEnabled: Bool { slideInteraction == .markup }
    var isLaserEnabled: Bool { slideInteraction == .laser }

    var markupTool: MarkupTool = .pen
    var markupColor: MarkupColor = .red
    var markupPersistence: MarkupPersistence = .clearOnAdvance
    /// When set, only an Apple Pencil draws — a finger still swipes to change slides.
    var markupPencilOnly = false

    /// Bumped whenever the canvas must reload from the model rather than the other way
    /// round — a page change, a clear, a new document. Lets the canvas distinguish an
    /// external change from the echo of its own commit.
    private(set) var markupRevision = 0

    /// Committed marks, in `MarkupSpace` coordinates, keyed by page.
    private(set) var markupByPage: [Int: PKDrawing] = [:]

    /// The stroke currently under the Pencil, in `MarkupSpace` coordinates.
    ///
    /// PencilKit does not publish a stroke until the pencil lifts, so this carries the
    /// in-flight one to the audience display; it is dropped the moment the finished
    /// stroke lands in `markupByPage`.
    private(set) var liveStroke: LiveStroke?

    var currentMarkup: PKDrawing {
        markupByPage[currentPageIndex] ?? PKDrawing()
    }

    func markup(forPage pageIndex: Int) -> PKDrawing {
        markupByPage[pageIndex] ?? PKDrawing()
    }

    var hasMarkupOnCurrentSlide: Bool {
        !currentMarkup.strokes.isEmpty || liveStroke != nil
    }

    var hasAnyMarkup: Bool {
        markupByPage.values.contains { !$0.strokes.isEmpty }
    }

    /// Switches into a mode, or back to paging if it is already active.
    func setInteraction(_ interaction: SlideInteraction) {
        slideInteraction = slideInteraction == interaction ? .navigate : interaction
        if !isMarkupEnabled { liveStroke = nil }
        if !isLaserEnabled { laserPoint = nil }
    }

    func toggleMarkup() {
        setInteraction(.markup)
    }

    func toggleLaser() {
        setInteraction(.laser)
    }

    func updateLaserPoint(_ point: CGPoint?) {
        laserPoint = point
    }

    /// Called when PencilKit commits a change on the current slide.
    func updateCurrentMarkup(_ drawing: PKDrawing) {
        if drawing.strokes.isEmpty {
            markupByPage.removeValue(forKey: currentPageIndex)
        } else {
            markupByPage[currentPageIndex] = drawing
        }
        // The committed drawing now contains whatever the preview was standing in for.
        liveStroke = nil
    }

    func updateLiveStroke(_ stroke: LiveStroke?) {
        liveStroke = stroke
    }

    func clearCurrentMarkup() {
        markupByPage.removeValue(forKey: currentPageIndex)
        liveStroke = nil
        markupRevision += 1
    }

    func clearAllMarkup() {
        markupByPage.removeAll()
        liveStroke = nil
        markupRevision += 1
    }

    // MARK: - Rendering

    /// Renders a region of a page. Views call this from `.task(id:)` with their own size.
    func image(
        region: SlideRegion,
        pageIndex: Int,
        width: CGFloat,
        scale: CGFloat
    ) async throws -> SlideImage? {
        guard let service, let document, width > 0 else { return nil }
        guard document.pageIndices.contains(pageIndex) else { return nil }
        guard document.layout.normalizedRect(for: region) != nil else { return nil }

        return try await service.image(
            pageIndex: pageIndex,
            region: region,
            layout: document.layout,
            targetWidth: width,
            scale: scale
        )
    }

    /// Warms the cache for the slides either side of the current one, so an advance
    /// lands on an already-rendered page.
    ///
    /// Only one prefetch runs at a time. Without that, clicking quickly through a deck
    /// spawned a detached task per advance, and each one's renders queued on the
    /// serialised renderer *ahead of* the slide now in view — the projector waiting on
    /// work for slides already gone by.
    private func prefetchNeighbors() {
        guard let service, let document else { return }
        let layout = document.layout
        let candidates = [currentPageIndex + 1, currentPageIndex - 1]
            .filter { document.pageIndices.contains($0) }
        guard !candidates.isEmpty else { return }

        prefetchTask?.cancel()
        prefetchTask = Task.detached(priority: .utility) {
            await service.prefetchSlides(pages: candidates, layout: layout)
        }
    }
}
