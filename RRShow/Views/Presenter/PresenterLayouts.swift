import SwiftUI

/// Dispatches to whichever arrangement the presenter has chosen.
struct PresenterLayoutContainer: View {

    @Environment(PresentationViewModel.self) private var model

    var body: some View {
        Group {
            switch model.effectiveLayoutMode {
            case .sideBySide: SideBySideLayout()
            case .threePane: ThreePaneLayout()
            case .speakerFocused: SpeakerFocusedLayout()
            case .fullSlide: FullSlideLayout()
            }
        }
        .padding(16)
    }
}

/// Shared spacing so the four layouts read as one family.
private enum Metrics {
    static let gap: CGFloat = 14
    /// Below this width the iPad is in portrait or a narrow split view, and
    /// side-by-side arrangements stack instead.
    static func isWide(_ size: CGSize) -> Bool { size.width > size.height * 1.15 }
}

// MARK: - 1. Side by Side

/// Current slide beside the current notes.
struct SideBySideLayout: View {

    @Environment(PresentationViewModel.self) private var model

    var body: some View {
        GeometryReader { proxy in
            if Metrics.isWide(proxy.size) {
                HStack(spacing: Metrics.gap) {
                    slidePane
                        // The slide takes the larger share; notes reflow into whatever is left.
                        .frame(width: (proxy.size.width - Metrics.gap) * 0.56)
                    notesPane
                }
            } else {
                VStack(spacing: Metrics.gap) {
                    slidePane
                        .frame(height: (proxy.size.height - Metrics.gap) * 0.5)
                    notesPane
                }
            }
        }
    }

    private var slidePane: some View {
        PresenterPane(
            title: "Slide",
            subtitle: model.pagePositionLabel,
            aspectRatio: model.slideAspectRatio
        ) {
            SlidePaneView(pageIndex: model.currentPageIndex, isMarkupSurface: true)
        }
    }

    private var notesPane: some View {
        PresenterPane(title: "Notes", aspectRatio: model.notesAspectRatio) {
            NotesPaneView(pageIndex: model.currentPageIndex)
        }
    }
}

// MARK: - 2. Three Pane

/// Current slide large, with the next slide and the notes stacked beside it.
struct ThreePaneLayout: View {

    @Environment(PresentationViewModel.self) private var model

    var body: some View {
        GeometryReader { proxy in
            if Metrics.isWide(proxy.size) {
                HStack(spacing: Metrics.gap) {
                    currentSlidePane
                        .frame(width: (proxy.size.width - Metrics.gap) * 0.62)
                    VStack(spacing: Metrics.gap) {
                        nextSlidePane
                            .frame(height: (proxy.size.height - Metrics.gap) * 0.42)
                        notesPane
                    }
                }
            } else {
                VStack(spacing: Metrics.gap) {
                    currentSlidePane
                        .frame(height: (proxy.size.height - Metrics.gap) * 0.46)
                    HStack(spacing: Metrics.gap) {
                        nextSlidePane
                            .frame(width: (proxy.size.width - Metrics.gap) * 0.42)
                        notesPane
                    }
                }
            }
        }
    }

    private var currentSlidePane: some View {
        PresenterPane(
            title: "Current Slide",
            subtitle: model.pagePositionLabel,
            aspectRatio: model.slideAspectRatio
        ) {
            SlidePaneView(pageIndex: model.currentPageIndex, isMarkupSurface: true)
        }
    }

    private var nextSlidePane: some View {
        PresenterPane(
            title: "Next",
            subtitle: model.nextPageIndex.map { "\($0 + 1)" },
            aspectRatio: model.slideAspectRatio
        ) {
            NextSlidePaneView()
        }
    }

    private var notesPane: some View {
        PresenterPane(title: "Notes") {
            NotesPaneView(pageIndex: model.currentPageIndex)
        }
    }
}

// MARK: - 3. Speaker Focused

/// Notes dominate the screen; the slides ride along as a narrow reference column.
struct SpeakerFocusedLayout: View {

    @Environment(PresentationViewModel.self) private var model

    var body: some View {
        GeometryReader { proxy in
            if Metrics.isWide(proxy.size) {
                HStack(spacing: Metrics.gap) {
                    notesPane
                    slideColumn(width: (proxy.size.width - Metrics.gap) * 0.26)
                        .frame(width: (proxy.size.width - Metrics.gap) * 0.26)
                }
            } else {
                VStack(spacing: Metrics.gap) {
                    notesPane
                    HStack(spacing: Metrics.gap) {
                        currentSlidePane
                        nextSlidePane
                    }
                    .frame(height: (proxy.size.height - Metrics.gap) * 0.26)
                }
            }
        }
    }

    private var notesPane: some View {
        PresenterPane(
            title: "Notes",
            subtitle: model.pagePositionLabel,
            aspectRatio: model.notesAspectRatio
        ) {
            NotesPaneView(pageIndex: model.currentPageIndex, cornerRadius: 8)
        }
    }

    private func slideColumn(width: CGFloat) -> some View {
        VStack(spacing: Metrics.gap) {
            currentSlidePane
                // Pin each thumbnail to the slide's own aspect ratio so the column
                // does not stretch them to fill leftover height.
                .frame(height: width / max(model.slideAspectRatio, 0.1) + 18)
            nextSlidePane
                .frame(height: width / max(model.slideAspectRatio, 0.1) + 18)
            Spacer(minLength: 0)
        }
    }

    private var currentSlidePane: some View {
        PresenterPane(title: "Current", aspectRatio: model.slideAspectRatio, isCompact: true) {
            SlidePaneView(pageIndex: model.currentPageIndex, isMarkupSurface: true, cornerRadius: 4)
        }
    }

    private var nextSlidePane: some View {
        PresenterPane(title: "Next", aspectRatio: model.slideAspectRatio, isCompact: true) {
            NextSlidePaneView(cornerRadius: 4)
        }
    }
}

// MARK: - 4. Full Slide

/// The slide gets the whole screen; notes live in a drawer that slides up from the bottom.
struct FullSlideLayout: View {

    @Environment(PresentationViewModel.self) private var model

    private var isDrawerOpen: Bool { model.hasNotes && model.isNotesDrawerExpanded }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: Metrics.gap) {
                PresenterPane(
                    title: "Slide",
                    subtitle: model.pagePositionLabel,
                    aspectRatio: model.slideAspectRatio
                ) {
                    SlidePaneView(pageIndex: model.currentPageIndex, isMarkupSurface: true, cornerRadius: 8)
                }

                if model.hasNotes {
                    drawer(maxHeight: proxy.size.height)
                }
            }
        }
    }

    private func drawer(maxHeight: CGFloat) -> some View {
        VStack(spacing: 6) {
            Button {
                withAnimation(.snappy(duration: 0.25)) { model.toggleNotesDrawer() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isDrawerOpen ? "chevron.down" : "chevron.up")
                        .font(.caption2.weight(.bold))
                    Text("NOTES")
                        .font(.caption2.weight(.semibold))
                        .tracking(0.8)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.secondary)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if isDrawerOpen {
                NotesPaneView(pageIndex: model.currentPageIndex, cornerRadius: 8)
                    .frame(height: maxHeight * 0.3)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .clipped()
    }
}
