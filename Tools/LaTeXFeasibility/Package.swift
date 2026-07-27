// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "LaTeXFeasibility",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "latex-feasibility", targets: ["LaTeXFeasibility"])
  ],
  targets: [
    .target(name: "LaTeXFeasibilityCore"),
    .executableTarget(
      name: "LaTeXFeasibility",
      dependencies: ["LaTeXFeasibilityCore"]
    ),
    .testTarget(
      name: "LaTeXFeasibilityCoreTests",
      dependencies: ["LaTeXFeasibilityCore"]
    ),
  ]
)
