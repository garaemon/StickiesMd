// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "OrgKit",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "OrgKit",
      targets: ["OrgKit"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/ChimeHQ/SwiftTreeSitter", from: "0.8.0"),
    .package(url: "https://github.com/CodeEditApp/CodeEditLanguages", from: "0.1.0"),
  ],
  targets: [
    .target(
      name: "TreeSitterOrg",
      path: "Sources/TreeSitterOrg",
      sources: ["parser.c", "scanner.c"],
      publicHeadersPath: "include",
      cSettings: [
        .headerSearchPath(".")
      ]
    ),
    .target(
      name: "OrgKit",
      dependencies: [
        "TreeSitterOrg",
        .product(name: "SwiftTreeSitter", package: "SwiftTreeSitter"),
        .product(name: "CodeEditLanguages", package: "CodeEditLanguages"),
      ]
    ),
    .testTarget(
      name: "OrgKitTests",
      dependencies: ["OrgKit"]
    ),
  ]
)
