#if DEBUG
import Foundation

/// Launch-argument hooks for driving a DEBUG build from a script — simulator
/// screenshots, UI tests, reproducing a bug on a particular slide.
///
/// `UserDefaults` folds `-key value` pairs from the launch arguments into its argument
/// domain, so there is nothing to parse and no release-build cost.
///
///     xcrun simctl launch <device> com.rlridenour.RRShow \
///         -RRShowOpenDocument sample.pdf \
///         -RRShowPageIndex 2 \
///         -presenter.layoutMode threePane
enum DebugLaunchOptions {

    /// Filename of a deck inside `Documents/Presentations` to open at launch.
    static var documentName: String? {
        UserDefaults.standard.string(forKey: "RRShowOpenDocument")
    }

    /// Zero-based page to land on.
    static var pageIndex: Int? {
        guard UserDefaults.standard.object(forKey: "RRShowPageIndex") != nil else { return nil }
        return UserDefaults.standard.integer(forKey: "RRShowPageIndex")
    }

    /// Open the deck bundled with the app, without depending on the container's
    /// contents. This is what the UI tests use: `-RRShowOpenDocument` reads from
    /// `Documents/Presentations`, which is empty until something has been imported.
    static var opensBundledSample: Bool {
        UserDefaults.standard.bool(forKey: "RRShowOpenBundledSample")
    }

    /// Turn the Pencil canvas on at launch.
    static var isMarkupEnabled: Bool {
        UserDefaults.standard.bool(forKey: "RRShowMarkup")
    }

    /// Turn the laser pointer on at launch.
    static var isLaserEnabled: Bool {
        UserDefaults.standard.bool(forKey: "RRShowLaser")
    }

    /// Blank the audience output at launch: "black" or "white".
    static var blankMode: BlankMode? {
        guard let raw = UserDefaults.standard.string(forKey: "RRShowBlankMode") else { return nil }
        return BlankMode(rawValue: raw)
    }

    /// Show the "audience display lost" banner at launch.
    ///
    /// The banner is otherwise reachable only by attaching a real display and taking it
    /// away again, which needs hardware — or a Simulator with an external display, which
    /// not every install has. This makes it inspectable from a script.
    static var simulatesDisplayLoss: Bool {
        UserDefaults.standard.bool(forKey: "RRShowSimulateDisplayLoss")
    }
}
#endif
