// swift-tools-version:5.3

import PackageDescription

let package = Package(
  name: "FanboyKit",
  platforms: [
    .iOS(.v13), .macOS(.v10_15)
  ],
  products: [
    .library(
      name: "FanboyKit",
      targets: ["FanboyKit"]),
  ],
  dependencies: [
    .package(name: "Patron", url: "/Users/michael/swift/patron", .branch("pkg"))
  ],
  targets: [
    .target(
      name: "FanboyKit",
      dependencies: ["Patron"]
    ),
    .testTarget(
      name: "FanboyKitTests",
      dependencies: ["FanboyKit"]),
  ]
)
