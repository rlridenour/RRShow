import SwiftUI

/// What the room sees.
///
/// Only ever the audience half of the page — never the notes, never any chrome —
/// drawn full-frame and letterboxed in black. Page changes cross-fade; blanking is
/// instant.
struct AudienceView: View {

    @Environment(PresentationViewModel.self) private var model

    /// Short enough to feel immediate from the back of a lecture hall, long enough not
    /// to flicker.
    private let transitionDuration: Double = 0.18

    var body: some View {
        ZStack {
            Color.black

            if model.hasDocument {
                slide
            } else {
                AudienceIdleView()
            }

            if let grayLevel = model.blankMode.grayLevel {
                Color(white: grayLevel)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: transitionDuration), value: model.blankMode)
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    /// Constrained to the slide's aspect ratio so the markup layer sits in exactly the
    /// same box as the image, letterboxing and all.
    private var slide: some View {
        ZStack {
            SlideImageView(
                region: .slide,
                pageIndex: model.currentPageIndex,
                background: .black,
                cornerRadius: 0,
                crossfade: transitionDuration
            )

            MarkupMirrorView(
                drawing: model.currentMarkup,
                liveStroke: model.liveStroke
            )

            LaserOverlay(point: model.laserPoint)
        }
        .aspectRatio(model.slideAspectRatio, contentMode: .fit)
    }
}

/// Shown on the projector before a deck is open — better than a blank screen while the
/// speaker is still setting up, and it confirms the display is actually working.
struct AudienceIdleView: View {

    var body: some View {
        // Explicit colours rather than semantic ones: this scene never inherits the
        // presenter window's colour scheme, so `.secondary` resolves against light mode
        // and renders all but invisible on the projector's black.
        VStack(spacing: 14) {
            Image(systemName: "rectangle.split.2x1")
                .font(.system(size: 44, weight: .ultraLight))
            Text("RRShow")
                .font(.system(size: 30, weight: .light))
                .tracking(2)
            Text("Ready — no presentation open")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.32))
        }
        .foregroundStyle(.white.opacity(0.5))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}
