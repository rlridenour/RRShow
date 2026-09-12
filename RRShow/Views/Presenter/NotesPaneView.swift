import SwiftUI

/// The speaker-notes half of the page.
struct NotesPaneView: View {

    let pageIndex: Int
    var cornerRadius: CGFloat = 6

    @Environment(PresentationViewModel.self) private var model

    var body: some View {
        if model.hasNotes {
            SlideImageView(
                region: .notes,
                pageIndex: pageIndex,
                background: PresenterPalette.well,
                cornerRadius: cornerRadius
            )
        } else {
            PlaceholderPane(
                systemImage: "note.text",
                title: "No Notes Frame",
                message: "This deck is set to a standard layout. Choose a split layout if it was compiled with notes on a second screen."
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

/// The next slide, or an end-of-deck marker.
struct NextSlidePaneView: View {

    var cornerRadius: CGFloat = 6

    @Environment(PresentationViewModel.self) private var model

    var body: some View {
        if let nextPageIndex = model.nextPageIndex {
            SlidePaneView(
                pageIndex: nextPageIndex,
                allowsSwipeNavigation: false,
                cornerRadius: cornerRadius
            )
        } else {
            PlaceholderPane(
                systemImage: "flag.checkered",
                title: "End of Presentation",
                message: nil
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

struct PlaceholderPane: View {

    let systemImage: String
    let title: String
    var message: String?

    var body: some View {
        ZStack {
            PresenterPalette.well
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                Text(title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                if let message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .padding(12)
        }
    }
}
