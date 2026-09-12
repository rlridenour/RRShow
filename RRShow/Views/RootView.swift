import SwiftUI

struct RootView: View {

    @Environment(PresentationViewModel.self) private var model

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            Group {
                if model.hasDocument {
                    PresenterView()
                } else {
                    WelcomeView()
                }
            }
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            ),
            presenting: model.errorMessage
        ) { _ in
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: { message in
            Text(message)
        }
        .onOpenURL { url in
            Task { await model.open(pickedURL: url) }
        }
        #if DEBUG
        .task { await model.applyDebugLaunchOptions() }
        #endif
    }
}
