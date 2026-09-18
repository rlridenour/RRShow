import Foundation

/// Identifiers the UI tests use to find controls.
///
/// This file is a member of both the app and the UI test target, so the two can never
/// drift apart — a renamed case breaks the test at compile time rather than at run time
/// with a mystifying "element not found".
enum AccessibilityID {

    enum Welcome {
        static let openPDF = "welcome.openPDF"
        static let openSample = "welcome.openSample"
    }

    enum Presenter {
        static let nextSlide = "presenter.nextSlide"
        static let previousSlide = "presenter.previousSlide"
        /// Button whose label reads "3 / 41".
        static let pagePosition = "presenter.pagePosition"
        static let blankBlack = "presenter.blank.black"
        static let blankWhite = "presenter.blank.white"
        static let markupToggle = "presenter.markupToggle"
        static let laserToggle = "presenter.laserToggle"
        static let thumbnailsToggle = "presenter.thumbnailsToggle"
        static let timer = "presenter.timer"
        static let close = "presenter.close"
        static let openAudienceWindow = "presenter.openAudienceWindow"
        /// Banner shown when the last audience display disconnects mid-deck.
        static let audienceDisplayLost = "presenter.audienceDisplayLost"
        static let audienceDisplayLostDismiss = "presenter.audienceDisplayLost.dismiss"
        /// The live slide surface, for drawing gestures. Published as an accessibility
        /// container — a bare identifier on a SwiftUI stack is not addressable.
        static let slideSurface = "presenter.slideSurface"
    }

    enum Markup {
        static let clearSlide = "markup.clearSlide"
        static func tool(_ name: String) -> String { "markup.tool.\(name)" }
    }
}
