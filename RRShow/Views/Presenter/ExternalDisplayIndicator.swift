import SwiftUI

/// Status chip telling the presenter whether the room is actually seeing anything.
struct ExternalDisplayIndicator: View {

    @Environment(PresentationViewModel.self) private var model

    private var monitor: ExternalDisplayMonitor { .shared }

    var body: some View {
        if monitor.isConnected {
            Label {
                Text(model.isBlanked ? model.blankMode.displayName : "On Air")
                    .font(.caption.weight(.medium))
            } icon: {
                Image(systemName: model.isBlanked ? "tv.slash" : "tv")
                    .font(.caption)
            }
            .foregroundStyle(model.isBlanked ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                Capsule().fill(.quaternary.opacity(0.4))
            }
            .help(monitor.displayDescription.map { "Audience display · \($0)" } ?? "Audience display connected")
        }
    }
}
