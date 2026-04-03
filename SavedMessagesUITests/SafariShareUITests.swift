import XCTest

/// UI tests for sharing a URL from Safari into SavedMessages via the Share Extension.
///
/// These tests launch Safari, navigate to a specific URL, use the share sheet
/// to invoke the SavedMessages share extension, and then switch back to the
/// main app to verify the URL was saved correctly.
/// Best run on a local simulator (not headless CI) because they interact with Safari.
final class SafariShareUITests: XCTestCase {

    private var app: XCUIApplication!
    private var safari: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    }

    override func tearDownWithError() throws {
        app = nil
        safari = nil
    }

    // MARK: - Helpers

    /// Launch the main app so its container is initialised, then background it.
    private func launchMainAppInBackground() {
        app.launch()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
    }

    /// Opens Safari and navigates to the given URL.
    /// - Parameter urlString: The URL to load in Safari.
    private func openURLInSafari(_ urlString: String) {
        safari.launch()
        XCTAssertTrue(safari.waitForExistence(timeout: 5), "Safari should launch")

        // Tap the address bar. In iOS 17+ the URL field is at the bottom.
        let urlField = safari.textFields["Address"]
        if urlField.waitForExistence(timeout: 5) {
            urlField.tap()
        } else {
            // Fallback: try tapping the tab bar URL display to focus the address bar
            let tabBarURL = safari.buttons["URL"]
            if tabBarURL.waitForExistence(timeout: 3) {
                tabBarURL.tap()
            } else {
                // Try the bottom bar area – iOS 17 shows the URL in the toolbar
                safari.toolbars.textFields.firstMatch.tap()
            }
        }

        // Clear any existing text and type the URL
        let activeField = safari.textFields.firstMatch
        XCTAssertTrue(activeField.waitForExistence(timeout: 5), "Address field should be focused")

        // Select all existing text (if any) and replace
        activeField.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        activeField.typeText(urlString)

        // Submit the URL by pressing Go / Return
        safari.keyboards.buttons["Go"].tap()

        // Wait for the page to finish loading. Once the keyboard dismisses and the
        // toolbar reappears we know navigation has started; then wait for the URL
        // bar to reflect the loaded page (keyboard gone means page is rendering).
        let toolbar = safari.toolbars.firstMatch
        XCTAssertTrue(
            toolbar.waitForExistence(timeout: 15),
            "Safari toolbar should reappear after the page starts loading"
        )
    }

    /// Taps the share button in Safari.
    private func tapShareButtonInSafari() {
        let shareButton = safari.buttons["ShareButton"]
        if !shareButton.waitForExistence(timeout: 5) {
            // Fallback: try other common accessibility identifiers
            let altShareButton = safari.toolbars.buttons["Share"]
            if altShareButton.waitForExistence(timeout: 3) {
                altShareButton.tap()
                return
            }
            // Another fallback: look for the share icon by its standard identifier
            let toolbarShareButton = safari.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "Share")
            ).firstMatch
            XCTAssertTrue(
                toolbarShareButton.waitForExistence(timeout: 5),
                "Share button should be visible in Safari toolbar"
            )
            toolbarShareButton.tap()
            return
        }
        shareButton.tap()
    }

    /// Finds and taps the SavedMessages share extension in the share sheet.
    private func tapSavedMessagesExtension() {
        let shareSheet = safari.otherElements["ActivityListView"]
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 5), "Share sheet should appear")

        let extensionButton = safari.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "SavedMessages")
        ).firstMatch

        if !extensionButton.waitForExistence(timeout: 3) {
            // Scroll through the share sheet to reveal more options
            shareSheet.swipeUp()
        }

        XCTAssertTrue(
            extensionButton.waitForExistence(timeout: 5),
            "SavedMessages share extension should appear in the share sheet"
        )
        extensionButton.tap()
    }

    /// Waits for the share extension to dismiss after saving.
    private func waitForExtensionDismissal() {
        // The extension saves immediately and shows a brief success HUD, then dismisses.
        // Wait for Safari's UI to return.
        let safariToolbar = safari.toolbars.firstMatch
        XCTAssertTrue(
            safariToolbar.waitForExistence(timeout: 15),
            "Safari should return to foreground after extension dismisses"
        )
    }

    // MARK: - Tests

    /// Full end-to-end test: open Safari → navigate to BMW Wikipedia article →
    /// share URL via SavedMessages extension → switch to main app → verify URL saved.
    func testShareBMWWikipediaURLFromSafari() throws {
        let bmwURL = "https://de.wikipedia.org/wiki/BMW_(Automarke)"

        // 1. Launch the main app first so its container is initialised
        launchMainAppInBackground()

        // 2. Open Safari and navigate to the URL
        openURLInSafari(bmwURL)

        // 3. Tap the Share button
        tapShareButtonInSafari()

        // 4. Find and tap the SavedMessages extension
        tapSavedMessagesExtension()

        // 5. Wait for the extension to save and dismiss
        waitForExtensionDismissal()

        // 6. Switch to the main app and verify the URL was saved
        app.activate()
        XCTAssertTrue(
            app.navigationBars["SavedMessages"].waitForExistence(timeout: 5),
            "Main app should be active and showing the items list"
        )

        // The shared URL should appear as a new item in the list.
        // URLs get tagged with "URL" and the source app tag.
        // Check that the URL text or the BMW page title is visible in the list.
        let bmwItem = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "BMW")
        ).firstMatch

        let urlItem = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "wikipedia")
        ).firstMatch

        let urlTag = app.staticTexts["URL"]

        // At least one of these should match – the item could show the page title
        // or the raw URL depending on how Safari provides the shared content.
        let foundBMW = bmwItem.waitForExistence(timeout: 10)
        let foundWikipedia = urlItem.waitForExistence(timeout: 3)
        let foundURLTag = urlTag.waitForExistence(timeout: 3)

        XCTAssertTrue(
            foundBMW || foundWikipedia || foundURLTag,
            "The shared BMW Wikipedia URL should appear in the SavedMessages items list"
        )
    }
}
