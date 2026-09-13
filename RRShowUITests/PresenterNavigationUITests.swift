import XCTest

/// Paging, blanking and mode toggles on the presenter's own screen.
final class PresenterNavigationUITests: RRShowUITestCase {

    func testOpensBundledSampleAtFirstSlide() {
        launchWithSample()
        XCTAssertEqual(pageLabel, "1 / 5")
    }

    func testNextAndPreviousMoveOneSlide() {
        launchWithSample()

        tapNext()
        XCTAssertEqual(pageLabel, "2 / 5")

        tapNext()
        XCTAssertEqual(pageLabel, "3 / 5")

        tapPrevious()
        XCTAssertEqual(pageLabel, "2 / 5")
    }

    func testPreviousIsDisabledOnFirstSlideAndNextOnLast() {
        launchWithSample()
        XCTAssertFalse(app.buttons[AccessibilityID.Presenter.previousSlide].isEnabled)

        launchWithSample(pageIndex: 4)
        XCTAssertEqual(pageLabel, "5 / 5")
        XCTAssertFalse(app.buttons[AccessibilityID.Presenter.nextSlide].isEnabled)
    }

    func testDebugLaunchArgumentLandsOnRequestedSlide() {
        launchWithSample(pageIndex: 3)
        XCTAssertEqual(pageLabel, "4 / 5")
    }

    func testEveryPresenterLayoutOpens() {
        for layout in ["sideBySide", "threePane", "speakerFocused", "fullSlide"] {
            launchWithSample(layout: layout)
            XCTAssertEqual(pageLabel, "1 / 5", "layout \(layout) failed to open")
            app.terminate()
        }
    }

    func testMarkupPaletteAppearsOnlyInMarkupMode() {
        launchWithSample()
        let clearButton = app.buttons[AccessibilityID.Markup.clearSlide]
        XCTAssertFalse(clearButton.exists, "Palette should be hidden until markup is on")

        app.buttons[AccessibilityID.Presenter.markupToggle].tap()
        XCTAssertTrue(clearButton.waitForExistence(timeout: 3))

        app.buttons[AccessibilityID.Presenter.markupToggle].tap()
        XCTAssertFalse(clearButton.waitForExistence(timeout: 1))
    }

    func testMarkupAndLaserAreMutuallyExclusive() {
        launchWithSample(markup: true)
        XCTAssertTrue(app.buttons[AccessibilityID.Markup.clearSlide].waitForExistence(timeout: 3))

        // Switching to the laser must retire the Pencil palette; both want the same pixels.
        app.buttons[AccessibilityID.Presenter.laserToggle].tap()
        XCTAssertFalse(app.buttons[AccessibilityID.Markup.clearSlide].waitForExistence(timeout: 2))
    }
}
