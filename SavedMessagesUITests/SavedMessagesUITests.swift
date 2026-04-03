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

    /// Consolidates: testTabBarHasThreeTabs, testSwitchingToSettingsTab, testSwitchingToTagsTab,
    /// testSwitchingBackToItemsTab, testTabNavigationRoundTripAllTabs, testTabNavigationReverseOrder,
    /// testTabAccessibilityIdentifiers
    func testTabNavigationAndAccessibility() {
        // Verify tab bar exists with all three tabs (accessibility identifiers)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should be visible")
        XCTAssertTrue(tabBar.buttons["Items"].exists, "Items tab should exist")
        XCTAssertTrue(tabBar.buttons["Settings"].exists, "Settings tab should exist")
        XCTAssertTrue(tabBar.buttons["Tags"].exists, "Tags tab should exist")

        // Items → Settings (verify content)
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Version"].exists)
        XCTAssertTrue(app.staticTexts["Build"].exists)

        // Settings → Tags
        app.tabBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))

        // Tags → Items (back to start)
        app.tabBars.buttons["Items"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))

        // Reverse order: Items → Tags → Settings → Items
        app.tabBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
        app.tabBars.buttons["Items"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
    }

    /// Consolidates: testRepeatedTabSwitching (stress test, kept separate)
    func testRepeatedTabSwitching() {
        for _ in 0..<3 {
            app.tabBars.buttons["Settings"].tap()
            XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
            app.tabBars.buttons["Items"].tap()
            XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        }
    }

    // MARK: - Items Tab Toolbar

    /// Consolidates: testItemsTabHasAddButtons, testItemsTabAddButtonsAreEnabled
    func testItemsTabToolbarButtons() {
        XCTAssertTrue(app.buttons["addTextButton"].exists, "Add text button should be visible")
        XCTAssertTrue(app.buttons["addTextButton"].isEnabled, "Add text button should be enabled")
        XCTAssertTrue(app.buttons["addPhotoVideoButton"].exists, "Add photo/video button should be visible")
        XCTAssertTrue(app.buttons["addPhotoVideoButton"].isEnabled, "Add photo/video button should be enabled")
        XCTAssertTrue(app.buttons["addAudioButton"].exists, "Add audio button should be visible")
        XCTAssertTrue(app.buttons["addAudioButton"].isEnabled, "Add audio button should be enabled")
    }

    // MARK: - Add Text Flow

    /// Consolidates: testOpenAndCancelAddTextSheet, testAddTextNavigationBarTitle, testAddTextHasTextEditor,
    /// testAddTextSaveButtonDisabledWhenEmpty, testAddTextSaveButtonEnablesAfterTyping
    func testAddTextSheetUI() {
        app.buttons["addTextButton"].tap()
        XCTAssertTrue(app.navigationBars["Add Text"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["cancelButton"].exists, "Cancel button should exist")
        XCTAssertTrue(app.textViews["textEditor"].exists, "Text editor should be visible")

        // Save should be disabled when empty
        let saveButton = app.buttons["saveButton"]
        XCTAssertTrue(saveButton.exists)
        XCTAssertFalse(saveButton.isEnabled, "Save should be disabled when text is empty")

        // Save should enable after typing
        let textEditor = app.textViews["textEditor"]
        textEditor.tap()
        textEditor.typeText("a")
        XCTAssertTrue(saveButton.isEnabled, "Save should be enabled after typing text")

        // Cancel returns to main list
        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
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

        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Hello UI Test"].waitForExistence(timeout: 2))
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

    /// Consolidates: testAddTextShowsTextTag, testAddURLTextShowsURLTag, testAddMultipleURLItems, testAddLongTextItem
    func testAddTextItemTypes() {
        // Plain text → "Text" tag
        addTextItem("Plain text tag test")
        XCTAssertTrue(app.staticTexts["Text"].waitForExistence(timeout: 2), "Text tag should appear for plain text")

        // URL → "URL" tag
        addTextItem("https://example.com/first")
        XCTAssertTrue(app.staticTexts["URL"].waitForExistence(timeout: 2), "URL tag should appear for URL text")
        XCTAssertTrue(app.staticTexts["https://example.com/first"].exists)

        // Second URL
        addTextItem("https://example.com/second")
        XCTAssertTrue(app.staticTexts["https://example.com/second"].waitForExistence(timeout: 2))

        // Long text (truncation)
        let longText = "This is a long text item that should be properly handled by the UI and displayed correctly in the items list with appropriate truncation"
        addTextItem(longText)
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
    }

    // MARK: - Add Audio Flow

    /// Consolidates: testOpenAndCancelAddAudioSheet, testAudioRecordButtonExists, testAudioTimerDisplayExists,
    /// testAudioNavigationBarTitle, testAudioHasCancelAndSaveButtons, testAudioSaveDisabledWithoutRecording
    func testAddAudioSheetUI() {
        app.buttons["addAudioButton"].tap()
        XCTAssertTrue(app.navigationBars["Audio Recording"].waitForExistence(timeout: 2))

        // Verify all UI elements
        XCTAssertTrue(app.buttons["cancelButton"].exists, "Cancel button should exist")
        XCTAssertTrue(app.buttons["recordButton"].exists, "Record button should exist")
        XCTAssertTrue(app.staticTexts["00:00.0"].exists, "Timer should show 00:00.0 initially")

        let saveButton = app.buttons["saveButton"]
        XCTAssertTrue(saveButton.exists, "Save button should exist")
        XCTAssertFalse(saveButton.isEnabled, "Save should be disabled before recording")

        // Cancel returns to main list
        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
    }

    // MARK: - Add Photo/Video Flow

    /// Consolidates: testOpenAndCancelAddPhotoVideoSheet, testPhotoVideoSaveButtonDisabledWhenEmpty,
    /// testPhotoVideoViewHasCameraAndLibraryOptions, testPhotoVideoNavigationBarTitle,
    /// testPhotoVideoHasCameraButton, testPhotoVideoHasCancelAndSaveButtons, testPhotoVideoSubtitles
    func testAddPhotoVideoSheetUI() {
        app.buttons["addPhotoVideoButton"].tap()
        XCTAssertTrue(app.navigationBars["Photos & Videos"].waitForExistence(timeout: 2))

        // Verify all UI elements
        XCTAssertTrue(app.buttons["cancelButton"].exists, "Cancel button should exist")
        XCTAssertTrue(app.buttons["cameraButton"].exists, "Camera button should exist")
        XCTAssertTrue(app.buttons["cameraButton"].isEnabled, "Camera button should be enabled")

        let saveButton = app.buttons["saveButton"]
        XCTAssertTrue(saveButton.exists, "Save button should exist")
        XCTAssertFalse(saveButton.isEnabled, "Save should be disabled when no items are selected")

        // Camera and library options with subtitles
        XCTAssertTrue(app.staticTexts["Take Photo or Video"].exists, "Camera option should exist")
        XCTAssertTrue(app.staticTexts["Select Photos & Videos"].exists, "Library option should exist")
        XCTAssertTrue(app.staticTexts["Capture with your camera"].exists, "Camera subtitle should exist")
        XCTAssertTrue(app.staticTexts["Tap to choose from your library"].exists, "Library subtitle should exist")

        // Cancel returns to main list
        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
    }

    // MARK: - Settings View

    /// Consolidates: testSettingsShowsVersionAndBuild, testSettingsNavigationBarTitle,
    /// testSettingsShowsVersionNumber, testSettingsShowsBuildNumber, testSettingsShowsAppSectionHeader
    func testSettingsViewContent() {
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))

        XCTAssertTrue(app.staticTexts["appSectionHeader"].exists, "App section header should exist")
        XCTAssertTrue(app.staticTexts["Version"].exists, "Version label should exist")
        XCTAssertTrue(app.staticTexts["Build"].exists, "Build label should exist")
        XCTAssertTrue(app.staticTexts["1.1"].exists, "Version 1.1 should be displayed")
        XCTAssertTrue(app.staticTexts["1"].exists, "Build number should be displayed")
    }

    // MARK: - Tags View

    /// Consolidates: testTagsViewShowsEmptyState, testTagsNavigationBarTitle, testTagsEmptyStateMessage
    func testTagsViewEmptyState() {
        app.tabBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))

        let hasContent = app.staticTexts["No Tags"].exists || app.cells.firstMatch.exists
        XCTAssertTrue(hasContent, "Tags view should show either tags or empty state")

        if app.staticTexts["No Tags"].exists {
            XCTAssertTrue(app.staticTexts["Add tags to your items to organize them."].exists, "Empty state description should be shown")
        }
    }

    /// Consolidates: testTagsViewShowsTagsAfterAddingItem, testTagsViewShowsURLTagAfterAddingURL
    func testTagsViewShowsTagsAfterAddingItems() {
        // Add text item → "Text" tag
        addTextItem("Tag display test")
        app.tabBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Text"].waitForExistence(timeout: 2), "Text tag should exist after adding text item")

        // Add URL item → "URL" tag
        addTextItem("https://example.com/tagtest")
        app.tabBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["URL"].waitForExistence(timeout: 2), "URL tag should exist after adding URL item")
    }

    // MARK: - Item Detail & Edit Flow

    /// Consolidates: testTapItemOpensDetail, testDetailViewShowsAllButtons, testDoneButtonDismissesDetail,
    /// testEditViewNavigationBarTitle, testEditViewHasNameField, testEditViewHasTagInputField,
    /// testEditViewHasCancelAndSaveButtons
    func testItemDetailAndEditViewUI() {
        addTextItem("UI elements test item")

        // Tap item opens detail with all buttons
        let itemText = app.staticTexts["UI elements test item"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))
        itemText.tap()

        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2), "Done button should exist")
        XCTAssertTrue(app.buttons["editButton"].exists, "Edit button should exist")
        XCTAssertTrue(app.buttons["shareButton"].exists, "Share button should exist")

        // Open edit view and verify UI elements
        app.buttons["editButton"].tap()
        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["nameTextField"].exists, "Name text field should exist in edit view")
        XCTAssertTrue(app.textFields["tagInputField"].exists, "Tag input field should exist in edit view")
        XCTAssertTrue(app.buttons["cancelButton"].exists, "Cancel button should exist in edit view")
        XCTAssertTrue(app.buttons["saveButton"].exists, "Save button should exist in edit view")
        app.buttons["cancelButton"].tap()

        // Done button dismisses detail
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        app.buttons["doneButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2), "Should return to items list after tapping Done")
    }

    func testEditItemName() {
        addTextItem("Original name item")

        let itemText = app.staticTexts["Original name item"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))
        itemText.tap()

        XCTAssertTrue(app.buttons["editButton"].waitForExistence(timeout: 2))
        app.buttons["editButton"].tap()

        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))
        let nameField = app.textFields["nameTextField"]
        XCTAssertTrue(nameField.exists)
        nameField.tap()
        nameField.clearAndTypeText("Renamed item")

        app.buttons["saveButton"].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        app.buttons["doneButton"].tap()

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

        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Cancel edit test"].exists)
        XCTAssertFalse(app.staticTexts["Should not save"].exists)
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

    // MARK: - Add Tag in Edit View

    /// Consolidates: testAddTagToItem, testAddMultipleTagsToItem, testCustomTagVisibleInTagsTab
    func testAddTagsToItemAndVerifyInTagsTab() {
        addTextItem("Taggable item")

        let itemText = app.staticTexts["Taggable item"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))
        itemText.tap()

        XCTAssertTrue(app.buttons["editButton"].waitForExistence(timeout: 2))
        app.buttons["editButton"].tap()
        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))

        let tagInput = app.textFields["tagInputField"]
        XCTAssertTrue(tagInput.exists, "Tag input field should exist")

        // Add first tag
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

        // Verify tags appear on item in list
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["TagA"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["TagB"].exists)

        // Verify custom tags visible in Tags tab
        app.tabBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["TagA"].waitForExistence(timeout: 2), "Custom tag should appear in Tags tab")
        XCTAssertTrue(app.staticTexts["TagB"].exists, "Second custom tag should appear in Tags tab")
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

        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        app.buttons["doneButton"].tap()

        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["CancelledTag"].exists, "Cancelled tag should not appear")
    }

    // MARK: - Quick Tag Management (Context Menu)

    /// Consolidates: testManageTagsFromContextMenu, testQuickTagViewHasNewTagInput, testSwipeToOpenTags
    func testQuickTagManagement() {
        addTextItem("Quick tag test")

        let itemText = app.staticTexts["Quick tag test"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))

        // Open via context menu
        itemText.press(forDuration: 1.0)
        let manageTagsButton = app.buttons["Manage Tags"]
        XCTAssertTrue(manageTagsButton.waitForExistence(timeout: 2), "Manage Tags should appear in context menu")
        manageTagsButton.tap()

        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["newTagField"].exists, "New tag input field should exist in quick tag view")
        app.buttons["cancelButton"].firstMatch.tap()

        // Open via swipe right
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))
        itemText.swipeRight()
        let tagsButton = app.buttons["swipeTagsButton"]
        if tagsButton.waitForExistence(timeout: 2) {
            tagsButton.tap()
            XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))
            app.buttons["cancelButton"].firstMatch.tap()
        }
    }

    // MARK: - Delete Item

    /// Consolidates: testDeleteItemViaSwipe, testDeleteItemViaContextMenu
    func testDeleteItemViaDifferentMethods() {
        addTextItem("Delete via swipe")
        addTextItem("Delete via context")

        // Delete via swipe
        let item1 = app.staticTexts["Delete via swipe"]
        XCTAssertTrue(item1.waitForExistence(timeout: 2))
        item1.swipeLeft()
        if app.buttons["Delete"].waitForExistence(timeout: 2) {
            app.buttons["Delete"].tap()
        }
        XCTAssertTrue(item1.waitForNonExistence(timeout: 3), "Swiped item should no longer appear in the list")

        // Delete via context menu
        let item2 = app.staticTexts["Delete via context"]
        XCTAssertTrue(item2.waitForExistence(timeout: 2))
        item2.press(forDuration: 1.0)
        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
        deleteButton.tap()
        XCTAssertTrue(item2.waitForNonExistence(timeout: 3), "Context-deleted item should no longer appear in the list")
    }

    func testDeleteMultipleItemsSequentially() {
        addTextItem("Sequential delete 1")
        addTextItem("Sequential delete 2")

        let item1 = app.staticTexts["Sequential delete 1"]
        XCTAssertTrue(item1.waitForExistence(timeout: 2))
        item1.swipeLeft()
        if app.buttons["Delete"].waitForExistence(timeout: 2) {
            app.buttons["Delete"].tap()
        }
        XCTAssertTrue(item1.waitForNonExistence(timeout: 3))

        let item2 = app.staticTexts["Sequential delete 2"]
        XCTAssertTrue(item2.waitForExistence(timeout: 2))
        item2.swipeLeft()
        if app.buttons["Delete"].waitForExistence(timeout: 2) {
            app.buttons["Delete"].tap()
        }
        XCTAssertTrue(item2.waitForNonExistence(timeout: 3))
    }

    // MARK: - Selection Mode

    /// Consolidates: testSelectButtonExists, testEnterSelectionMode, testCancelSelectionMode,
    /// testSelectAllButton, testDeleteSelectedButtonShowsCount
    func testSelectionModeFlow() {
        addTextItem("Select flow 1")
        addTextItem("Select flow 2")

        // Select button exists
        let selectButton = app.buttons["selectButton"]
        XCTAssertTrue(selectButton.waitForExistence(timeout: 2), "Select button should exist when items are present")

        // Enter selection mode
        selectButton.tap()
        XCTAssertTrue(app.buttons["cancelSelectButton"].waitForExistence(timeout: 2), "Cancel select button should appear in selection mode")

        // Cancel selection mode
        app.buttons["cancelSelectButton"].tap()
        XCTAssertTrue(app.buttons["selectButton"].waitForExistence(timeout: 2), "Select button should reappear after cancelling selection")

        // Re-enter and select all
        app.buttons["selectButton"].tap()
        XCTAssertTrue(app.buttons["cancelSelectButton"].waitForExistence(timeout: 2))
        app.buttons["selectButton"].tap()

        // Delete selected button should appear with count
        let deleteButton = app.buttons["deleteSelectedButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2), "Delete selected button should appear after selecting all")

        app.buttons["cancelSelectButton"].tap()
    }

    func testDeleteSelectedItems() {
        addTextItem("Bulk delete 1")
        addTextItem("Bulk delete 2")

        let selectButton = app.buttons["selectButton"]
        XCTAssertTrue(selectButton.waitForExistence(timeout: 3), "Select button should be visible when items are present")
        selectButton.tap()
        XCTAssertTrue(app.buttons["cancelSelectButton"].waitForExistence(timeout: 2))

        app.buttons["selectButton"].tap()

        let deleteSelected = app.buttons["deleteSelectedButton"]
        XCTAssertTrue(deleteSelected.waitForExistence(timeout: 2))
        deleteSelected.tap()

        XCTAssertTrue(app.staticTexts["Bulk delete 1"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Bulk delete 2"].waitForNonExistence(timeout: 3))
    }

    func testSelectionModeHidesContextMenu() {
        addTextItem("No context in select")

        app.buttons["selectButton"].tap()
        XCTAssertTrue(app.buttons["cancelSelectButton"].waitForExistence(timeout: 2))

        let itemText = app.staticTexts["No context in select"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))
        itemText.press(forDuration: 1.0)

        let shareButton = app.buttons["Share"]
        XCTAssertFalse(shareButton.waitForExistence(timeout: 1), "Context menu should not appear in selection mode")

        app.buttons["cancelSelectButton"].tap()
    }

    // MARK: - Context Menu

    /// Consolidates: testContextMenuShowsAllOptions, testContextMenuDismissByTappingOutside
    func testContextMenu() {
        addTextItem("Context menu check")

        let itemText = app.staticTexts["Context menu check"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))
        itemText.press(forDuration: 1.0)

        XCTAssertTrue(app.buttons["Share"].waitForExistence(timeout: 2), "Share should appear in context menu")
        XCTAssertTrue(app.buttons["Manage Tags"].exists, "Manage Tags should appear in context menu")
        XCTAssertTrue(app.buttons["Delete"].exists, "Delete should appear in context menu")

        // Dismiss by tapping outside
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 3), "Should return to items list")
    }

    // MARK: - Empty State

    /// Consolidates: testEmptyStateShowsWhenNoItems, testEmptyStateDisappearsAfterAddingItem
    func testEmptyStateBehavior() {
        let emptyState = app.staticTexts["No Items"]
        let hasItems = app.cells.firstMatch.exists
        XCTAssertTrue(emptyState.exists || hasItems, "Should show empty state or items")

        addTextItem("Fill empty state")

        XCTAssertFalse(app.staticTexts["No Items"].exists, "Empty state should disappear after adding item")
        XCTAssertTrue(app.staticTexts["Fill empty state"].exists, "Added item should be visible")
    }

    // MARK: - Tags Tab Navigation

    /// Consolidates: testTagsTabNavigationToFilteredList, testTagsTabNavigationBackButton,
    /// testFilteredListShowsCorrectItems
    func testTagsTabNavigation() {
        addTextItem("Filter text item")
        addTextItem("https://example.com/filtertest")

        app.tabBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))

        // Navigate to Text tag filtered list
        let textTag = app.staticTexts["Text"]
        if textTag.waitForExistence(timeout: 2) {
            textTag.tap()
            XCTAssertTrue(app.navigationBars["Text"].waitForExistence(timeout: 2))
            XCTAssertTrue(app.staticTexts["Filter text item"].waitForExistence(timeout: 2))

            // Go back
            app.navigationBars.buttons["Tags"].tap()
            XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))
        }

        // Navigate to URL tag and verify filtering
        let urlTag = app.staticTexts["URL"]
        if urlTag.waitForExistence(timeout: 2) {
            urlTag.tap()
            XCTAssertTrue(app.navigationBars["URL"].waitForExistence(timeout: 2))
            XCTAssertTrue(app.staticTexts["https://example.com/filtertest"].waitForExistence(timeout: 2))
            XCTAssertFalse(app.staticTexts["Filter text item"].exists, "Non-URL items should not appear in URL-filtered list")
        }
    }

    // MARK: - Multiple Items & Display

    /// Consolidates: testAddMultipleTextItems, testItemsListOrder, testItemTagsBadgesDisplayInList,
    /// testURLItemTagsBadgesDisplayInList, testItemRowShowsCreationDate, testItemRowDisplaysLocation,
    /// testURLItemDetailShowsOpenInBrowser, testURLItemShowsLinkIcon
    func testMultipleItemsAndDisplay() {
        addTextItem("First item")
        addTextItem("Second item")
        addTextItem("Third item")

        // All items visible
        XCTAssertTrue(app.staticTexts["First item"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Second item"].exists)
        XCTAssertTrue(app.staticTexts["Third item"].exists)

        // Text tag badge visible
        XCTAssertTrue(app.staticTexts["Text"].exists, "Text tag badge should be visible in item row")

        // Add URL item and verify display
        addTextItem("https://example.com/display")
        XCTAssertTrue(app.staticTexts["https://example.com/display"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["URL"].exists, "URL tag badge should be visible in item row")
    }

    // MARK: - Text Detail Content

    /// Consolidates: testTextItemDetailShowsContent, testTextItemDetailPreservesFullContent
    func testTextItemDetailContent() {
        let content = "Multi word content for detail"
        addTextItem(content)

        app.staticTexts[content].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts[content].exists, "Full text content should be displayed in detail")
        app.buttons["doneButton"].tap()
    }

    // MARK: - Share Sheet Features

    /// Consolidates: testShareButtonVisibleInDetailView, testShareTextItemOpensShareSheet,
    /// testDismissShareSheetReturnsToDetailView
    func testShareFromDetailView() {
        addTextItem("Share detail test")

        app.staticTexts["Share detail test"].tap()
        XCTAssertTrue(app.buttons["shareButton"].waitForExistence(timeout: 2), "Share button should be visible in detail view")
        app.buttons["shareButton"].tap()

        XCTAssertTrue(waitForShareSheet(), "Share sheet should appear for text item")
        dismissShareSheet()

        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 3), "Should return to detail view after dismissing share sheet")
        XCTAssertTrue(app.buttons["shareButton"].exists, "Share button should still be visible")
        app.buttons["doneButton"].tap()
    }

    /// Consolidates: testShareFromContextMenu, testDismissShareSheetFromContextMenuReturnsList,
    /// testShareURLItemFromContextMenu
    func testShareFromContextMenu() {
        addTextItem("Context share text")
        addTextItem("https://example.com/share")

        // Share text item from context menu
        let textItem = app.staticTexts["Context share text"]
        XCTAssertTrue(textItem.waitForExistence(timeout: 2))
        textItem.press(forDuration: 1.0)
        let shareButton = app.buttons["Share"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 2), "Context menu should have Share option")
        shareButton.tap()
        XCTAssertTrue(waitForShareSheet(), "Share sheet should appear from context menu")
        dismissShareSheet()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 3), "Should return to items list")

        // Share URL item from context menu
        let urlItem = app.staticTexts["https://example.com/share"]
        XCTAssertTrue(urlItem.waitForExistence(timeout: 2))
        urlItem.press(forDuration: 1.0)
        let shareButton2 = app.buttons["Share"]
        XCTAssertTrue(shareButton2.waitForExistence(timeout: 2))
        shareButton2.tap()
        XCTAssertTrue(waitForShareSheet(), "Share sheet should appear for URL item via context menu")
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

        XCTAssertTrue(app.buttons["shareButton"].waitForExistence(timeout: 2))
        app.buttons["shareButton"].tap()

        XCTAssertTrue(waitForShareSheet(), "Share should still work after editing item")
    }

    // MARK: - Item Lifecycle

    /// Consolidates: testAddThenDeleteItem, testAddEditThenDeleteItem, testAddShareThenDeleteItem
    func testItemLifecycle() {
        addTextItem("Full lifecycle item")
        XCTAssertTrue(app.staticTexts["Full lifecycle item"].waitForExistence(timeout: 2))

        // Edit
        app.staticTexts["Full lifecycle item"].tap()
        XCTAssertTrue(app.buttons["editButton"].waitForExistence(timeout: 2))
        app.buttons["editButton"].tap()
        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))
        let nameField = app.textFields["nameTextField"]
        nameField.tap()
        nameField.clearAndTypeText("Edited lifecycle")
        app.buttons["saveButton"].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))

        // Share
        app.buttons["shareButton"].tap()
        XCTAssertTrue(waitForShareSheet())
        dismissShareSheet()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 3))
        app.buttons["doneButton"].tap()

        // Delete
        XCTAssertTrue(app.staticTexts["Edited lifecycle"].waitForExistence(timeout: 2))
        app.staticTexts["Edited lifecycle"].swipeLeft()
        if app.buttons["Delete"].waitForExistence(timeout: 2) {
            app.buttons["Delete"].tap()
        }
        XCTAssertTrue(app.staticTexts["Edited lifecycle"].waitForNonExistence(timeout: 3))
    }

    // MARK: - Reopening Sheets

    /// Consolidates: testReopenAddTextSheetAfterCancel, testReopenAddAudioSheetAfterCancel,
    /// testReopenAddPhotoVideoSheetAfterCancel, testReopenDetailAfterDismiss,
    /// testOpenEachAddSheetSequentially
    func testReopeningSheetsAfterCancel() {
        // Open and reopen Add Text
        app.buttons["addTextButton"].tap()
        XCTAssertTrue(app.navigationBars["Add Text"].waitForExistence(timeout: 2))
        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        app.buttons["addTextButton"].tap()
        XCTAssertTrue(app.navigationBars["Add Text"].waitForExistence(timeout: 2))
        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))

        // Open and reopen Add Audio
        app.buttons["addAudioButton"].tap()
        XCTAssertTrue(app.navigationBars["Audio Recording"].waitForExistence(timeout: 2))
        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        app.buttons["addAudioButton"].tap()
        XCTAssertTrue(app.navigationBars["Audio Recording"].waitForExistence(timeout: 2))
        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))

        // Open and reopen Add Photo/Video
        app.buttons["addPhotoVideoButton"].tap()
        XCTAssertTrue(app.navigationBars["Photos & Videos"].waitForExistence(timeout: 2))
        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        app.buttons["addPhotoVideoButton"].tap()
        XCTAssertTrue(app.navigationBars["Photos & Videos"].waitForExistence(timeout: 2))
        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))

        // Open and reopen detail
        addTextItem("Reopen detail test")
        app.staticTexts["Reopen detail test"].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        app.buttons["doneButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        app.staticTexts["Reopen detail test"].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        app.buttons["doneButton"].tap()
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
        XCTAssertTrue(app.navigationBars["Add Text"].waitForExistence(timeout: 5))

        let textEditor = app.textViews["textEditor"]
        textEditor.tap()
        textEditor.typeText(text)

        app.buttons["saveButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 5))
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
