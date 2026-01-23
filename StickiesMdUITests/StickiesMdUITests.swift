//
//  StickiesMdUITests.swift
//  StickiesMdUITests
//
//  Created by Gemini on 2026/01/23.
//

import XCTest

final class StickiesMdUITests: XCTestCase {

    override func setUpWithError() throws {
        // In UI tests, it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
    }

    func testLaunch() throws {
        // Create an instance of the UI application
        let app = XCUIApplication()
        // Launch the application
        app.launch()
        
        // Launch verification: Check that at least one window is open
        XCTAssertTrue(app.windows.firstMatch.exists, "A window should be displayed after launching the app")
    }

    func testToolbarButtons() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Verify buttons exist
        XCTAssertTrue(app.buttons["save_button"].exists, "Save button should exist")
        XCTAssertTrue(app.buttons["pin_button"].exists, "Pin button should exist")
        XCTAssertTrue(app.buttons["settings_button"].exists, "Settings button should exist")
    }
    
    func testSettingsPopover() throws {
        let app = XCUIApplication()
        app.launch()
        
        let settingsButton = app.buttons["settings_button"]
        XCTAssertTrue(settingsButton.exists)
        
        settingsButton.click()
        
        // After clicking, a popover should appear. 
        // In macOS SwiftUI, popovers usually appear as a new entity.
        // We can check if a new element (like a static text inside SettingsView) appears, 
        // or check app.popovers.
        
        // Since we haven't added IDs to SettingsView, just checking if *any* popover or new element appears might be brittle.
        // However, standard popovers often register in the hierarchy.
        // Let's assume standard behavior:
        XCTAssertTrue(app.popovers.firstMatch.waitForExistence(timeout: 2.0), "Popover should appear after clicking settings")
    }
    
    func testTextEditing() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Access the text editor. 
        // We added "rich_text_editor" to the SwiftUI view and "rich_text_editor_textview" to the NSTextView.
        // Usually, the NSTextView inside a scroll view is what receives the input.
        let textView = app.textViews["rich_text_editor_textview"]
        
        XCTAssertTrue(textView.waitForExistence(timeout: 2.0), "Text editor should exist")
        
        textView.click()
        textView.typeText("Hello UI Test")
        
        XCTAssertEqual(textView.value as? String, "Hello UI Test", "Text view content should match typed text")
    }
}
