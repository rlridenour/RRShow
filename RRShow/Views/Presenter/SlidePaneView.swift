import SwiftUI

/// The audience slide, plus the blanking overlay and swipe navigation.
struct SlidePaneView: View {

    let pageIndex: Int
    /// Swipe paging is disabled on preview panes (the next slide) and thumbnails.
    var allowsSwipeNavigation = true
    /// Only the pane showing the live slide hosts the Pencil canvas.
    var isMarkupSurface = false
    var cornerRadius: CGFloat = 6

    @Environment(PresentationViewModel.self) private var model

    var body: some View {
        ZStack {
            SlideImageView(region: .slide, pageIndex: pageIndex, cornerRadius: cornerRadius)

            if showsMarkup {
                MarkupCanvas(
                    drawing: model.currentMarkup,
                    revision: model.markupRevision,
                    tool: model.markupTool,
                    color: model.markupColor,
                    pencilOnly: model.markupPencilOnly,
                    onCommit: { model.updateCurrentMarkup($0) },
                    onLiveStroke: { model.updateLiveStroke($0) }
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }

            if showsLaser {
                LaserPointerSurface { model.updateLaserPoint($0) }
            }

            // The presenter sees the dot too, so they can aim without looking up.
            if isMarkupSurface, pageIndex == model.currentPageIndex {
                LaserOverlay(point: model.laserPoint)
            }

            if showsBlankOverlay, let grayLevel = model.blankMode.grayLevel {
                blankOverlay(grayLevel: grayLevel)
            }
        }
        // While the canvas is live it owns the touches, except in Pencil-only mode where
        // a finger is still free to page the deck.
        // `children: .contain` publishes the pane as an addressable container while
        // leaving what is inside it accessible.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            isMarkupSurface ? AccessibilityID.Presenter.slideSurface : ""
        )
        .gesture(
            swipeGesture,
            isEnabled: allowsSwipeNavigation
                && !showsLaser
                && (!showsMarkup || model.markupPencilOnly)
        )
    }

    /// Only the slide the audience is actually looking at gets blanked — a next-slide
    /// preview should keep showing what is coming.
    private var showsBlankOverlay: Bool {
        model.isBlanked && pageIndex == model.currentPageIndex
    }

    private var showsMarkup: Bool {
        isMarkupSurface && model.isMarkupEnabled && pageIndex == model.currentPageIndex
    }

    private var showsLaser: Bool {
        isMarkupSurface && model.isLaserEnabled && pageIndex == model.currentPageIndex
    }

    private func blankOverlay(grayLevel: Double) -> some View {
        ZStack {
            Color(white: grayLevel)

            VStack(spacing: 8) {
                Image(systemName: model.blankMode.systemImage)
                    .font(.title2)
                Text("Audience screen blanked")
                    .font(.callout.weight(.medium))
                Text("Tap, or press B / W / esc, to resume")
                    .font(.caption)
            }
            // Legible against whichever shade is being shown.
            .foregroundStyle(grayLevel > 0.5 ? .black.opacity(0.45) : .white.opacity(0.5))
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contentShape(.rect)
        .onTapGesture { model.clearBlank() }
        .transition(.opacity)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                // Ignore mostly-vertical drags so scrolling never advances a slide.
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.translation.width < 0 {
                    model.goToNextPage()
                } else {
                    model.goToPreviousPage()
                }
            }
    }
}
