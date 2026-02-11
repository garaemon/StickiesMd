//
//  StickiesMdUITestsLaunchTests.swift
//  StickiesMdUITests
//
//  Created by Ryohei Ueda on 2026/01/23.
//

import XCTest

final class StickiesMdUITestsLaunchTests: XCTestCase {

  override class var runsForEachTargetApplicationUIConfiguration: Bool {
    false
  }

  private let app = XCUIApplication()

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  override func tearDownWithError() throws {
    app.terminate()
    waitForAppToTerminate(app)
  }

  @MainActor
  func testLaunch() throws {
    // Terminate any leftover instance and wait for it to fully exit
    app.terminate()
    waitForAppToTerminate(app)
    app.launchArguments.append("--reset-state")
    app.launch()

    // Insert steps here to perform after app launch but before taking a screenshot,
    // such as logging into a test account or navigating somewhere in the app

    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "Launch Screen"
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func waitForAppToTerminate(_ app: XCUIApplication, timeout: TimeInterval = 5) {
    let deadline = Date().addingTimeInterval(timeout)
    while app.state != .notRunning && Date() < deadline {
      Thread.sleep(forTimeInterval: 0.1)
    }
  }
}
