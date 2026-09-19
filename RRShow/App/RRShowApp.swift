import os
import SwiftUI

@main
struct RRShowApp: App {

    // Shared so the external-display scene, built outside SwiftUI, sees the same session.
    @State private var model = PresentationViewModel.shared

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(model.theme.colorScheme)
                .audienceDisplay(model)
                // The audience display follows the presenter scene out of the
                // foreground, so this is the other half of the disconnect story.
                .onChange(of: scenePhase) { _, phase in
                    DiagnosticLog.lifecycle.notice(
                        "Presenter scene \(Self.describe(phase), privacy: .public), deck open \(model.hasDocument)"
                    )
                    // A display attached while the app was away leaves nothing behind to
                    // notice on the way back, so re-check on every return to the front.
                    if phase == .active { AudienceDisplayClaim.start() }
                }
        }

        // A second window carrying the audience view.
        //
        // On iPadOS a connected display reaches the app on its own — as a scene accessory
        // from iOS 27, as an external-display scene before that. On Mac Catalyst neither
        // happens: an attached display simply never reaches the app, so the audience
        // output has to be a window the presenter places, dragged to the projector and
        // full-screened there, the way every other Mac presentation app works.
        //
        // It is a plain `WindowGroup` rather than anything display-aware, so it is also
        // the fallback on iPad if the automatic path ever fails to appear.
        WindowGroup(id: AudienceWindow.id) {
            AudienceView()
                .environment(model)
                .preferredColorScheme(.dark)
        }
    }
}

extension RRShowApp {
    private static func describe(_ phase: ScenePhase) -> String {
        switch phase {
        case .active: "active"
        case .inactive: "inactive"
        case .background: "background"
        @unknown default: "unknown"
        }
    }
}

enum AudienceWindow {
    static let id = "audience"
}
