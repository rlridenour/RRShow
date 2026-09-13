import UIKit

/// Keeps the screen awake while a deck is open.
///
/// A presenter sets the iPad down and talks. With Auto-Lock at its default of two
/// minutes the device locks mid-sentence, and locking ends the AirPlay session — the
/// slide vanishes from the Apple TV and the presenter has to pick the iPad up and
/// reconnect. Video players get this behaviour for free from `AVPlayer`; anything that
/// holds the screen for minutes at a time has to ask for it.
///
/// Scoped to "a deck is open" rather than the whole app lifetime, so putting the deck
/// away lets the device sleep normally again.
@MainActor
enum ScreenSleepGuard {

    static var isPresenting = false {
        didSet {
            guard isPresenting != oldValue else { return }
            UIApplication.shared.isIdleTimerDisabled = isPresenting
        }
    }
}
