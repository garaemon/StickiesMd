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
        
        // Additional verification: Take a screenshot if necessary
        // let attachment = XCTAttachment(screenshot: app.screenshot())
        // attachment.lifetime = .keepAlways
        // add(attachment)
    }
}