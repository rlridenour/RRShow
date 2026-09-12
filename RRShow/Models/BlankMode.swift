import Foundation

/// Blanks the audience output without leaving the deck — the "B" and "W" keys every
/// presenter remote and lecture-hall habit already expects.
enum BlankMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case none
    case black
    case white

    var id: String { rawValue }

    /// Grey level to paint, or `nil` when the slide should show through.
    var grayLevel: Double? {
        switch self {
        case .none: nil
        case .black: 0
        case .white: 1
        }
    }

    var displayName: String {
        switch self {
        case .none: "Showing Slide"
        case .black: "Black Screen"
        case .white: "White Screen"
        }
    }

    var systemImage: String {
        switch self {
        case .none: "rectangle.on.rectangle"
        case .black: "moon.fill"
        case .white: "sun.max.fill"
        }
    }
}
