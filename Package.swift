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
    .package(name: "Patron", url: "https://github.com/michaelnisi/patron", from: "11.0.0")
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
