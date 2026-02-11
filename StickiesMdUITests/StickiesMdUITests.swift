//
//  StickiesMdUITests.swift
//  StickiesMdUITests
//
//  Created by Ryohei Ueda on 2026/01/23.
//

import XCTest

final class StickiesMdUITests: XCTestCase {

  private let app = XCUIApplication()

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  override func tearDownWithError() throws {
    app.terminate()
    waitForAppToTerminate(app)
  }

  @MainActor
  func testMainControlsExist() throws {
    app.launchArguments.append("--reset-state")
    app.launch()

    // Wait for at least one window/panel to appear
    let window = app.descendants(matching: .any)["StickyWindow"].firstMatch

    if !window.waitForExistence(timeout: 5) {
      // If no window exists, try to create one from the menu
      let menuBarsQuery = app.menuBars
      menuBarsQuery.menuBarItems["File"].click()
      menuBarsQuery.menuItems["New Sticky"].click()
    }

    XCTAssertTrue(window.waitForExistence(timeout: 10), "Sticky window should exist")

    // Check if the buttons exist
    let saveButton = window.buttons["saveButton"].firstMatch
    let pinButton = window.buttons["pinButton"].firstMatch
    let settingsButton = window.buttons["settingsButton"].firstMatch

    XCTAssertTrue(saveButton.exists, "Save button should exist")
    XCTAssertTrue(pinButton.exists, "Pin button should exist")
    XCTAssertTrue(settingsButton.exists, "Settings button should exist")
  }

  @MainActor
  func skipTestOpenSettings() throws {
    app.launchArguments.append("--reset-state")
    app.launch()

    let window = app.descendants(matching: .any)["StickyWindow"].firstMatch
    if !window.waitForExistence(timeout: 5) {
      let menuBarsQuery = app.menuBars
      menuBarsQuery.menuBarItems["File"].click()
      menuBarsQuery.menuItems["New Sticky"].click()
    }

    XCTAssertTrue(window.waitForExistence(timeout: 15), "Sticky window should exist")

    // Ensure window is focused
    window.click()

    let settingsButton = window.buttons["settingsButton"].firstMatch
    XCTAssertTrue(settingsButton.waitForExistence(timeout: 15), "Settings button should exist")

    print("Clicking settings button...")
    settingsButton.click()

    // Check if settings popover appeared
    let settingsTitle = app.staticTexts["settingsTitle"].firstMatch
    print("Waiting for settings title...")
    if !settingsTitle.waitForExistence(timeout: 5) {
      print("Retry clicking settings button...")
      settingsButton.click()
      XCTAssertTrue(
        settingsTitle.waitForExistence(timeout: 15), "Settings title should appear after retry")
    } else {
      XCTAssertTrue(settingsTitle.exists)
    }

    let opacitySlider = app.sliders["opacitySlider"].firstMatch
    XCTAssertTrue(opacitySlider.exists, "Opacity slider should exist in settings")
  }

  private func waitForAppToTerminate(_ app: XCUIApplication, timeout: TimeInterval = 5) {
    let deadline = Date().addingTimeInterval(timeout)
    while app.state != .notRunning && Date() < deadline {
      Thread.sleep(forTimeInterval: 0.1)
    }
  }
}
