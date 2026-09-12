import SwiftUI

/// Override for the detected page split. Phase 1's "standard vs. split-screen" toggle,
/// with the notes position exposed for the less common Beamer options.
struct LayoutMenu: View {

    @Environment(PresentationViewModel.self) private var model

    var body: some View {
        Menu {
            Section("Page Layout") {
                Button {
                    model.setLayout(.standard)
                } label: {
                    Label("Standard", systemImage: model.layout == .standard ? "checkmark" : "rectangle")
                }

                ForEach(NotesPosition.allCases) { position in
                    let layout = SlideLayout.split(notes: position)
                    Button {
                        model.setLayout(layout)
                    } label: {
                        Label(
                            position.displayName,
                            systemImage: model.layout == layout ? "checkmark" : "rectangle.split.2x1"
                        )
                    }
                }
            }

            if !model.isUsingDetectedLayout, let detected = model.document?.detectedLayout {
                Section {
                    Button("Reset to Detected (\(detected.displayName))") {
                        model.resetLayoutToDetected()
                    }
                }
            }
        } label: {
            Label("Layout", systemImage: "rectangle.split.2x1")
        }
    }
}
