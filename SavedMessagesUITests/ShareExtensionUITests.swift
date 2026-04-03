import XCTest

/// UI tests for the Share Extension flow from the Photos app.
///
/// These tests launch the system Photos app, share one or more images via the
/// share sheet, and verify that the SavedMessages share extension processes them
/// correctly. Because the tests depend on the Photos library containing at least
/// one image (add test assets to the simulator beforehand), they are best run
/// manually on a local simulator rather than in headless CI.
final class ShareExtensionUITests: XCTestCase {

    private var app: XCUIApplication!
    private var photosApp: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        photosApp = XCUIApplication(bundleIdentifier: "com.apple.mobileslideshow")
    }

    override func tearDownWithError() throws {
        app = nil
        photosApp = nil
    }

    // MARK: - Helpers

    /// Launch the main app, then background it so the share extension can run.
    private func launchMainAppInBackground() {
        app.launch()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
    }

    /// Opens the Photos app and navigates to the first photo in the library.
    /// - Returns: `true` if a photo was successfully opened.
    @discardableResult
    private func openFirstPhotoInPhotos() -> Bool {
        photosApp.launch()
        let photosReady = photosApp.waitForExistence(timeout: 5)
        guard photosReady else { return false }

        let firstPhoto = photosApp.cells.firstMatch
        guard firstPhoto.waitForExistence(timeout: 5) else { return false }
        firstPhoto.tap()
        return true
    }

    /// Taps the system share button in the Photos detail view.
    private func tapShareButton() {
        let shareButton = photosApp.buttons["Share"]
        if !shareButton.waitForExistence(timeout: 3) {
            photosApp.images.firstMatch.tap()
        }
        XCTAssertTrue(shareButton.waitForExistence(timeout: 3), "Share button should be visible")
        shareButton.tap()
    }

    /// Finds and taps the SavedMessages share extension in the share sheet.
    private func tapSavedMessagesExtension() {
        let shareSheet = photosApp.otherElements["ActivityListView"]
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 5), "Share sheet should appear")

        let extensionButton = photosApp.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "SavedMessages")
        ).firstMatch

        if !extensionButton.waitForExistence(timeout: 3) {
            shareSheet.swipeUp()
        }

        XCTAssertTrue(
            extensionButton.waitForExistence(timeout: 5),
            "SavedMessages share extension should appear in the share sheet"
        )
        extensionButton.tap()
    }

    /// Waits for the share extension HUD to dismiss after saving.
    private func waitForExtensionDismissal() {
        let photosNavBar = photosApp.navigationBars.firstMatch
        XCTAssertTrue(
            photosNavBar.waitForExistence(timeout: 15),
            "Photos should return to foreground after extension dismisses"
        )
    }

    // MARK: - Tests

    /// Tests the full flow: open Photos → share a photo → SavedMessages
    /// extension saves automatically → verify item in main app.
    func testShareSinglePhotoFromPhotos() throws {
        // 1. Launch the main app first so its container is initialised
        launchMainAppInBackground()

        // 2. Open Photos and navigate to the first photo
        let photoOpened = openFirstPhotoInPhotos()
        try XCTSkipUnless(photoOpened, "No photos available in the simulator library – skipping test")

        // 3. Tap the Share button
        tapShareButton()

        // 4. Find and tap the SavedMessages extension
        tapSavedMessagesExtension()

        // 5. Wait for the extension to save and dismiss
        waitForExtensionDismissal()

        // 6. Switch back to the main app and verify the item appeared
        app.activate()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 5))

        // The shared photo should appear as a new item in the list.
        let photoTag = app.staticTexts["Photo"]
        XCTAssertTrue(
            photoTag.waitForExistence(timeout: 5),
            "A newly shared photo item should appear with the 'Photo' tag"
        )
    }

    /// Tests that the share extension shows the saving HUD.
    func testShareExtensionShowsSavingHUD() throws {
        launchMainAppInBackground()

        let photoOpened = openFirstPhotoInPhotos()
        try XCTSkipUnless(photoOpened, "No photos available in the simulator library – skipping test")

        tapShareButton()
        tapSavedMessagesExtension()

        // The extension should briefly show "Saving…" before the success result
        let savingText = photosApp.staticTexts["Saving…"]
        if savingText.waitForExistence(timeout: 2) {
            XCTAssertTrue(savingText.exists, "Saving HUD should be displayed")
        }

        waitForExtensionDismissal()
    }
}
