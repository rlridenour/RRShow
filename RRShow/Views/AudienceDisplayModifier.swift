import SwiftUI

extension View {

    /// Offers `AudienceView` to a connected display.
    ///
    /// Two eras, because the deployment target spans both.
    ///
    /// From iOS 27 the audience display is a **scene accessory**: the app declares what
    /// content to provide and the system decides when and where to present it. Nothing
    /// arrives unasked — an app that does not register an accessory gets a mirror of the
    /// presenter's screen on the projector, notes and controls and all, which is exactly
    /// what happened here when the iPad moved to the release that introduced it.
    ///
    /// Before iOS 27 the system created the scene itself from the
    /// `UIWindowSceneSessionRoleExternalDisplayNonInteractive` configuration in
    /// `Config/Info.plist`, and `ExternalDisplaySceneDelegate` filled it. That path stays
    /// for iOS 17 through 26, and can go when the deployment target reaches 27.
    ///
    /// Mac Catalyst has neither, which is what the audience `WindowGroup` is for.
    @ViewBuilder
    func audienceDisplay(_ model: PresentationViewModel) -> some View {
#if targetEnvironment(macCatalyst)
        self
#else
        if #available(iOS 27.0, *) {
            self.sceneAccessory {
                ExternalNonInteractiveAccessory {
                    AudienceView()
                        .environment(model)
                        .preferredColorScheme(.dark)
                }
            }
        } else {
            self
        }
#endif
    }
}
