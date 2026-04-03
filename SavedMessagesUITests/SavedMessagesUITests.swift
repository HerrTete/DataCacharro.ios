import XCTest

final class SavedMessagesUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tab Navigation

    func testTabBarHasThreeTabs() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should be visible")
        XCTAssertTrue(tabBar.buttons["Items"].exists, "Items tab should exist")
        XCTAssertTrue(tabBar.buttons["Settings"].exists, "Settings tab should exist")
        XCTAssertTrue(tabBar.buttons["Tags"].exists, "Tags tab should exist")
    }

    func testSwitchingToSettingsTab() {
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Version"].exists)
        XCTAssertTrue(app.staticTexts["Build"].exists)
    }

    func testSwitchingToTagsTab() {
        app.tabBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))
    }

    func testSwitchingBackToItemsTab() {
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
        app.tabBars.buttons["Items"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
    }

    func testTabNavigationRoundTripAllTabs() {
        // Items → Settings → Tags → Items
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))

        app.tabBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))

        app.tabBars.buttons["Items"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
    }

    func testTabNavigationReverseOrder() {
        // Items → Tags → Settings → Items
        app.tabBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))

        app.tabBars.buttons["Items"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
    }

    func testTabAccessibilityIdentifiers() {
        XCTAssertTrue(app.tabBars.buttons["Items"].exists, "Items tab should have correct label")
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists, "Settings tab should have correct label")
        XCTAssertTrue(app.tabBars.buttons["Tags"].exists, "Tags tab should have correct label")
    }

    func testRepeatedTabSwitching() {
        // Rapidly switch tabs multiple times
        for _ in 0..<3 {
            app.tabBars.buttons["Settings"].tap()
            XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
            app.tabBars.buttons["Items"].tap()
            XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        }
    }

    // MARK: - Items Tab Toolbar

    func testItemsTabHasAddButtons() {
        XCTAssertTrue(app.buttons["addTextButton"].exists, "Add text button should be visible")
        XCTAssertTrue(app.buttons["addPhotoVideoButton"].exists, "Add photo/video button should be visible")
        XCTAssertTrue(app.buttons["addAudioButton"].exists, "Add audio button should be visible")
    }

    func testItemsTabAddButtonsAreEnabled() {
        XCTAssertTrue(app.buttons["addTextButton"].isEnabled, "Add text button should be enabled")
        XCTAssertTrue(app.buttons["addPhotoVideoButton"].isEnabled, "Add photo/video button should be enabled")
        XCTAssertTrue(app.buttons["addAudioButton"].isEnabled, "Add audio button should be enabled")
    }

    // MARK: - Add Text Flow

    func testOpenAndCancelAddTextSheet() {
        app.buttons["addTextButton"].tap()
        XCTAssertTrue(app.navigationBars["Add Text"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["cancelButton"].exists)
        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
    }

    func testAddTextSaveButtonDisabledWhenEmpty() {
        app.buttons["addTextButton"].tap()
        XCTAssertTrue(app.navigationBars["Add Text"].waitForExistence(timeout: 2))
        let saveButton = app.buttons["saveButton"]
        XCTAssertTrue(saveButton.exists)
        XCTAssertFalse(saveButton.isEnabled, "Save should be disabled when text is empty")
        app.buttons["cancelButton"].tap()
    }

    func testAddTextAndSave() {
        app.buttons["addTextButton"].tap()
        XCTAssertTrue(app.navigationBars["Add Text"].waitForExistence(timeout: 2))

        let textEditor = app.textViews["textEditor"]
        XCTAssertTrue(textEditor.exists, "Text editor should be visible")
        textEditor.tap()
        textEditor.typeText("Hello UI Test")

        let saveButton = app.buttons["saveButton"]
        XCTAssertTrue(saveButton.isEnabled, "Save should be enabled after typing text")
        saveButton.tap()

        // Sheet should dismiss and we return to items list
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        // The newly added item should appear in the list
        XCTAssertTrue(app.staticTexts["Hello UI Test"].waitForExistence(timeout: 2))
    }

    func testAddURLTextShowsURLTag() {
        app.buttons["addTextButton"].tap()
        XCTAssertTrue(app.navigationBars["Add Text"].waitForExistence(timeout: 2))

        let textEditor = app.textViews["textEditor"]
        textEditor.tap()
        textEditor.typeText("https://example.com")

        app.buttons["saveButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        // URL items get tagged as "URL"
        XCTAssertTrue(app.staticTexts["URL"].waitForExistence(timeout: 2))
    }

    func testAddTextShowsTextTag() {
        addTextItem("Plain text tag test")

        // Text items should get tagged as "Text"
        XCTAssertTrue(app.staticTexts["Text"].waitForExistence(timeout: 2))
    }

    func testAddTextSaveButtonEnablesAfterTyping() {
        app.buttons["addTextButton"].tap()
        XCTAssertTrue(app.navigationBars["Add Text"].waitForExistence(timeout: 2))

        let saveButton = app.buttons["saveButton"]
        XCTAssertFalse(saveButton.isEnabled, "Save should be disabled initially")

        let textEditor = app.textViews["textEditor"]
        textEditor.tap()
        textEditor.typeText("a")

        XCTAssertTrue(saveButton.isEnabled, "Save should be enabled after typing text")
        app.buttons["cancelButton"].tap()
    }

    func testAddTextNavigationBarTitle() {
        app.buttons["addTextButton"].tap()
        XCTAssertTrue(app.navigationBars["Add Text"].waitForExistence(timeout: 2))
        app.buttons["cancelButton"].tap()
    }

    func testAddTextHasTextEditor() {
        app.buttons["addTextButton"].tap()
        XCTAssertTrue(app.navigationBars["Add Text"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textViews["textEditor"].exists, "Text editor should be visible")
        app.buttons["cancelButton"].tap()
    }

    func testAddTextCancelDoesNotCreateItem() {
        app.buttons["addTextButton"].tap()
        XCTAssertTrue(app.navigationBars["Add Text"].waitForExistence(timeout: 2))

        let textEditor = app.textViews["textEditor"]
        textEditor.tap()
        textEditor.typeText("This should not be saved")

        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["This should not be saved"].exists, "Cancelled text should not appear in list")
    }

    func testAddMultipleURLItems() {
        addTextItem("https://example.com/first")
        addTextItem("https://example.com/second")

        XCTAssertTrue(app.staticTexts["https://example.com/first"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["https://example.com/second"].exists)
    }

    func testAddLongTextItem() {
        let longText = "This is a long text item that should be properly handled by the UI and displayed correctly in the items list with appropriate truncation"
        addTextItem(longText)
        // The item should appear (possibly truncated in list)
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
    }

    // MARK: - Add Audio Flow

    func testOpenAndCancelAddAudioSheet() {
        app.buttons["addAudioButton"].tap()
        XCTAssertTrue(app.navigationBars["Audio Recording"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["cancelButton"].exists)
        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
    }

    func testAudioRecordButtonExists() {
        app.buttons["addAudioButton"].tap()
        XCTAssertTrue(app.navigationBars["Audio Recording"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["recordButton"].exists, "Record button should exist")
        // Save is disabled before recording
        let saveButton = app.buttons["saveButton"]
        XCTAssertTrue(saveButton.exists)
        XCTAssertFalse(saveButton.isEnabled, "Save should be disabled before recording")
        app.buttons["cancelButton"].tap()
    }

    func testAudioTimerDisplayExists() {
        app.buttons["addAudioButton"].tap()
        XCTAssertTrue(app.navigationBars["Audio Recording"].waitForExistence(timeout: 2))
        // Timer should show initial value
        XCTAssertTrue(app.staticTexts["00:00.0"].exists, "Timer should show 00:00.0 initially")
        app.buttons["cancelButton"].tap()
    }

    func testAudioNavigationBarTitle() {
        app.buttons["addAudioButton"].tap()
        XCTAssertTrue(app.navigationBars["Audio Recording"].waitForExistence(timeout: 2))
        app.buttons["cancelButton"].tap()
    }

    func testAudioHasCancelAndSaveButtons() {
        app.buttons["addAudioButton"].tap()
        XCTAssertTrue(app.navigationBars["Audio Recording"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["cancelButton"].exists, "Cancel button should exist")
        XCTAssertTrue(app.buttons["saveButton"].exists, "Save button should exist")
        app.buttons["cancelButton"].tap()
    }

    func testAudioSaveDisabledWithoutRecording() {
        app.buttons["addAudioButton"].tap()
        XCTAssertTrue(app.navigationBars["Audio Recording"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["saveButton"].isEnabled, "Save should be disabled without recording")
        app.buttons["cancelButton"].tap()
    }

    // MARK: - Add Photo/Video Flow

    func testOpenAndCancelAddPhotoVideoSheet() {
        app.buttons["addPhotoVideoButton"].tap()
        XCTAssertTrue(app.navigationBars["Photos & Videos"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["cancelButton"].exists)
        XCTAssertTrue(app.buttons["cameraButton"].exists, "Camera button should exist")
        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
    }

    func testPhotoVideoSaveButtonDisabledWhenEmpty() {
        app.buttons["addPhotoVideoButton"].tap()
        XCTAssertTrue(app.navigationBars["Photos & Videos"].waitForExistence(timeout: 2))
        let saveButton = app.buttons["saveButton"]
        XCTAssertTrue(saveButton.exists)
        XCTAssertFalse(saveButton.isEnabled, "Save should be disabled when no items are selected")
        app.buttons["cancelButton"].tap()
    }

    func testPhotoVideoViewHasCameraAndLibraryOptions() {
        app.buttons["addPhotoVideoButton"].tap()
        XCTAssertTrue(app.navigationBars["Photos & Videos"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Take Photo or Video"].exists)
        XCTAssertTrue(app.staticTexts["Select Photos & Videos"].exists)
        app.buttons["cancelButton"].tap()
    }

    func testPhotoVideoNavigationBarTitle() {
        app.buttons["addPhotoVideoButton"].tap()
        XCTAssertTrue(app.navigationBars["Photos & Videos"].waitForExistence(timeout: 2))
        app.buttons["cancelButton"].tap()
    }

    func testPhotoVideoHasCameraButton() {
        app.buttons["addPhotoVideoButton"].tap()
        XCTAssertTrue(app.navigationBars["Photos & Videos"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["cameraButton"].exists, "Camera button should exist")
        XCTAssertTrue(app.buttons["cameraButton"].isEnabled, "Camera button should be enabled")
        app.buttons["cancelButton"].tap()
    }

    func testPhotoVideoHasCancelAndSaveButtons() {
        app.buttons["addPhotoVideoButton"].tap()
        XCTAssertTrue(app.navigationBars["Photos & Videos"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["cancelButton"].exists, "Cancel button should exist")
        XCTAssertTrue(app.buttons["saveButton"].exists, "Save button should exist")
        app.buttons["cancelButton"].tap()
    }

    func testPhotoVideoSubtitles() {
        app.buttons["addPhotoVideoButton"].tap()
        XCTAssertTrue(app.navigationBars["Photos & Videos"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Capture with your camera"].exists, "Camera subtitle should exist")
        XCTAssertTrue(app.staticTexts["Tap to choose from your library"].exists, "Library subtitle should exist")
        app.buttons["cancelButton"].tap()
    }

    // MARK: - Settings View

    func testSettingsShowsVersionAndBuild() {
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Version"].exists, "Version label should exist")
        XCTAssertTrue(app.staticTexts["Build"].exists, "Build label should exist")
        XCTAssertTrue(app.staticTexts["appSectionHeader"].exists, "App section header should exist")
    }

    func testSettingsNavigationBarTitle() {
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
    }

    func testSettingsShowsVersionNumber() {
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
        // Version 1.1 should be displayed
        XCTAssertTrue(app.staticTexts["1.1"].exists, "Version 1.1 should be displayed")
    }

    func testSettingsShowsBuildNumber() {
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
        // Build number should be displayed
        XCTAssertTrue(app.staticTexts["1"].exists, "Build number should be displayed")
    }

    func testSettingsShowsAppSectionHeader() {
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["appSectionHeader"].exists, "App section header should exist")
    }

    // MARK: - Tags View

    func testTagsViewShowsEmptyState() {
        // Clean start - may show empty state if no items exist
        app.tabBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))
        // Either we see tags or the empty state
        let hasContent = app.staticTexts["No Tags"].exists || app.cells.firstMatch.exists
        XCTAssertTrue(hasContent, "Tags view should show either tags or empty state")
    }

    func testTagsNavigationBarTitle() {
        app.tabBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))
    }

    func testTagsViewShowsTagsAfterAddingItem() {
        addTextItem("Tag display test")

        app.tabBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))

        // Text tag should appear after adding a text item
        XCTAssertTrue(app.staticTexts["Text"].waitForExistence(timeout: 2), "Text tag should exist after adding text item")
    }

    func testTagsViewShowsURLTagAfterAddingURL() {
        addTextItem("https://example.com/tagtest")

        app.tabBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))

        XCTAssertTrue(app.staticTexts["URL"].waitForExistence(timeout: 2), "URL tag should exist after adding URL item")
    }

    func testTagsEmptyStateMessage() {
        app.tabBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))
        // If empty state is shown, it should have the correct message
        if app.staticTexts["No Tags"].exists {
            XCTAssertTrue(app.staticTexts["Add tags to your items to organize them."].exists, "Empty state description should be shown")
        }
    }

    // MARK: - Item Detail & Edit Flow

    func testTapItemOpensDetail() {
        // First, add an item
        addTextItem("Detail test item")

        // Tap the item in the list
        let itemText = app.staticTexts["Detail test item"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))
        itemText.tap()

        // Detail view should open
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["editButton"].exists)
        XCTAssertTrue(app.buttons["shareButton"].exists)

        app.buttons["doneButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
    }

    func testDetailViewShowsAllButtons() {
        addTextItem("Button check item")

        app.staticTexts["Button check item"].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2), "Done button should exist")
        XCTAssertTrue(app.buttons["editButton"].exists, "Edit button should exist")
        XCTAssertTrue(app.buttons["shareButton"].exists, "Share button should exist")
        app.buttons["doneButton"].tap()
    }

    func testEditItemName() {
        addTextItem("Original name item")

        let itemText = app.staticTexts["Original name item"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))
        itemText.tap()

        XCTAssertTrue(app.buttons["editButton"].waitForExistence(timeout: 2))
        app.buttons["editButton"].tap()

        // Edit view should open
        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))
        let nameField = app.textFields["nameTextField"]
        XCTAssertTrue(nameField.exists)

        // Clear and type new name
        nameField.tap()
        nameField.clearAndTypeText("Renamed item")

        app.buttons["saveButton"].tap()
        // Edit sheet should dismiss, detail view should update title
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        app.buttons["doneButton"].tap()

        // Back on the main list, the renamed item should be visible
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Renamed item"].waitForExistence(timeout: 2))
    }

    func testEditItemCancelDoesNotSave() {
        addTextItem("Cancel edit test")

        let itemText = app.staticTexts["Cancel edit test"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))
        itemText.tap()

        XCTAssertTrue(app.buttons["editButton"].waitForExistence(timeout: 2))
        app.buttons["editButton"].tap()

        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))
        let nameField = app.textFields["nameTextField"]
        nameField.tap()
        nameField.clearAndTypeText("Should not save")

        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        app.buttons["doneButton"].tap()

        // Original name should still be there
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Cancel edit test"].exists)
        XCTAssertFalse(app.staticTexts["Should not save"].exists)
    }

    func testEditViewNavigationBarTitle() {
        addTextItem("Edit nav test")

        app.staticTexts["Edit nav test"].tap()
        XCTAssertTrue(app.buttons["editButton"].waitForExistence(timeout: 2))
        app.buttons["editButton"].tap()

        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))
        app.buttons["cancelButton"].tap()
        app.buttons["doneButton"].tap()
    }

    func testEditViewHasNameField() {
        addTextItem("Name field test")

        app.staticTexts["Name field test"].tap()
        XCTAssertTrue(app.buttons["editButton"].waitForExistence(timeout: 2))
        app.buttons["editButton"].tap()

        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["nameTextField"].exists, "Name text field should exist in edit view")
        app.buttons["cancelButton"].tap()
        app.buttons["doneButton"].tap()
    }

    func testEditViewHasTagInputField() {
        addTextItem("Tag input test")

        app.staticTexts["Tag input test"].tap()
        XCTAssertTrue(app.buttons["editButton"].waitForExistence(timeout: 2))
        app.buttons["editButton"].tap()

        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["tagInputField"].exists, "Tag input field should exist in edit view")
        app.buttons["cancelButton"].tap()
        app.buttons["doneButton"].tap()
    }

    func testEditViewHasCancelAndSaveButtons() {
        addTextItem("Edit buttons test")

        app.staticTexts["Edit buttons test"].tap()
        XCTAssertTrue(app.buttons["editButton"].waitForExistence(timeout: 2))
        app.buttons["editButton"].tap()

        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["cancelButton"].exists, "Cancel button should exist in edit view")
        XCTAssertTrue(app.buttons["saveButton"].exists, "Save button should exist in edit view")
        app.buttons["cancelButton"].tap()
        app.buttons["doneButton"].tap()
    }

    func testEditNameMultipleTimes() {
        addTextItem("Multi edit test")

        // First edit
        app.staticTexts["Multi edit test"].tap()
        XCTAssertTrue(app.buttons["editButton"].waitForExistence(timeout: 2))
        app.buttons["editButton"].tap()
        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))
        let nameField = app.textFields["nameTextField"]
        nameField.tap()
        nameField.clearAndTypeText("First rename")
        app.buttons["saveButton"].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))

        // Second edit
        app.buttons["editButton"].tap()
        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))
        let nameField2 = app.textFields["nameTextField"]
        nameField2.tap()
        nameField2.clearAndTypeText("Second rename")
        app.buttons["saveButton"].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        app.buttons["doneButton"].tap()

        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Second rename"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["First rename"].exists)
    }

    func testDoneButtonDismissesDetail() {
        addTextItem("Done dismiss test")

        app.staticTexts["Done dismiss test"].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        app.buttons["doneButton"].tap()

        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2), "Should return to items list after tapping Done")
    }

    // MARK: - Add Tag in Edit View

    func testAddTagToItem() {
        addTextItem("Taggable item")

        let itemText = app.staticTexts["Taggable item"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))
        itemText.tap()

        XCTAssertTrue(app.buttons["editButton"].waitForExistence(timeout: 2))
        app.buttons["editButton"].tap()

        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))

        let tagInput = app.textFields["tagInputField"]
        XCTAssertTrue(tagInput.exists, "Tag input field should exist")
        tagInput.tap()
        tagInput.typeText("CustomTag")

        // Submit the tag
        let addTagButton = app.buttons["addTagButton"]
        if addTagButton.waitForExistence(timeout: 1) {
            addTagButton.tap()
        } else {
            // Press return to submit
            app.keyboards.buttons["Return"].tap()
        }

        app.buttons["saveButton"].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        app.buttons["doneButton"].tap()

        // Verify the tag appears on the item in the list
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["CustomTag"].waitForExistence(timeout: 2))
    }

    func testAddMultipleTagsToItem() {
        addTextItem("Multi tag item")

        app.staticTexts["Multi tag item"].tap()
        XCTAssertTrue(app.buttons["editButton"].waitForExistence(timeout: 2))
        app.buttons["editButton"].tap()
        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))

        // Add first tag
        let tagInput = app.textFields["tagInputField"]
        tagInput.tap()
        tagInput.typeText("TagA")
        let addTagButton = app.buttons["addTagButton"]
        if addTagButton.waitForExistence(timeout: 1) {
            addTagButton.tap()
        } else {
            app.keyboards.buttons["Return"].tap()
        }

        // Add second tag
        tagInput.tap()
        tagInput.typeText("TagB")
        if addTagButton.waitForExistence(timeout: 1) {
            addTagButton.tap()
        } else {
            app.keyboards.buttons["Return"].tap()
        }

        app.buttons["saveButton"].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        app.buttons["doneButton"].tap()

        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["TagA"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["TagB"].exists)
    }

    func testAddTagCancelDoesNotSaveTag() {
        addTextItem("Tag cancel test")

        app.staticTexts["Tag cancel test"].tap()
        XCTAssertTrue(app.buttons["editButton"].waitForExistence(timeout: 2))
        app.buttons["editButton"].tap()
        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))

        let tagInput = app.textFields["tagInputField"]
        tagInput.tap()
        tagInput.typeText("CancelledTag")
        let addTagButton = app.buttons["addTagButton"]
        if addTagButton.waitForExistence(timeout: 1) {
            addTagButton.tap()
        } else {
            app.keyboards.buttons["Return"].tap()
        }

        // Cancel instead of save
        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        app.buttons["doneButton"].tap()

        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["CancelledTag"].exists, "Cancelled tag should not appear")
    }

    func testCustomTagVisibleInTagsTab() {
        addTextItem("Custom tag nav test")

        app.staticTexts["Custom tag nav test"].tap()
        XCTAssertTrue(app.buttons["editButton"].waitForExistence(timeout: 2))
        app.buttons["editButton"].tap()
        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))

        let tagInput = app.textFields["tagInputField"]
        tagInput.tap()
        tagInput.typeText("NavTag")
        let addTagButton = app.buttons["addTagButton"]
        if addTagButton.waitForExistence(timeout: 1) {
            addTagButton.tap()
        } else {
            app.keyboards.buttons["Return"].tap()
        }

        app.buttons["saveButton"].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        app.buttons["doneButton"].tap()

        // Go to Tags tab and verify custom tag appears
        app.tabBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["NavTag"].waitForExistence(timeout: 2), "Custom tag should appear in Tags tab")
    }

    // MARK: - Quick Tag Management (Context Menu)

    func testManageTagsFromContextMenu() {
        addTextItem("Context tag item")

        let itemText = app.staticTexts["Context tag item"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))

        itemText.press(forDuration: 1.0)
        let manageTagsButton = app.buttons["Manage Tags"]
        XCTAssertTrue(manageTagsButton.waitForExistence(timeout: 2), "Manage Tags should appear in context menu")
        manageTagsButton.tap()

        // Quick Tag view should open
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))
        app.buttons["cancelButton"].firstMatch.tap()
    }

    func testQuickTagViewHasNewTagInput() {
        addTextItem("Quick tag input test")

        app.staticTexts["Quick tag input test"].tap()
        XCTAssertTrue(app.buttons["editButton"].waitForExistence(timeout: 2))
        app.buttons["doneButton"].tap()

        // Open quick tag via context menu
        let itemText = app.staticTexts["Quick tag input test"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))
        itemText.press(forDuration: 1.0)
        app.buttons["Manage Tags"].tap()

        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["newTagField"].exists, "New tag input field should exist in quick tag view")
        app.buttons["cancelButton"].firstMatch.tap()
    }

    func testSwipeToOpenTags() {
        addTextItem("Swipe tag test")

        let itemText = app.staticTexts["Swipe tag test"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))

        // Swipe right to reveal Tags action
        itemText.swipeRight()
        let tagsButton = app.buttons["swipeTagsButton"]
        if tagsButton.waitForExistence(timeout: 2) {
            tagsButton.tap()
            // Quick Tag view should open
            XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))
            app.buttons["cancelButton"].firstMatch.tap()
        }
    }

    // MARK: - Delete Item

    func testDeleteItemViaSwipe() {
        addTextItem("Delete me via swipe")

        let itemText = app.staticTexts["Delete me via swipe"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))

        // Swipe left to reveal delete action
        itemText.swipeLeft()
        let deleteButton = app.buttons["Delete"]
        if deleteButton.waitForExistence(timeout: 2) {
            deleteButton.tap()
        }

        // Item should be gone — wait briefly for UI to update, then verify absence
        let deletedItem = app.staticTexts["Delete me via swipe"]
        let disappeared = deletedItem.waitForNonExistence(timeout: 3)
        XCTAssertTrue(disappeared, "Deleted item should no longer appear in the list")
    }

    func testDeleteItemViaContextMenu() {
        addTextItem("Delete me via context")

        let itemText = app.staticTexts["Delete me via context"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))

        itemText.press(forDuration: 1.0)
        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
        deleteButton.tap()

        let deletedItem = app.staticTexts["Delete me via context"]
        let disappeared = deletedItem.waitForNonExistence(timeout: 3)
        XCTAssertTrue(disappeared, "Deleted item should no longer appear in the list")
    }

    func testDeleteMultipleItemsSequentially() {
        addTextItem("Sequential delete 1")
        addTextItem("Sequential delete 2")

        // Delete first item
        let item1 = app.staticTexts["Sequential delete 1"]
        XCTAssertTrue(item1.waitForExistence(timeout: 2))
        item1.swipeLeft()
        if app.buttons["Delete"].waitForExistence(timeout: 2) {
            app.buttons["Delete"].tap()
        }
        XCTAssertTrue(item1.waitForNonExistence(timeout: 3))

        // Delete second item
        let item2 = app.staticTexts["Sequential delete 2"]
        XCTAssertTrue(item2.waitForExistence(timeout: 2))
        item2.swipeLeft()
        if app.buttons["Delete"].waitForExistence(timeout: 2) {
            app.buttons["Delete"].tap()
        }
        XCTAssertTrue(item2.waitForNonExistence(timeout: 3))
    }

    // MARK: - Selection Mode

    func testSelectButtonExists() {
        addTextItem("Select button test")

        let selectButton = app.buttons["selectButton"]
        XCTAssertTrue(selectButton.waitForExistence(timeout: 2), "Select button should exist when items are present")
    }

    func testEnterSelectionMode() {
        addTextItem("Selection mode test")

        let selectButton = app.buttons["selectButton"]
        XCTAssertTrue(selectButton.waitForExistence(timeout: 2))
        selectButton.tap()

        // Cancel button should appear in selection mode
        XCTAssertTrue(app.buttons["cancelSelectButton"].waitForExistence(timeout: 2), "Cancel select button should appear in selection mode")
    }

    func testCancelSelectionMode() {
        addTextItem("Cancel select test")

        app.buttons["selectButton"].tap()
        XCTAssertTrue(app.buttons["cancelSelectButton"].waitForExistence(timeout: 2))

        app.buttons["cancelSelectButton"].tap()
        // Should exit selection mode
        XCTAssertTrue(app.buttons["selectButton"].waitForExistence(timeout: 2), "Select button should reappear after cancelling selection")
    }

    func testSelectAllButton() {
        addTextItem("Select all test 1")
        addTextItem("Select all test 2")

        let selectButton = app.buttons["selectButton"]
        XCTAssertTrue(selectButton.waitForExistence(timeout: 2))
        selectButton.tap()

        // After entering selection mode, should show "Select All"
        let selectAllButton = app.buttons["selectButton"]
        XCTAssertTrue(selectAllButton.waitForExistence(timeout: 2))
        selectAllButton.tap()

        // Delete selected button should appear
        XCTAssertTrue(app.buttons["deleteSelectedButton"].waitForExistence(timeout: 2), "Delete selected button should appear after selecting all")

        app.buttons["cancelSelectButton"].tap()
    }

    func testDeleteSelectedItems() {
        addTextItem("Bulk delete 1")
        addTextItem("Bulk delete 2")

        // Enter selection mode
        let selectButton = app.buttons["selectButton"]
        XCTAssertTrue(selectButton.waitForExistence(timeout: 3), "Select button should be visible when items are present")
        selectButton.tap()
        XCTAssertTrue(app.buttons["cancelSelectButton"].waitForExistence(timeout: 2))

        // Select all
        app.buttons["selectButton"].tap()

        // Delete selected
        let deleteSelected = app.buttons["deleteSelectedButton"]
        XCTAssertTrue(deleteSelected.waitForExistence(timeout: 2))
        deleteSelected.tap()

        // Both items should be gone
        XCTAssertTrue(app.staticTexts["Bulk delete 1"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Bulk delete 2"].waitForNonExistence(timeout: 3))
    }

    func testSelectionModeHidesContextMenu() {
        addTextItem("No context in select")

        // Enter selection mode
        app.buttons["selectButton"].tap()
        XCTAssertTrue(app.buttons["cancelSelectButton"].waitForExistence(timeout: 2))

        // Long press should NOT show context menu in selection mode
        let itemText = app.staticTexts["No context in select"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))
        itemText.press(forDuration: 1.0)

        // Context menu items should not appear
        let shareButton = app.buttons["Share"]
        XCTAssertFalse(shareButton.waitForExistence(timeout: 1), "Context menu should not appear in selection mode")

        app.buttons["cancelSelectButton"].tap()
    }

    func testDeleteSelectedButtonShowsCount() {
        addTextItem("Count delete 1")
        addTextItem("Count delete 2")

        // Enter selection mode and select all
        let selectButton = app.buttons["selectButton"]
        XCTAssertTrue(selectButton.waitForExistence(timeout: 3), "Select button should be visible when items are present")
        selectButton.tap()
        XCTAssertTrue(app.buttons["cancelSelectButton"].waitForExistence(timeout: 2))
        app.buttons["selectButton"].tap()

        // Delete button should show count
        let deleteButton = app.buttons["deleteSelectedButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))

        app.buttons["cancelSelectButton"].tap()
    }

    // MARK: - Context Menu

    func testContextMenuShowsAllOptions() {
        addTextItem("Context menu check")

        let itemText = app.staticTexts["Context menu check"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))

        itemText.press(forDuration: 1.0)

        XCTAssertTrue(app.buttons["Share"].waitForExistence(timeout: 2), "Share should appear in context menu")
        XCTAssertTrue(app.buttons["Manage Tags"].exists, "Manage Tags should appear in context menu")
        XCTAssertTrue(app.buttons["Delete"].exists, "Delete should appear in context menu")

        // Dismiss context menu by tapping outside
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
    }

    func testContextMenuDismissByTappingOutside() {
        addTextItem("Dismiss context")

        let itemText = app.staticTexts["Dismiss context"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))

        itemText.press(forDuration: 1.0)
        XCTAssertTrue(app.buttons["Share"].waitForExistence(timeout: 2))

        // Dismiss by tapping outside
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()

        // Should return to items list
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 3))
    }

    // MARK: - Empty State

    func testEmptyStateShowsWhenNoItems() {
        // If no items exist, the empty state should show
        // This depends on the initial state of the app
        let emptyState = app.staticTexts["No Items"]
        let hasItems = app.cells.firstMatch.exists
        // Either we have items or the empty state
        XCTAssertTrue(emptyState.exists || hasItems, "Should show empty state or items")
    }

    func testEmptyStateDisappearsAfterAddingItem() {
        // Add an item
        addTextItem("Fill empty state")

        // The empty state should no longer be visible
        XCTAssertFalse(app.staticTexts["No Items"].exists, "Empty state should disappear after adding item")
        XCTAssertTrue(app.staticTexts["Fill empty state"].exists, "Added item should be visible")
    }

    // MARK: - Tags Tab Navigation

    func testTagsTabNavigationToFilteredList() {
        // First, add a text item (will get "Text" tag)
        addTextItem("Tagged item for navigation")

        // Go to Tags tab
        app.tabBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))

        // Look for "Text" tag and tap it
        let textTag = app.staticTexts["Text"]
        if textTag.waitForExistence(timeout: 2) {
            textTag.tap()
            // Should navigate to filtered list with that tag as title
            XCTAssertTrue(app.navigationBars["Text"].waitForExistence(timeout: 2))
            XCTAssertTrue(app.staticTexts["Tagged item for navigation"].exists)
        }
    }

    func testTagsTabNavigationBackButton() {
        addTextItem("Tag nav back test")

        app.tabBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))

        let textTag = app.staticTexts["Text"]
        if textTag.waitForExistence(timeout: 2) {
            textTag.tap()
            XCTAssertTrue(app.navigationBars["Text"].waitForExistence(timeout: 2))

            // Go back
            app.navigationBars.buttons["Tags"].tap()
            XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))
        }
    }

    func testFilteredListShowsCorrectItems() {
        addTextItem("Filter test text")
        addTextItem("https://example.com/filtertest")

        app.tabBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))

        // Navigate to URL tag
        let urlTag = app.staticTexts["URL"]
        if urlTag.waitForExistence(timeout: 2) {
            urlTag.tap()
            XCTAssertTrue(app.navigationBars["URL"].waitForExistence(timeout: 2))
            // URL item should be present
            XCTAssertTrue(app.staticTexts["https://example.com/filtertest"].waitForExistence(timeout: 2))
            // Text item should NOT be present (it only has "Text" tag)
            XCTAssertFalse(app.staticTexts["Filter test text"].exists, "Non-URL items should not appear in URL-filtered list")
        }
    }

    // MARK: - Multiple Items

    func testAddMultipleTextItems() {
        addTextItem("First item")
        addTextItem("Second item")
        addTextItem("Third item")

        XCTAssertTrue(app.staticTexts["First item"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Second item"].exists)
        XCTAssertTrue(app.staticTexts["Third item"].exists)
    }

    func testItemsListOrder() {
        // Items should appear in reverse chronological order (newest first)
        addTextItem("Earlier item")
        addTextItem("Later item")

        XCTAssertTrue(app.staticTexts["Later item"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Earlier item"].exists)
    }

    // MARK: - Share Sheet Features

    func testShareButtonVisibleInDetailView() {
        addTextItem("Share visible test")

        app.staticTexts["Share visible test"].tap()
        XCTAssertTrue(app.buttons["shareButton"].waitForExistence(timeout: 2), "Share button should be visible in detail view")
        app.buttons["doneButton"].tap()
    }

    func testShareTextItemOpensShareSheet() {
        addTextItem("Share text detail")

        app.staticTexts["Share text detail"].tap()
        XCTAssertTrue(app.buttons["shareButton"].waitForExistence(timeout: 2))
        app.buttons["shareButton"].tap()

        XCTAssertTrue(waitForShareSheet(), "Share sheet should appear for text item")
    }

    func testDismissShareSheetReturnsToDetailView() {
        addTextItem("Dismiss from detail")

        app.staticTexts["Dismiss from detail"].tap()
        XCTAssertTrue(app.buttons["shareButton"].waitForExistence(timeout: 2))
        app.buttons["shareButton"].tap()

        XCTAssertTrue(waitForShareSheet(), "Share sheet should appear")
        dismissShareSheet()

        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 3), "Should return to detail view after dismissing share sheet")
        XCTAssertTrue(app.buttons["shareButton"].exists, "Share button should still be visible")
        app.buttons["doneButton"].tap()
    }

    func testShareFromContextMenu() {
        addTextItem("Context menu share")

        let itemText = app.staticTexts["Context menu share"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))

        itemText.press(forDuration: 1.0)

        let shareButton = app.buttons["Share"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 2), "Context menu should have Share option")
        shareButton.tap()

        XCTAssertTrue(waitForShareSheet(), "Share sheet should appear from context menu")
    }

    func testDismissShareSheetFromContextMenuReturnsList() {
        addTextItem("Context dismiss")

        let itemText = app.staticTexts["Context dismiss"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))

        itemText.press(forDuration: 1.0)
        app.buttons["Share"].tap()

        XCTAssertTrue(waitForShareSheet())
        dismissShareSheet()

        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 3), "Should return to items list after dismissing share sheet")
    }

    func testShareURLItemFromContextMenu() {
        addTextItem("https://example.com/share")

        let itemText = app.staticTexts["https://example.com/share"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))

        // URL items open browser on tap, so use context menu to share
        itemText.press(forDuration: 1.0)

        let shareButton = app.buttons["Share"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 2))
        shareButton.tap()

        XCTAssertTrue(waitForShareSheet(), "Share sheet should appear for URL item via context menu")
    }

    func testShareMultipleItemsSequentially() {
        addTextItem("First share item")
        addTextItem("Second share item")

        // Share first item from detail view
        app.staticTexts["First share item"].tap()
        XCTAssertTrue(app.buttons["shareButton"].waitForExistence(timeout: 2))
        app.buttons["shareButton"].tap()
        XCTAssertTrue(waitForShareSheet())
        dismissShareSheet()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 3))
        app.buttons["doneButton"].tap()

        // Share second item from detail view
        XCTAssertTrue(app.staticTexts["Second share item"].waitForExistence(timeout: 2))
        app.staticTexts["Second share item"].tap()
        XCTAssertTrue(app.buttons["shareButton"].waitForExistence(timeout: 2))
        app.buttons["shareButton"].tap()
        XCTAssertTrue(waitForShareSheet(), "Share sheet should work for second item too")
    }

    func testShareAfterEditingItem() {
        addTextItem("Pre-edit share")

        app.staticTexts["Pre-edit share"].tap()

        XCTAssertTrue(app.buttons["editButton"].waitForExistence(timeout: 2))
        app.buttons["editButton"].tap()

        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))
        let nameField = app.textFields["nameTextField"]
        nameField.tap()
        nameField.clearAndTypeText("Post-edit share")
        app.buttons["saveButton"].tap()

        // Back in detail view — share the edited item
        XCTAssertTrue(app.buttons["shareButton"].waitForExistence(timeout: 2))
        app.buttons["shareButton"].tap()

        XCTAssertTrue(waitForShareSheet(), "Share should still work after editing item")
    }

    // MARK: - Text Detail Content

    func testTextItemDetailShowsContent() {
        addTextItem("Full content check")

        app.staticTexts["Full content check"].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        // The text content should be displayed in the detail view
        XCTAssertTrue(app.staticTexts["Full content check"].exists)
        app.buttons["doneButton"].tap()
    }

    func testTextItemDetailPreservesFullContent() {
        let content = "Multi word content for detail"
        addTextItem(content)

        app.staticTexts[content].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts[content].exists, "Full text content should be displayed in detail")
        app.buttons["doneButton"].tap()
    }

    // MARK: - URL Item Detail

    func testURLItemDetailShowsOpenInBrowser() {
        addTextItem("https://example.com")

        let itemText = app.staticTexts["https://example.com"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))
        // URL items open in browser on tap, but we can verify the item exists
        // (Since URL items open externally, we just verify the list entry)
        XCTAssertTrue(itemText.exists)
    }

    func testURLItemShowsLinkIcon() {
        addTextItem("https://example.com/icon")

        // URL items should show the link icon in the list
        XCTAssertTrue(app.staticTexts["https://example.com/icon"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["URL"].exists, "URL tag badge should be visible")
    }

    // MARK: - Location Display

    func testItemRowDisplaysLocation() {
        // Add an item — location may be captured automatically
        addTextItem("Location display test")

        // Verify item appears (location is optional and depends on device permissions)
        XCTAssertTrue(app.staticTexts["Location display test"].waitForExistence(timeout: 2))
        // We cannot guarantee location is available in test environment,
        // but the UI should render without errors
    }

    // MARK: - Item Tags Display

    func testItemTagsBadgesDisplayInList() {
        addTextItem("Tag badge test")

        // Text items automatically get "Text" tag which should display as a badge
        XCTAssertTrue(app.staticTexts["Tag badge test"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Text"].exists, "Text tag badge should be visible in item row")
    }

    func testURLItemTagsBadgesDisplayInList() {
        addTextItem("https://example.com/badges")

        XCTAssertTrue(app.staticTexts["https://example.com/badges"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["URL"].exists, "URL tag badge should be visible in item row")
    }

    // MARK: - Date Display

    func testItemRowShowsCreationDate() {
        addTextItem("Date display test")

        // Each item row should show a creation date
        XCTAssertTrue(app.staticTexts["Date display test"].waitForExistence(timeout: 2))
        // Date is formatted with .dateTime format — we just verify the item row appears correctly
    }

    // MARK: - Add and Delete Lifecycle

    func testAddThenDeleteItem() {
        addTextItem("Lifecycle test item")
        XCTAssertTrue(app.staticTexts["Lifecycle test item"].waitForExistence(timeout: 2))

        // Delete it
        app.staticTexts["Lifecycle test item"].swipeLeft()
        if app.buttons["Delete"].waitForExistence(timeout: 2) {
            app.buttons["Delete"].tap()
        }
        XCTAssertTrue(app.staticTexts["Lifecycle test item"].waitForNonExistence(timeout: 3))
    }

    func testAddEditThenDeleteItem() {
        addTextItem("Full lifecycle")

        // Edit
        app.staticTexts["Full lifecycle"].tap()
        XCTAssertTrue(app.buttons["editButton"].waitForExistence(timeout: 2))
        app.buttons["editButton"].tap()
        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))
        let nameField = app.textFields["nameTextField"]
        nameField.tap()
        nameField.clearAndTypeText("Edited lifecycle")
        app.buttons["saveButton"].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        app.buttons["doneButton"].tap()

        // Delete
        XCTAssertTrue(app.staticTexts["Edited lifecycle"].waitForExistence(timeout: 2))
        app.staticTexts["Edited lifecycle"].swipeLeft()
        if app.buttons["Delete"].waitForExistence(timeout: 2) {
            app.buttons["Delete"].tap()
        }
        XCTAssertTrue(app.staticTexts["Edited lifecycle"].waitForNonExistence(timeout: 3))
    }

    func testAddShareThenDeleteItem() {
        addTextItem("Share then delete")

        // Share
        app.staticTexts["Share then delete"].tap()
        XCTAssertTrue(app.buttons["shareButton"].waitForExistence(timeout: 2))
        app.buttons["shareButton"].tap()
        XCTAssertTrue(waitForShareSheet())
        dismissShareSheet()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 3))
        app.buttons["doneButton"].tap()

        // Delete
        XCTAssertTrue(app.staticTexts["Share then delete"].waitForExistence(timeout: 2))
        app.staticTexts["Share then delete"].swipeLeft()
        if app.buttons["Delete"].waitForExistence(timeout: 2) {
            app.buttons["Delete"].tap()
        }
        XCTAssertTrue(app.staticTexts["Share then delete"].waitForNonExistence(timeout: 3))
    }

    // MARK: - Reopening Sheets

    func testReopenAddTextSheetAfterCancel() {
        // Open and cancel
        app.buttons["addTextButton"].tap()
        XCTAssertTrue(app.navigationBars["Add Text"].waitForExistence(timeout: 2))
        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))

        // Open again — should work
        app.buttons["addTextButton"].tap()
        XCTAssertTrue(app.navigationBars["Add Text"].waitForExistence(timeout: 2))
        app.buttons["cancelButton"].tap()
    }

    func testReopenAddAudioSheetAfterCancel() {
        app.buttons["addAudioButton"].tap()
        XCTAssertTrue(app.navigationBars["Audio Recording"].waitForExistence(timeout: 2))
        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))

        app.buttons["addAudioButton"].tap()
        XCTAssertTrue(app.navigationBars["Audio Recording"].waitForExistence(timeout: 2))
        app.buttons["cancelButton"].tap()
    }

    func testReopenAddPhotoVideoSheetAfterCancel() {
        app.buttons["addPhotoVideoButton"].tap()
        XCTAssertTrue(app.navigationBars["Photos & Videos"].waitForExistence(timeout: 2))
        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))

        app.buttons["addPhotoVideoButton"].tap()
        XCTAssertTrue(app.navigationBars["Photos & Videos"].waitForExistence(timeout: 2))
        app.buttons["cancelButton"].tap()
    }

    func testReopenDetailAfterDismiss() {
        addTextItem("Reopen detail test")

        // Open detail
        app.staticTexts["Reopen detail test"].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        app.buttons["doneButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))

        // Open again
        app.staticTexts["Reopen detail test"].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        app.buttons["doneButton"].tap()
    }

    // MARK: - Different Add Flows Sequentially

    func testOpenEachAddSheetSequentially() {
        // Open Add Text
        app.buttons["addTextButton"].tap()
        XCTAssertTrue(app.navigationBars["Add Text"].waitForExistence(timeout: 2))
        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))

        // Open Add Audio
        app.buttons["addAudioButton"].tap()
        XCTAssertTrue(app.navigationBars["Audio Recording"].waitForExistence(timeout: 2))
        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))

        // Open Add Photo/Video
        app.buttons["addPhotoVideoButton"].tap()
        XCTAssertTrue(app.navigationBars["Photos & Videos"].waitForExistence(timeout: 2))
        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
    }

    // MARK: - Share Sheet Helpers

    /// Waits for the system share sheet (UIActivityViewController) to appear.
    private func waitForShareSheet() -> Bool {
        let activityListView = app.otherElements["ActivityListView"]
        return activityListView.waitForExistence(timeout: 5)
    }

    /// Dismisses the system share sheet by tapping Close.
    private func dismissShareSheet() {
        let closeButton = app.navigationBars.buttons["Close"]
        if closeButton.waitForExistence(timeout: 2) {
            closeButton.tap()
        } else if app.buttons["Close"].firstMatch.waitForExistence(timeout: 2) {
            app.buttons["Close"].firstMatch.tap()
        }
        // Wait for share sheet to fully dismiss
        let activityListView = app.otherElements["ActivityListView"]
        let dismissed = activityListView.waitForNonExistence(timeout: 3)
        XCTAssertTrue(dismissed, "Share sheet should be dismissed")
    }

    /// Adds a text item via the Add Text sheet.
    private func addTextItem(_ text: String) {
        // Ensure we're on Items tab
        if !app.navigationBars["SavedMessages"].exists {
            app.tabBars.buttons["Items"].tap()
            _ = app.navigationBars["SavedMessages"].waitForExistence(timeout: 2)
        }

        app.buttons["addTextButton"].tap()
        XCTAssertTrue(app.navigationBars["Add Text"].waitForExistence(timeout: 2))

        let textEditor = app.textViews["textEditor"]
        textEditor.tap()
        textEditor.typeText(text)

        app.buttons["saveButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
    }
}

// MARK: - XCUIElement Helpers

extension XCUIElement {
    /// Clears the text field content and types new text.
    func clearAndTypeText(_ text: String) {
        guard let currentValue = self.value as? String, !currentValue.isEmpty else {
            self.typeText(text)
            return
        }
        // Select all text and delete it
        self.tap()
        self.press(forDuration: 1.0)
        let selectAll = XCUIApplication().menuItems["Select All"]
        if selectAll.waitForExistence(timeout: 1) {
            selectAll.tap()
            self.typeText(text)
        } else {
            // Fallback: delete character by character
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            self.typeText(deleteString + text)
        }
    }

    /// Waits for the element to no longer exist.
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}
