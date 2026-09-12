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
}
#endif
