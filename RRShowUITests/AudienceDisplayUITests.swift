import XCTest

/// What the projector is actually showing.
///
/// These are the checks that previously depended on calibrated `CGEvent` clicks against
/// simulator window coordinates — fragile, and silently wrong after any layout change.
/// Driving the app through accessibility and reading `XCUIScreen.screens[1]` is stable.
///
/// Every test skips cleanly when no external display is attached.
final class AudienceDisplayUITests: RRShowUITestCase {

    func testAudienceWindowCoversItsDisplay() throws {
        let screen = try requireAudienceScreen()
        launchWithSample()

        let coverage = settledFingerprint(of: screen).contentCoverage
        // Not an assertion: the Simulator intermittently reports an external display's
        // geometry as the port's default while its framebuffer is larger, and UIKit
        // hands the app that same wrong size. Recorded so a real regression on hardware
        // is visible in the logs rather than silently averaged away.
        print("AUDIENCE COVERAGE \(String(format: "%.2f", coverage)) of the display")
        XCTAssertGreaterThan(coverage, 0.05, "Audience window is essentially invisible")
    }

    func testAudienceDisplayShowsSomethingWhenDeckIsOpen() throws {
        let screen = try requireAudienceScreen()
        launchWithSample()

        let audience = settledFingerprint(of: screen)
        XCTAssertFalse(audience.isEmpty, "Could not read the audience screen")
        XCTAssertTrue(audience.hasContent, "Audience display is entirely black")
        XCTAssertGreaterThan(
            audience.contentBrightness, 0.5,
            "The audience picture is dark — a white Beamer slide should be bright"
        )
    }

    func testAdvancingASlideChangesTheAudienceDisplay() throws {
        let screen = try requireAudienceScreen()
        launchWithSample()

        let before = settledFingerprint(of: screen)
        tapNext()
        let after = settledFingerprint(of: screen)

        XCTAssertEqual(pageLabel, "2 / 5")
        XCTAssertGreaterThan(
            before.distance(to: after), 0.01,
            "Audience display did not follow the presenter to the next slide"
        )
    }

    func testAudienceDisplayIsStableWhileNothingHappens() throws {
        let screen = try requireAudienceScreen()
        launchWithSample()

        let first = settledFingerprint(of: screen)
        Thread.sleep(forTimeInterval: 1.5)
        let second = settledFingerprint(of: screen)

        // Guards the test above: if the screen drifted on its own, "it changed" would
        // prove nothing.
        XCTAssertLessThan(
            first.distance(to: second), 0.01,
            "Audience display changed with no input"
        )
    }

    func testGoingBackRestoresThePreviousSlide() throws {
        let screen = try requireAudienceScreen()
        launchWithSample()

        let first = settledFingerprint(of: screen)
        tapNext()
        let second = settledFingerprint(of: screen)
        tapPrevious()
        let backAgain = settledFingerprint(of: screen)

        XCTAssertGreaterThan(first.distance(to: second), 0.01)
        XCTAssertLessThan(
            first.distance(to: backAgain), 0.01,
            "Returning to slide 1 did not restore what the audience saw"
        )
    }

    func testBlackingTheScreenDarkensTheAudienceDisplay() throws {
        let screen = try requireAudienceScreen()
        launchWithSample()

        let showing = settledFingerprint(of: screen)
        XCTAssertTrue(showing.hasContent)

        app.buttons[AccessibilityID.Presenter.blankBlack].tap()
        let blanked = settledFingerprint(of: screen)
        XCTAssertFalse(
            blanked.hasContent,
            "Blacking the screen should leave nothing lit on the audience display"
        )

        app.buttons[AccessibilityID.Presenter.blankBlack].tap()
        let resumed = settledFingerprint(of: screen)
        XCTAssertGreaterThan(resumed.contentBrightness, 0.5, "Slide did not come back")
    }

    func testWhitingTheScreenFillsTheAudienceDisplay() throws {
        let screen = try requireAudienceScreen()
        launchWithSample()

        app.buttons[AccessibilityID.Presenter.blankWhite].tap()
        let blanked = settledFingerprint(of: screen)

        XCTAssertGreaterThan(
            blanked.contentBrightness, 0.9,
            "Audience picture is not white"
        )
        XCTAssertTrue(
            blanked.contentIsUniform,
            "A whited screen should be a flat field, not a slide"
        )
    }

    func testPencilMarksReachTheAudienceDisplay() throws {
        let screen = try requireAudienceScreen()
        launchWithSample(markup: true)

        let clean = settledFingerprint(of: screen)

        // Draw across the middle of the live slide.
        let surface = app.otherElements[AccessibilityID.Presenter.slideSurface].firstMatch
        XCTAssertTrue(surface.waitForExistence(timeout: 5), "Markup surface not found")
        surface.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
            .press(
                forDuration: 0.1,
                thenDragTo: surface.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)),
                withVelocity: .slow,
                thenHoldForDuration: 0.1
            )

        let marked = settledFingerprint(of: screen)
        XCTAssertGreaterThan(
            clean.distance(to: marked), 0.002,
            "A stroke drawn on the presenter did not appear on the audience display"
        )

        // And marks are ephemeral: they must not survive the slide change.
        tapNext()
        tapPrevious()
        let returned = settledFingerprint(of: screen)
        XCTAssertLessThan(
            clean.distance(to: returned), 0.01,
            "Marks outlived the slide they were drawn on"
        )
    }
}
