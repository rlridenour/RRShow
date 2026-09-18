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

    /// When the last audience display went away, or `nil` while one is attached or
    /// the presenter has acknowledged the loss.
    ///
    /// The projector going blank mid-talk looks the same whatever caused it, and the
    /// presenter is looking at the room, not the iPad. This drives a banner on the
    /// presenter screen so the loss is at least announced.
    private(set) var lostDisplayAt: Date?

    var isConnected: Bool { !displays.isEmpty }

    /// Point size of the attached display, for the presenter's status chip.
    var displaySize: CGSize? { displays.values.first }

    var displayDescription: String? {
        guard let size = displaySize else { return nil }
        return "\(Int(size.width)) × \(Int(size.height))"
    }

    func displayConnected(_ scene: UIWindowScene) {
        displays[ObjectIdentifier(scene)] = scene.coordinateSpace.bounds.size
        lostDisplayAt = nil
    }

    func displayDisconnected(_ scene: UIWindowScene) {
        let wasConnected = displays.removeValue(forKey: ObjectIdentifier(scene)) != nil
        if wasConnected, displays.isEmpty {
            lostDisplayAt = Date()
        }
    }

    /// Hides the loss banner — the presenter dismissed it, or a new deck was opened.
    func clearDisplayLoss() {
        lostDisplayAt = nil
    }
}
