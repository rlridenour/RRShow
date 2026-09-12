import SwiftUI
import UIKit

/// How the presenter's own screen is lit.
///
/// The audience surface is always black and never consults this — a projector in a dark
/// room has exactly one correct background.
enum PresenterTheme: String, CaseIterable, Identifiable, Sendable {
    /// Follow the iPad. Useful for a presenter who already runs scheduled dark mode.
    case system
    /// Dark chrome. The default: a lit iPad is the brightest thing in a dark lecture
    /// hall, and dark chrome keeps the slide the brightest thing on the iPad.
    case dark
    /// Light chrome, for a bright room or a well-lit seminar table.
    case light

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "Match System"
        case .dark: "Dark"
        case .light: "Light"
        }
    }

    var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .dark: "moon.fill"
        case .light: "sun.max.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }
}

extension PresenterTheme {
    private static let defaultsKey = "presenter.theme"

    static var restored: PresenterTheme {
        guard let raw = UserDefaults.standard.string(forKey: defaultsKey) else { return .dark }
        return PresenterTheme(rawValue: raw) ?? .dark
    }

    static func store(_ theme: PresenterTheme) {
        UserDefaults.standard.set(theme.rawValue, forKey: defaultsKey)
    }
}

/// Chrome colours for the presenter interface, resolved per colour scheme.
///
/// Defined in code rather than the asset catalog so the two values sit side by side and
/// the relationship between them is readable.
enum PresenterPalette {

    /// Behind the pane layout.
    static let background = adaptive(dark: 0.08, light: 0.92)

    /// Transport bar and thumbnail strip.
    static let chrome = adaptive(dark: 0.11, light: 0.87)

    /// The well a notes frame or placeholder sits in.
    static let well = adaptive(dark: 0.13, light: 0.80)

    /// Floating palettes, which stay dark in both schemes so they read as tools rather
    /// than as part of the page.
    static let floating = Color.black.opacity(0.62)

    private static func adaptive(dark: CGFloat, light: CGFloat) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(white: traits.userInterfaceStyle == .dark ? dark : light, alpha: 1)
        })
    }
}
