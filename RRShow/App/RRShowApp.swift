import SwiftUI

@main
struct RRShowApp: App {

    // Shared so the external-display scene, built outside SwiftUI, sees the same session.
    @State private var model = PresentationViewModel.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(model.theme.colorScheme)
        }

        // A second window carrying the audience view.
        //
        // On iPadOS a connected display gets its own scene automatically, via
        // `ExternalDisplaySceneDelegate`. On Mac Catalyst no such scene arrives — an
        // attached display simply never reaches the app — so the audience output has to
        // be a window the presenter places: drag it to the projector and full-screen it
        // there, the way every other Mac presentation app works.
        //
        // It is a plain `WindowGroup` rather than anything display-aware, so it is also
        // the fallback on iPad if the automatic scene ever fails to appear.
        WindowGroup(id: AudienceWindow.id) {
            AudienceView()
                .environment(model)
                .preferredColorScheme(.dark)
        }
    }
}

enum AudienceWindow {
    static let id = "audience"
}
