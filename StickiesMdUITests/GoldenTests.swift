import XCTest

@MainActor
final class GoldenTests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  /// Tests the rendering of `sample.md` against a golden image.
  ///
  /// This test uses the CLI screenshot feature to generate an image of `sample.md`
  /// and compares it with the reference image located in `ReferenceImages/sample.png`.
  /// If the test fails, use `scripts/generate-golden.sh` to update the reference image.
  func testSampleMdGolden() throws {
    let app = XCUIApplication()

    // Locate reference directory relative to this source file
    let sourceFileURL = URL(fileURLWithPath: #filePath)
    let referenceImagesDir = sourceFileURL.deletingLastPathComponent().appendingPathComponent(
      "ReferenceImages")
    let sampleMdURL = referenceImagesDir.appendingPathComponent("sample.md")
    let goldenImageURL = referenceImagesDir.appendingPathComponent("sample.png")

    // Provide a temporary output path
    let tempDir = FileManager.default.temporaryDirectory
    let outputImageURL = tempDir.appendingPathComponent("actual_sample.png")
    let tempSampleURL = tempDir.appendingPathComponent("sample.md")

    // Clean previous output
    try? FileManager.default.removeItem(at: outputImageURL)
    try? FileManager.default.removeItem(at: tempSampleURL)

    // Ensure sample.md exists
    XCTAssertTrue(
      FileManager.default.fileExists(atPath: sampleMdURL.path),
      "sample.md not found at \(sampleMdURL.path)")

    // Launch arguments for screenshot generation
    // --reset-state to ensure clean start and isolated store
    app.launchArguments = [
      "--reset-state",
      "--screenshot",
      "--output", outputImageURL.path,
      "--width", "800",
      "--height", "600",
      sampleMdURL.path,
    ]
    app.launch()

    // Wait for the file to be created.
    // The app terminates after saving.
    let exists = checkFileExists(at: outputImageURL, timeout: 10)
    XCTAssertTrue(exists, "Screenshot was not generated at \(outputImageURL.path)")

    // Compare with golden
    if FileManager.default.fileExists(atPath: goldenImageURL.path) {
      let goldenData = try Data(contentsOf: goldenImageURL)
      let outputData = try Data(contentsOf: outputImageURL)

      XCTAssertEqual(
        goldenData, outputData,
        "Screenshot does not match golden image. Output: \(outputImageURL.path)")
    } else {
      // Record mode: Save the generated image as golden if it doesn't exist?
      // Or just fail.
      // For this task, we want to fail so we can manually verify and copy.
      XCTFail(
        "Golden image not found. Generated image at \(outputImageURL.path). Verify and move to \(goldenImageURL.path)."
      )
    }
  }

  private func checkFileExists(at url: URL, timeout: TimeInterval) -> Bool {
    let start = Date()
    while Date().timeIntervalSince(start) < timeout {
      if FileManager.default.fileExists(atPath: url.path) {
        return true
      }
      Thread.sleep(forTimeInterval: 0.1)
    }
    return false
  }
}
