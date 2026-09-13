import SwiftUI

/// Paging controls along the bottom of the presenter screen.
struct TransportBar: View {

    @Environment(PresentationViewModel.self) private var model

    @State private var isShowingSlideGrid = false

    var body: some View {
        HStack(spacing: 14) {
            Button {
                model.goToPreviousPage()
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 28)
            }
            .disabled(!model.canGoToPreviousPage)
            .keyboardShortcut(.leftArrow, modifiers: .command)
            .accessibilityIdentifier(AccessibilityID.Presenter.previousSlide)

            Button {
                model.goToNextPage()
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 28)
            }
            .disabled(!model.canGoToNextPage)
            .keyboardShortcut(.rightArrow, modifiers: .command)
            .accessibilityIdentifier(AccessibilityID.Presenter.nextSlide)

            Button {
                isShowingSlideGrid = true
            } label: {
                Text(model.pagePositionLabel)
                    .font(.callout.monospacedDigit())
                    .frame(minWidth: 72)
            }
            .help("Go to slide")
            .accessibilityIdentifier(AccessibilityID.Presenter.pagePosition)

            if model.pageCount > 1 {
                Slider(
                    value: Binding(
                        get: { Double(model.currentPageIndex) },
                        set: { model.go(to: Int($0.rounded())) }
                    ),
                    in: 0 ... Double(model.pageCount - 1),
                    step: 1
                )
                .frame(minWidth: 80)
            }

            TimerChip()

            ExternalDisplayIndicator()

            blankControls
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(PresenterPalette.chrome)
        .sheet(isPresented: $isShowingSlideGrid) {
            SlideGridView()
        }
    }

    private var blankControls: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) { model.toggleBlank(.black) }
            } label: {
                Image(systemName: "moon.fill")
            }
            .tint(model.blankMode == .black ? .accentColor : nil)
            .help("Black the audience screen (B)")
            .accessibilityIdentifier(AccessibilityID.Presenter.blankBlack)

            Button {
                withAnimation(.easeOut(duration: 0.15)) { model.toggleBlank(.white) }
            } label: {
                Image(systemName: "sun.max.fill")
            }
            .tint(model.blankMode == .white ? .accentColor : nil)
            .help("White the audience screen (W)")
            .accessibilityIdentifier(AccessibilityID.Presenter.blankWhite)
        }
    }
}
