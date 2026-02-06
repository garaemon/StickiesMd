import AppKit
import XCTest

@testable import StickiesMd

final class NSColorHexTests: XCTestCase {
  func testHexInitialization() {
    let red = NSColor(hex: "#FF0000")
    XCTAssertNotNil(red)

    let srgbRed = red?.usingColorSpace(.sRGB)
    XCTAssertEqual(srgbRed?.redComponent ?? 0, 1.0, accuracy: 0.01)
    XCTAssertEqual(srgbRed?.greenComponent ?? 0, 0.0, accuracy: 0.01)
    XCTAssertEqual(srgbRed?.blueComponent ?? 0, 0.0, accuracy: 0.01)

    let blue = NSColor(hex: "0000FF")  // Without hash
    XCTAssertNotNil(blue)
    let srgbBlue = blue?.usingColorSpace(.sRGB)
    XCTAssertEqual(srgbBlue?.blueComponent ?? 0, 1.0, accuracy: 0.01)
  }

  func testToHex() {
    let red = NSColor(srgbRed: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
    XCTAssertEqual(red.toHex(), "#FF0000")

    let green = NSColor(srgbRed: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
    XCTAssertEqual(green.toHex(), "#00FF00")

    let custom = NSColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
    XCTAssertEqual(custom.toHex(), "#808080")

    // Test P3 color conversion (simulated by creating a color that needs conversion)
    // If we create a color in P3, toHex should convert it to sRGB first
    let p3Color = NSColor(colorSpace: .displayP3, components: [1.0, 0.0, 0.0, 1.0], count: 4)
    // In sRGB, P3 Red is slightly different or clipped, but conceptually it should return a hex string.
    XCTAssertNotNil(p3Color.toHex())
  }
}
