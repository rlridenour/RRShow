import Foundation

/// What a touch on the current slide does.
///
/// The three are mutually exclusive because they all want the same pixels: paging needs
/// the swipe, the Pencil canvas needs the whole surface, and the laser needs to follow
/// the finger without leaving a mark.
enum SlideInteraction: String, CaseIterable, Identifiable, Sendable {
    /// Swipe to page. The default.
    case navigate
    /// Apple Pencil markup.
    case markup
    /// A glowing dot on the audience display, following finger or Pencil hover.
    case laser

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .navigate: "Navigate"
        case .markup: "Markup"
        case .laser: "Laser Pointer"
        }
    }

    var systemImage: String {
        switch self {
        case .navigate: "hand.draw"
        case .markup: "pencil.tip.crop.circle"
        case .laser: "dot.circle.and.hand.point.up.left.fill"
        }
    }
}
