import SwiftUI
import UIKit
import os

/// Records what the app can see of an attached display, and nothing else.
///
/// This exists because of a failure that is invisible from the lectern and leaves nothing
/// behind. From iOS 27 the audience display is a scene accessory the app registers — see
/// `View.audienceDisplay(_:)` — and an app that registers none is simply mirrored onto the
/// projector: notes, next slide, controls and all. The system says nothing about it. The
/// only trace is on the other side, in SpringBoard's log:
///
///     [DisplayControlling] Updating current non interactive presentation
///                          from nothing to app<com.rlridenour.RRShow>
///     [DisplayControlling] [(null)] Stop hosting non interactive scene
///
/// Diagnosing that from the app's own silence took a day. One line per look is cheap
/// insurance against repeating it.

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
