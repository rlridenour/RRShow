import SwiftUI
import UIKit

/// Owns the window on the projector.
///
/// iOS has no SwiftUI scene type for external displays, so the audience window is built
/// in UIKit. The system creates a scene with the
/// `windowExternalDisplayNonInteractive` role whenever a display is attached over
/// AirPlay, HDMI or USB-C; `Info.plist` points that role at this class, and everything
/// below is just hosting `AudienceView` in it.
///
/// `PresentationViewModel.shared` is injected into the environment so the view tree
/// here behaves exactly like the one in the presenter window — same renderer, same
/// cache, same page.
final class ExternalDisplaySceneDelegate: NSObject, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        // Belt and braces: the window already adopts the scene's size, but stating it
        // means the frame and `windowScene(_:didUpdate:)` below share one source of
        // truth for how big the audience surface is.
        window.frame = windowScene.coordinateSpace.bounds
        let host = UIHostingController(
            rootView: AudienceView()
                .environment(PresentationViewModel.shared)
        )
        // The projector shows black wherever the slide does not reach, never the
        // system background colour.
        host.view.backgroundColor = .black
        // The projector is always a dark surface; never let it pick up light mode.
        host.overrideUserInterfaceStyle = .dark
        window.rootViewController = host
        window.backgroundColor = .black
        window.isHidden = false

        self.window = window

        MainActor.assumeIsolated {
            ExternalDisplayMonitor.shared.displayConnected(windowScene)
        }
    }

    /// The display changed mode, or was rotated. Re-fit the window.
    func windowScene(
        _ windowScene: UIWindowScene,
        didUpdate previousCoordinateSpace: UICoordinateSpace,
        interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation,
        traitCollection previousTraitCollection: UITraitCollection
    ) {
        window?.frame = windowScene.coordinateSpace.bounds
        MainActor.assumeIsolated {
            ExternalDisplayMonitor.shared.displayConnected(windowScene)
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        guard let windowScene = scene as? UIWindowScene else { return }
        MainActor.assumeIsolated {
            ExternalDisplayMonitor.shared.displayDisconnected(windowScene)
        }
        window = nil
    }
}
