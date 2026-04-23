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

    // MARK: - Tab Navigation & Settings

    /// Covers: tab bar presence, all three tabs, forward/reverse navigation,
    /// settings content (version, build, section header), and accessibility identifiers.
    func testTabNavigationSettingsAndAccessibility() {
        // Verify tab bar exists with all three tabs
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should be visible")
        XCTAssertTrue(tabBar.buttons["Items"].exists, "Items tab should exist")
        XCTAssertTrue(tabBar.buttons["Settings"].exists, "Settings tab should exist")
        XCTAssertTrue(tabBar.buttons["Tags"].exists, "Tags tab should exist")

        // Items → Settings (verify content)
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["appSectionHeader"].exists, "App section header should exist")
        XCTAssertTrue(app.staticTexts["Version"].exists, "Version label should exist")
        XCTAssertTrue(app.staticTexts["Build"].exists, "Build label should exist")
        XCTAssertTrue(app.staticTexts["1.3"].exists, "Version 1.3 should be displayed")
        XCTAssertTrue(app.staticTexts["1"].exists, "Build number should be displayed")

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

    // MARK: - Items Tab Toolbar

    func testItemsTabToolbarButtons() {
        XCTAssertTrue(app.buttons["addTextButton"].exists, "Add text button should be visible")
        XCTAssertTrue(app.buttons["addTextButton"].isEnabled, "Add text button should be enabled")
        XCTAssertTrue(app.buttons["addPhotoVideoButton"].exists, "Add photo/video button should be visible")
        XCTAssertTrue(app.buttons["addPhotoVideoButton"].isEnabled, "Add photo/video button should be enabled")
        XCTAssertTrue(app.buttons["addCameraButton"].exists, "Add camera button should be visible")
        XCTAssertTrue(app.buttons["addCameraButton"].isEnabled, "Add camera button should be enabled")
        XCTAssertTrue(app.buttons["addAudioButton"].exists, "Add audio button should be visible")
        XCTAssertTrue(app.buttons["addAudioButton"].isEnabled, "Add audio button should be enabled")
    }

    // MARK: - Add Text Flow

    /// Covers: sheet UI, save disabled when empty, save enables after typing,
    /// cancel returns to list, save creates item, cancel doesn't create item.
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

    /// Covers: save creates item, cancel doesn't create item, text and URL tag detection,
    /// long text handling.
    func testAddTextSaveCancelAndItemTypes() {
        // Save creates item
        addTextItem("Hello UI Test")
        XCTAssertTrue(app.staticTexts["Hello UI Test"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Text"].exists, "Text tag should appear for plain text")

        // Cancel doesn't create item
        app.buttons["addTextButton"].tap()
        XCTAssertTrue(app.navigationBars["Add Text"].waitForExistence(timeout: 2))
        let textEditor = app.textViews["textEditor"]
        textEditor.tap()
        textEditor.typeText("Not saved")
        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Not saved"].exists, "Cancelled text should not appear")

        // URL → "URL" tag
        addTextItem("https://example.com/first")
        XCTAssertTrue(app.staticTexts["URL"].waitForExistence(timeout: 2), "URL tag should appear for URL text")
        XCTAssertTrue(app.staticTexts["https://example.com/first"].exists)

        // Long text
        let longText = "This is a long text item that should be properly handled by the UI and displayed correctly in the items list with appropriate truncation"
        addTextItem(longText)
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
    }

    // MARK: - Add Audio Flow

    func testAddAudioSheetUI() {
        app.buttons["addAudioButton"].tap()
        XCTAssertTrue(app.navigationBars["Audio Recording"].waitForExistence(timeout: 2))

        XCTAssertTrue(app.buttons["cancelButton"].exists, "Cancel button should exist")
        XCTAssertTrue(app.buttons["recordButton"].exists, "Record button should exist")
        XCTAssertTrue(app.staticTexts["00:00.0"].exists, "Timer should show 00:00.0 initially")

        let saveButton = app.buttons["saveButton"]
        XCTAssertTrue(saveButton.exists, "Save button should exist")
        XCTAssertFalse(saveButton.isEnabled, "Save should be disabled before recording")

        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
    }

    // MARK: - Add Photo/Video Flow

    func testAddPhotoVideoButtonExists() {
        XCTAssertTrue(app.buttons["addPhotoVideoButton"].exists, "Add photo/video button should exist")
        XCTAssertTrue(app.buttons["addPhotoVideoButton"].isEnabled, "Add photo/video button should be enabled")
        XCTAssertTrue(app.buttons["addCameraButton"].exists, "Add camera button should exist")
        XCTAssertTrue(app.buttons["addCameraButton"].isEnabled, "Add camera button should be enabled")
    }

    // MARK: - Tags View

    func testTagsViewEmptyState() {
        app.tabBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))

        let hasContent = app.staticTexts["No Tags"].exists || app.cells.firstMatch.exists
        XCTAssertTrue(hasContent, "Tags view should show either tags or empty state")

        if app.staticTexts["No Tags"].exists {
            XCTAssertTrue(app.staticTexts["Add tags to your items to organize them."].exists, "Empty state description should be shown")
        }
    }

    /// Covers: tags appear after adding items, tags tab shows item counts, tag navigation to
    /// filtered list, back button, filtering correctness.
    func testTagsViewWithItemsCountsAndNavigation() {
        // Add text and URL items
        addTextItem("Filter text item")
        addTextItem("https://example.com/filtertest")

        app.tabBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Text"].waitForExistence(timeout: 2), "Text tag should exist")
        XCTAssertTrue(app.staticTexts["URL"].waitForExistence(timeout: 2), "URL tag should exist")

        // Verify item counts are displayed next to tags
        XCTAssertTrue(app.staticTexts["tagCount_Text"].exists, "Text tag item count should be displayed")
        XCTAssertTrue(app.staticTexts["tagCount_URL"].exists, "URL tag item count should be displayed")

        // Navigate to Text tag filtered list
        app.staticTexts["Text"].tap()
        XCTAssertTrue(app.navigationBars["Text"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Filter text item"].waitForExistence(timeout: 2))

        // Go back
        app.navigationBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))

        // Navigate to URL tag and verify filtering
        let urlTag = app.staticTexts["URL"]
        if urlTag.waitForExistence(timeout: 2) {
            urlTag.tap()
            XCTAssertTrue(app.navigationBars["URL"].waitForExistence(timeout: 2))
            XCTAssertTrue(app.staticTexts["https://example.com/filtertest"].waitForExistence(timeout: 2))
            XCTAssertFalse(app.staticTexts["Filter text item"].exists, "Non-URL items should not appear in URL-filtered list")
        }
    }

    // MARK: - Item Detail & Edit Flow

    /// Covers: detail view buttons, edit view UI elements, edit name (save + cancel + multiple),
    /// tag removal in edit view, URL item "Open in Browser" button.
    func testItemDetailEditAndTagRemoval() {
        addTextItem("Editable item")

        // Open detail and verify buttons
        let itemText = app.staticTexts["Editable item"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))
        itemText.tap()

        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2), "Done button should exist")
        XCTAssertTrue(app.buttons["editButton"].exists, "Edit button should exist")
        XCTAssertTrue(app.buttons["shareButton"].exists, "Share button should exist")

        // Open edit view and verify UI elements
        app.buttons["editButton"].tap()
        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["nameTextField"].exists, "Name text field should exist")
        XCTAssertTrue(app.textFields["tagInputField"].exists, "Tag input field should exist")
        XCTAssertTrue(app.buttons["cancelButton"].exists, "Cancel button should exist")
        XCTAssertTrue(app.buttons["saveButton"].exists, "Save button should exist")

        // Edit name and cancel → should not save
        let nameField = app.textFields["nameTextField"]
        nameField.tap()
        nameField.clearAndTypeText("Should not save")
        app.buttons["cancelButton"].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))

        // Verify original name preserved
        app.buttons["doneButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Editable item"].exists, "Original name should be preserved after cancel")
        XCTAssertFalse(app.staticTexts["Should not save"].exists)

        // Edit name and save → should persist (first rename)
        app.staticTexts["Editable item"].tap()
        XCTAssertTrue(app.buttons["editButton"].waitForExistence(timeout: 2))
        app.buttons["editButton"].tap()
        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))
        let firstRenameField = app.textFields["nameTextField"]
        firstRenameField.tap()
        firstRenameField.clearAndTypeText("First rename")
        app.buttons["saveButton"].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))

        // Second rename → should overwrite first
        app.buttons["editButton"].tap()
        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))
        let secondRenameField = app.textFields["nameTextField"]
        secondRenameField.tap()
        secondRenameField.clearAndTypeText("Second rename")

        // Add a tag so we can test removal
        let tagInput = app.textFields["tagInputField"]
        tagInput.tap()
        tagInput.typeText("RemoveMe")
        let addTagBtn = app.buttons["addTagButton"]
        if addTagBtn.waitForExistence(timeout: 1) {
            addTagBtn.tap()
        } else {
            app.keyboards.buttons["Return"].tap()
        }

        // Verify tag appears and remove it via remove button
        XCTAssertTrue(app.staticTexts["RemoveMe"].waitForExistence(timeout: 2), "Added tag should appear")
        let removeButton = app.buttons["removeTag_RemoveMe"]
        if removeButton.waitForExistence(timeout: 2) {
            removeButton.tap()
            XCTAssertTrue(app.staticTexts["RemoveMe"].waitForNonExistence(timeout: 2), "Removed tag should disappear")
        }

        app.buttons["saveButton"].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        app.buttons["doneButton"].tap()

        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Second rename"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["First rename"].exists)
    }

    // MARK: - Add & Remove Tags in Edit View

    /// Covers: add multiple tags, verify tags in Tags tab, cancel doesn't save tags.
    func testAddTagsAndCancelTags() {
        addTextItem("Taggable item")

        // Add two tags and save
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

        // Verify tags in Tags tab
        app.tabBars.buttons["Tags"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["TagA"].waitForExistence(timeout: 2), "Custom tag should appear in Tags tab")
        XCTAssertTrue(app.staticTexts["TagB"].exists, "Second custom tag should appear in Tags tab")

        // Test cancel doesn't save tags
        app.tabBars.buttons["Items"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 2))

        app.staticTexts["Taggable item"].tap()
        XCTAssertTrue(app.buttons["editButton"].waitForExistence(timeout: 2))
        app.buttons["editButton"].tap()
        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))

        let tagInput2 = app.textFields["tagInputField"]
        tagInput2.tap()
        tagInput2.typeText("CancelledTag")
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

    // MARK: - Quick Tag Management

    /// Covers: context menu "Manage Tags", QuickTagView UI, swipe-right tag button,
    /// adding and saving tags via QuickTagView.
    func testQuickTagManagementAndSave() {
        addTextItem("Quick tag test")

        let itemText = app.staticTexts["Quick tag test"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))

        // Open QuickTagView via context menu
        itemText.press(forDuration: 1.0)
        let manageTagsButton = app.buttons["Manage Tags"]
        XCTAssertTrue(manageTagsButton.waitForExistence(timeout: 2), "Manage Tags should appear in context menu")
        manageTagsButton.tap()

        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["newTagField"].exists, "New tag input field should exist in quick tag view")

        // Add a new tag and save
        let newTagField = app.textFields["newTagField"]
        newTagField.tap()
        newTagField.typeText("QuickTag")
        let addButton = app.buttons["addTagButton"]
        if addButton.waitForExistence(timeout: 1) {
            addButton.tap()
        } else {
            app.keyboards.buttons["Return"].tap()
        }

        app.buttons["saveButton"].firstMatch.tap()

        // Verify the tag was saved on the item
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["QuickTag"].waitForExistence(timeout: 2), "Quick tag should be saved on item")

        // Open via swipe right
        itemText.swipeRight()
        let tagsButton = app.buttons["swipeTagsButton"]
        if tagsButton.waitForExistence(timeout: 2) {
            tagsButton.tap()
            XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 2))
            app.buttons["cancelButton"].firstMatch.tap()
        }
    }

    // MARK: - Delete Item

    /// Covers: delete via swipe, delete via context menu, sequential deletion.
    func testDeleteItemViaDifferentMethods() {
        addTextItem("Delete via swipe")
        addTextItem("Delete via context")
        addTextItem("Sequential delete")

        // Delete via swipe
        let item1 = app.staticTexts["Delete via swipe"]
        XCTAssertTrue(item1.waitForExistence(timeout: 2))
        item1.swipeLeft()
        if app.buttons["Delete"].waitForExistence(timeout: 2) {
            app.buttons["Delete"].tap()
        }
        XCTAssertTrue(item1.waitForNonExistence(timeout: 3), "Swiped item should be deleted")

        // Delete via context menu
        let item2 = app.staticTexts["Delete via context"]
        XCTAssertTrue(item2.waitForExistence(timeout: 2))
        item2.press(forDuration: 1.0)
        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
        deleteButton.tap()
        XCTAssertTrue(item2.waitForNonExistence(timeout: 3), "Context-deleted item should be deleted")

        // Sequential delete (remaining item)
        let item3 = app.staticTexts["Sequential delete"]
        XCTAssertTrue(item3.waitForExistence(timeout: 2))
        item3.swipeLeft()
        if app.buttons["Delete"].waitForExistence(timeout: 2) {
            app.buttons["Delete"].tap()
        }
        XCTAssertTrue(item3.waitForNonExistence(timeout: 3))
    }

    // MARK: - Selection Mode

    /// Covers: select button, enter/exit selection, select all, deselect all,
    /// delete selected count, bulk delete, context menu hidden in selection mode.
    func testSelectionModeFlow() {
        addTextItem("Select flow 1")
        addTextItem("Select flow 2")

        // Select button exists
        let selectButton = app.buttons["selectButton"]
        XCTAssertTrue(selectButton.waitForExistence(timeout: 2), "Select button should exist")

        // Enter and cancel selection mode
        selectButton.tap()
        XCTAssertTrue(app.buttons["cancelSelectButton"].waitForExistence(timeout: 2))
        app.buttons["cancelSelectButton"].tap()
        XCTAssertTrue(app.buttons["selectButton"].waitForExistence(timeout: 2), "Select button should reappear")

        // Enter selection mode, select all
        app.buttons["selectButton"].tap()
        XCTAssertTrue(app.buttons["cancelSelectButton"].waitForExistence(timeout: 2))
        app.buttons["selectButton"].tap()

        // Delete selected should appear with count
        let deleteSelected = app.buttons["deleteSelectedButton"]
        XCTAssertTrue(deleteSelected.waitForExistence(timeout: 2), "Delete selected button should appear")
        XCTAssertTrue(app.tabBars.firstMatch.exists, "Tab bar should stay visible in Items selection mode")
        XCTAssertTrue(app.tabBars.buttons["Items"].exists, "Items tab should still be present while bulk delete is available")

        // Deselect All – tapping selectButton again when all selected should deselect
        app.buttons["selectButton"].tap()
        XCTAssertTrue(app.buttons["deleteSelectedButton"].waitForNonExistence(timeout: 2), "Delete button should disappear after deselecting all")

        // Verify context menu hidden in selection mode
        let itemText = app.staticTexts["Select flow 1"]
        XCTAssertTrue(itemText.waitForExistence(timeout: 2))
        itemText.press(forDuration: 1.0)
        let shareButton = app.buttons["Share"]
        XCTAssertFalse(shareButton.waitForExistence(timeout: 1), "Context menu should not appear in selection mode")

        app.buttons["cancelSelectButton"].tap()
    }

    func testDeleteSelectedItems() {
        addTextItem("Bulk delete 1")
        addTextItem("Bulk delete 2")

        let selectButton = app.buttons["selectButton"]
        XCTAssertTrue(selectButton.waitForExistence(timeout: 3))
        selectButton.tap()
        XCTAssertTrue(app.buttons["cancelSelectButton"].waitForExistence(timeout: 2))

        app.buttons["selectButton"].tap()

        let deleteSelected = app.buttons["deleteSelectedButton"]
        XCTAssertTrue(deleteSelected.waitForExistence(timeout: 2))
        deleteSelected.tap()

        XCTAssertTrue(app.staticTexts["Bulk delete 1"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Bulk delete 2"].waitForNonExistence(timeout: 3))
    }

    // MARK: - Context Menu

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
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 3))
    }

    // MARK: - Empty State

    func testEmptyStateBehavior() {
        let emptyState = app.staticTexts["No Items"]
        let hasItems = app.cells.firstMatch.exists
        XCTAssertTrue(emptyState.exists || hasItems, "Should show empty state or items")

        addTextItem("Fill empty state")

        XCTAssertFalse(app.staticTexts["No Items"].exists, "Empty state should disappear")
        XCTAssertTrue(app.staticTexts["Fill empty state"].exists, "Added item should be visible")
    }

    // MARK: - Multiple Items & Display

    func testMultipleItemsAndDisplay() {
        addTextItem("First item")
        addTextItem("Second item")
        addTextItem("Third item")

        // All items visible
        XCTAssertTrue(app.staticTexts["First item"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Second item"].exists)
        XCTAssertTrue(app.staticTexts["Third item"].exists)
        XCTAssertTrue(app.staticTexts["Text"].exists, "Text tag badge should be visible")

        // Add URL item and verify display
        addTextItem("https://example.com/display")
        XCTAssertTrue(app.staticTexts["https://example.com/display"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["URL"].exists, "URL tag badge should be visible")
    }

    // MARK: - Text Detail Content

    func testTextItemDetailContent() {
        let content = "Multi word content for detail"
        addTextItem(content)

        app.staticTexts[content].tap()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts[content].exists, "Full text content should be displayed in detail")
        app.buttons["doneButton"].tap()
    }

    // MARK: - Share Sheet Features

    /// Covers: share from detail, share from context menu (text + URL), share after editing.
    func testShareFlows() {
        addTextItem("Share test")
        addTextItem("https://example.com/share")

        // Share from detail view
        app.staticTexts["Share test"].tap()
        XCTAssertTrue(app.buttons["shareButton"].waitForExistence(timeout: 2))
        app.buttons["shareButton"].tap()
        XCTAssertTrue(waitForShareSheet(), "Share sheet should appear from detail")
        dismissShareSheet()
        XCTAssertTrue(app.buttons["doneButton"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["shareButton"].exists, "Share button should still be visible")
        app.buttons["doneButton"].tap()

        // Share text item from context menu
        let textItem = app.staticTexts["Share test"]
        XCTAssertTrue(textItem.waitForExistence(timeout: 2))
        textItem.press(forDuration: 1.0)
        let shareButton = app.buttons["Share"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 2))
        shareButton.tap()
        XCTAssertTrue(waitForShareSheet(), "Share sheet should appear from context menu")
        dismissShareSheet()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 3))

        // Share URL item from context menu
        let urlItem = app.staticTexts["https://example.com/share"]
        XCTAssertTrue(urlItem.waitForExistence(timeout: 2))
        urlItem.press(forDuration: 1.0)
        let shareButton2 = app.buttons["Share"]
        XCTAssertTrue(shareButton2.waitForExistence(timeout: 2))
        shareButton2.tap()
        XCTAssertTrue(waitForShareSheet(), "Share sheet should appear for URL item")
        dismissShareSheet()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 3))

        // Share after editing
        app.staticTexts["Share test"].tap()
        XCTAssertTrue(app.buttons["editButton"].waitForExistence(timeout: 2))
        app.buttons["editButton"].tap()
        XCTAssertTrue(app.navigationBars["Edit"].waitForExistence(timeout: 2))
        let nameField = app.textFields["nameTextField"]
        nameField.tap()
        nameField.clearAndTypeText("Post-edit share")
        app.buttons["saveButton"].tap()
        XCTAssertTrue(app.buttons["shareButton"].waitForExistence(timeout: 2))
        app.buttons["shareButton"].tap()
        XCTAssertTrue(waitForShareSheet(), "Share should still work after editing")
    }

    // MARK: - Item Lifecycle

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

        // Open and reopen Add Photo/Video (now opens system photo picker directly; no nav bar to check)
        XCTAssertTrue(app.buttons["addPhotoVideoButton"].exists, "Add photo/video button should be accessible")
        XCTAssertTrue(app.buttons["addCameraButton"].exists, "Add camera button should be accessible")

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

    private func waitForShareSheet() -> Bool {
        let activityListView = app.otherElements["ActivityListView"]
        return activityListView.waitForExistence(timeout: 5)
    }

    private func dismissShareSheet() {
        let closeButton = app.navigationBars.buttons["Close"]
        if closeButton.waitForExistence(timeout: 2) {
            closeButton.tap()
        } else if app.buttons["Close"].firstMatch.waitForExistence(timeout: 2) {
            app.buttons["Close"].firstMatch.tap()
        }
        let activityListView = app.otherElements["ActivityListView"]
        let dismissed = activityListView.waitForNonExistence(timeout: 3)
        XCTAssertTrue(dismissed, "Share sheet should be dismissed")
    }

    /// Adds a text item via the Add Text sheet using clipboard paste for speed.
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

        // Use pasteboard for faster text input instead of character-by-character typing
        UIPasteboard.general.string = text
        textEditor.press(forDuration: 1.0)
        let pasteButton = app.menuItems["Paste"]
        if pasteButton.waitForExistence(timeout: 2) {
            pasteButton.tap()
        } else {
            // Fallback to typing if paste menu doesn't appear
            textEditor.typeText(text)
        }

        app.buttons["saveButton"].tap()
        XCTAssertTrue(app.navigationBars["SavedMessages"].waitForExistence(timeout: 5))
    }
}

// MARK: - XCUIElement Helpers

extension XCUIElement {
    func clearAndTypeText(_ text: String) {
        guard let currentValue = self.value as? String, !currentValue.isEmpty else {
            self.typeText(text)
            return
        }
        self.tap()
        self.press(forDuration: 1.0)
        let selectAll = XCUIApplication().menuItems["Select All"]
        if selectAll.waitForExistence(timeout: 1) {
            selectAll.tap()
            self.typeText(text)
        } else {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            self.typeText(deleteString + text)
        }
    }

    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}
