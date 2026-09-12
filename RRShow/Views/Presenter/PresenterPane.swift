import SwiftUI

/// A labelled pane. Every region of the presenter screen is one of these, so the
/// captions line up across all four layouts.
struct PresenterPane<Content: View>: View {

    let title: String
    var subtitle: String?
    /// When set, the content hugs this ratio and is centred in whatever space is left,
    /// instead of stretching and letterboxing itself with black.
    var aspectRatio: CGFloat?
    var isCompact = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 3 : 6) {
            HStack(spacing: 6) {
                Text(title.uppercased())
                    .font(isCompact ? .system(size: 9, weight: .semibold) : .caption2.weight(.semibold))
                    .tracking(0.8)
                if let subtitle {
                    Text(subtitle)
                        .font(isCompact ? .system(size: 9) : .caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.secondary)
            .lineLimit(1)

            content()
                .aspectRatio(aspectRatio, contentMode: .fit)
                // Top-aligned so the content sits directly under its caption. Centring
                // it instead leaves the label stranded above a gap whenever the pane is
                // taller than the slide's aspect ratio allows — which, with 16:9 content
                // on a 4:3 iPad, is most of the time.
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}
