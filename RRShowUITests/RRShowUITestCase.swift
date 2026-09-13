import XCTest

/// Shared launch plumbing.
class RRShowUITestCase: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        cachedAudienceScreen = nil
        app?.terminate()
        app = nil
        super.tearDown()
    }

    /// Launches straight into the bundled sample deck.
    ///
    /// The `-RRShow…` arguments are the DEBUG launch hooks; `UserDefaults` folds them
    /// into its argument domain, so the app lands on a known slide in a known layout
    /// without the test having to tap its way there.
    @discardableResult
    func launchWithSample(
        layout: String = "threePane",
        pageIndex: Int = 0,
        markup: Bool = false,
        laser: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-RRShowOpenBundledSample", "YES",
            "-presenter.layoutMode", layout,
            "-RRShowPageIndex", String(pageIndex),
            "-presenter.theme", "dark",
        ]
        if markup { app.launchArguments += ["-RRShowMarkup", "YES"] }
        if laser { app.launchArguments += ["-RRShowLaser", "YES"] }
        app.launch()
        self.app = app

        // The deck is copied out of the bundle on launch, so give the presenter a moment
        // to replace the welcome screen. Waiting on a button rather than a container:
        // an identifier on a bare SwiftUI stack is not addressable by XCUITest.
        XCTAssertTrue(
            app.buttons[AccessibilityID.Presenter.pagePosition].waitForExistence(timeout: 20),
            "Presenter interface did not appear"
        )
        return app
    }

    var pageLabel: String {
        app.buttons[AccessibilityID.Presenter.pagePosition].label
    }

    func tapNext() {
        app.buttons[AccessibilityID.Presenter.nextSlide].tap()
    }

    func tapPrevious() {
        app.buttons[AccessibilityID.Presenter.previousSlide].tap()
    }

    /// The audience display, when one is attached to this simulator.
    ///
    /// Identified by screenshot size rather than by index. `XCUIScreen.screens` does not
    /// promise an order, and taking `screens[1]` silently captured the *presenter's*
    /// screen instead — which still changes when you page and still settles when you
    /// stop, so the relative assertions passed while testing the wrong display entirely.
    /// Only the absolute-brightness checks caught it.
    ///
    /// Throws a skip rather than failing: the suite has to pass on a machine with no
    /// external display configured.
    func requireAudienceScreen() throws -> XCUIScreen {
        if let cached = cachedAudienceScreen { return cached }

        let screens = XCUIScreen.screens
        try XCTSkipUnless(
            screens.count > 1,
            "No external display attached. Enable one in Simulator ▸ I/O ▸ External Displays."
        )

        let mainSize = XCUIScreen.main.screenshot().image.size
        guard let audience = screens.first(
            where: { $0.screenshot().image.size != mainSize }
        ) else {
            throw XCTSkip(
                "Every attached screen reports the presenter's size (\(mainSize)); "
                + "cannot tell the audience display apart."
            )
        }

        cachedAudienceScreen = audience
        return audience
    }

    private var cachedAudienceScreen: XCUIScreen?

    func fingerprint(of screen: XCUIScreen) -> ScreenFingerprint {
        ScreenFingerprint(screen.screenshot())
    }

    /// Polls until `screen` stops changing, so a fingerprint is never taken mid-fade.
    @discardableResult
    func settledFingerprint(of screen: XCUIScreen, timeout: TimeInterval = 5) -> ScreenFingerprint {
        var previous = fingerprint(of: screen)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            Thread.sleep(forTimeInterval: 0.25)
            let current = fingerprint(of: screen)
            if current.distance(to: previous) < 0.002 { return current }
            previous = current
        }
        return previous
    }
}
