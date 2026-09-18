import Foundation
import os

/// Loggers for the things that cannot be reconstructed after a talk.
///
/// A lost audience display has three unrelated causes — the link dropped, the app left
/// the foreground, or the display changed mode — and the presenter sees the same thing
/// for all of them. Writing the app's own view of each event to the unified log at
/// notice level, which is persisted, means `log collect --device` afterwards tells them
/// apart in one query instead of three log archives.
enum DiagnosticLog {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.rlridenour.RRShow"

    /// The projector scene: connected, resized, disconnected, and the app state at the time.
    static let audienceDisplay = Logger(subsystem: subsystem, category: "AudienceDisplay")

    /// The presenter scene moving between foreground and background.
    static let lifecycle = Logger(subsystem: subsystem, category: "Lifecycle")
}
