import XCTest

@MainActor
final class GoldenTests: XCTestCase {
  override func setUpWithError() throws {
    print("GoldenTests: setUpWithError started")
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
    let bundleURL = Bundle(for: GoldenTests.self).bundleURL
    let appURL =
      bundleURL
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("StickiesMd.app")
      .appendingPathComponent("Contents")
      .appendingPathComponent("MacOS")
      .appendingPathComponent("StickiesMd")

    // Verify app exists
    XCTAssertTrue(
      FileManager.default.fileExists(atPath: appURL.path), "App binary not found at \(appURL.path)")

    let process = Process()
    process.executableURL = appURL
    process.arguments = [
      "--reset-state",
      "--screenshot",
      // Note: We do NOT pass --no-exit, so the app should terminate automatically after saving
      "--output", outputImageURL.path,
      "--width", "800",
      "--height", "600",
      sampleMdURL.path,
    ]

    try process.run()

    // Wait for the file to be created.
    // The app terminates after saving.
    let exists = checkFileExists(at: outputImageURL, timeout: 20)
    XCTAssertTrue(exists, "Screenshot was not generated at \(outputImageURL.path)")

    // Ensure process terminates (it should have by now if it worked)
    process.waitUntilExit()
    XCTAssertEqual(process.terminationStatus, 0, "App exited with non-zero status")

    // Compare with golden
    if FileManager.default.fileExists(atPath: goldenImageURL.path) {
      let match = compareImages(url1: goldenImageURL, url2: outputImageURL, tolerance: 0.10)
      XCTAssertTrue(
        match,
        "Screenshot does not match golden image within tolerance. Output: \(outputImageURL.path)")
    } else {
      // Record mode: Save the generated image as golden if it doesn't exist
      XCTFail(
        "Golden image not found. Generated image at \(outputImageURL.path). Verify and move to \(goldenImageURL.path)."
      )
    }
  }

  private func compareImages(url1: URL, url2: URL, tolerance: Double) -> Bool {
    guard let image1 = NSImage(contentsOf: url1),
      let image2 = NSImage(contentsOf: url2)
    else {
      print("Failed to load images")
      return false
    }

    var rect = CGRect(x: 0, y: 0, width: image1.size.width, height: image1.size.height)
    guard let cgImage1 = image1.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
      print("Failed to get CGImage for image1")
      return false
    }

    rect = CGRect(x: 0, y: 0, width: image2.size.width, height: image2.size.height)
    guard let cgImage2 = image2.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
      print("Failed to get CGImage for image2")
      return false
    }

    guard cgImage1.width == cgImage2.width, cgImage1.height == cgImage2.height else {
      print(
        "Dimensions mismatch: \(cgImage1.width)x\(cgImage1.height) vs \(cgImage2.width)x\(cgImage2.height)"
      )
      return false
    }

    guard let data1 = cgImage1.dataProvider?.data,
      let data2 = cgImage2.dataProvider?.data
    else {
      print("Failed to get data provider")
      return false
    }

    let length1 = CFDataGetLength(data1)
    let length2 = CFDataGetLength(data2)
    guard length1 == length2 else {
      print("Data length mismatch: \(length1) vs \(length2)")
      return false
    }

    guard let ptr1 = CFDataGetBytePtr(data1),
      let ptr2 = CFDataGetBytePtr(data2)
    else {
      print("Failed to get byte pointers")
      return false
    }

    var diffCount = 0
    for i in 0..<length1 {
      if ptr1[i] != ptr2[i] {
        diffCount += 1
      }
    }

    let diffRatio = Double(diffCount) / Double(length1)
    print("GoldenTests: Image difference ratio: \(diffRatio)")

    if diffRatio > tolerance {
      print("GoldenTests: FAILED - Difference ratio \(diffRatio) exceeds tolerance \(tolerance)")
      print("GoldenTests: Image 1 size: \(image1.size)")
      print("GoldenTests: Image 2 size: \(image2.size)")
      print("GoldenTests: Data length 1: \(length1)")
      print("GoldenTests: Data length 2: \(length2)")
    } else {
      print("GoldenTests: PASSED - Difference ratio \(diffRatio) within tolerance \(tolerance)")
    }

    return diffRatio <= tolerance
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
