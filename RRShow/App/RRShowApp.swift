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
    }
}
