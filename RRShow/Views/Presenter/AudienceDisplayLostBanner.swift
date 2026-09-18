import SwiftUI

/// Announces that the projector went away.
///
/// The presenter is looking at the room, and the room sees whatever the iPad falls back
/// to — usually its own Home Screen, mirrored. The three causes need three different
/// fixes, and none of them is obvious from the lectern, so the banner names them.
struct AudienceDisplayLostBanner: View {

    /// When the display went away, shown as a live "n seconds ago".
    var lostAt: Date
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "tv.slash")
                .font(.title3)
                .foregroundStyle(Color.orange)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text("Audience display lost \(Text(lostAt, style: .relative)) ago")
                    .font(.subheadline.weight(.semibold))
                Text("If the projector shows the Home Screen, RRShow was sent to the background — reopen it and the slide comes back. Otherwise check the AirPlay or cable connection.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 28, height: 28)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
            .accessibilityIdentifier(AccessibilityID.Presenter.audienceDisplayLostDismiss)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 520)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(PresenterPalette.floating)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.5))
                }
        }
        .shadow(color: .black.opacity(0.35), radius: 10, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Presenter.audienceDisplayLost)
    }
}
