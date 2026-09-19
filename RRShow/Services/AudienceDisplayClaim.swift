import SwiftUI
import UIKit
import os

/// Records what the app can see of an attached display, and nothing else.
///
/// This exists because of a failure that is invisible from the lectern and leaves nothing
/// behind. iPadOS decides whether an app may have its own scene on an attached display by
/// looking at the SDK its binary was linked against; since the stable release that
/// followed the iPadOS public beta, a binary linked against the iOS 27 SDK is not offered
/// one. SpringBoard nominates the app to own the display and then has nothing to host —
///
///     [DisplayControlling] Updating current non interactive presentation
///                          from nothing to app<com.rlridenour.RRShow>
///     [DisplayControlling] [(null)] Stop hosting non interactive scene
///
/// — and the projector quietly shows the presenter's own screen instead: notes, next
/// slide, controls and all. `Scripts/install-device.sh` is the workaround.
///
/// Nothing here can fix that; the scene is the system's to create, and asking for it
/// outright is refused ("the requested role
/// UIWindowSceneSessionRoleExternalDisplayNonInteractive is not supported"). What it can
/// do is leave a record, so the next time the projector shows the wrong thing there is
/// something in the log to read rather than three days of guessing.
@MainActor
enum AudienceDisplayClaim {

    private static var isObserving = false

    /// Starts watching, and records the situation as it stands.
    static func start() {
#if !targetEnvironment(macCatalyst)
        if !isObserving {
            isObserving = true
            // Mirroring registers as a capture of the main screen — the same machinery as
            // screen recording — so this fires when a display arrives and again when it
            // goes. The screen connect and disconnect notifications say the same thing
            // and have been deprecated since iOS 16.
            NotificationCenter.default.addObserver(
                forName: UIScreen.capturedDidChangeNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in AudienceDisplayClaim.log() }
            }
        }
        log()
#endif
    }

    private static func log() {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.session.role == .windowApplication }
        let captured = scene?.traitCollection.sceneCaptureState != .inactive
        let screens = UIScreen.screens.count

        DiagnosticLog.audienceDisplay.notice(
            """
            Audience display check: \(screens, privacy: .public) screen(s), \
            captured \(captured, privacy: .public), \
            audience scene \(ExternalDisplayMonitor.shared.isConnected, privacy: .public)
            """
        )
    }
}
