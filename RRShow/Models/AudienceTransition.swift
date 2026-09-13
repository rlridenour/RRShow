import Foundation

/// How the audience display moves between slides.
enum AudienceTransition: String, CaseIterable, Identifiable, Sendable {
    /// One frame changes. Cheapest thing a display can be asked to do.
    case cut
    /// A short dissolve. Softer in the room, but it turns one slide change into a burst
    /// of full-frame updates.
    case crossFade

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cut: "Cut"
        case .crossFade: "Cross-fade"
        }
    }

    var detail: String {
        switch self {
        case .cut: "One frame. Best over AirPlay."
        case .crossFade: "Softer, but sends many more frames."
        }
    }

    /// Duration handed to the renderer, or `nil` to swap straight over.
    var duration: Double? {
        switch self {
        case .cut: nil
        case .crossFade: 0.18
        }
    }

    /// A wired projector can absorb a dissolve happily; AirPlay carries the whole
    /// display over peer-to-peer Wi-Fi, where a burst of full-frame updates on every
    /// slide change is exactly the wrong thing to ask for. The Mac presents over AirPlay
    /// far more often than the iPad does, so it starts conservative.
    static var `default`: AudienceTransition {
        #if targetEnvironment(macCatalyst)
        .cut
        #else
        .crossFade
        #endif
    }
}

extension AudienceTransition {
    private static let defaultsKey = "audience.transition"

    static var restored: AudienceTransition {
        guard let raw = UserDefaults.standard.string(forKey: defaultsKey) else { return .default }
        return AudienceTransition(rawValue: raw) ?? .default
    }

    static func store(_ transition: AudienceTransition) {
        UserDefaults.standard.set(transition.rawValue, forKey: defaultsKey)
    }
}
