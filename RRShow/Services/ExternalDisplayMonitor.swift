import SwiftUI
import UIKit

/// Tracks whether an audience display is attached, and how big it is.
///
/// The scene delegate reports connections here so the presenter interface can show
/// what the room is seeing without reaching into UIKit itself.
@MainActor
@Observable
final class ExternalDisplayMonitor {

    static let shared = ExternalDisplayMonitor()

    /// Connected audience scenes, keyed by identity so repeat connects cannot double-count.
    private(set) var displays: [ObjectIdentifier: CGSize] = [:]

    var isConnected: Bool { !displays.isEmpty }

    /// Point size of the attached display, for the presenter's status chip.
    var displaySize: CGSize? { displays.values.first }

    var displayDescription: String? {
        guard let size = displaySize else { return nil }
        return "\(Int(size.width)) × \(Int(size.height))"
    }

    func displayConnected(_ scene: UIWindowScene) {
        displays[ObjectIdentifier(scene)] = scene.coordinateSpace.bounds.size
    }

    func displayDisconnected(_ scene: UIWindowScene) {
        displays.removeValue(forKey: ObjectIdentifier(scene))
    }
}
