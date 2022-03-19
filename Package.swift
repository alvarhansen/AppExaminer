// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FlipperClientSwift",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "FlipperClientSwift",
            targets: ["FlipperClientSwift"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
         .package(url: "https://github.com/cbaker6/CertificateSigningRequest", from: "1.28.0"),
         .package(url: "https://github.com/robnadin/SocketRocket", .branchItem("spm-support")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "FlipperClientSwift",
            dependencies: []),
        .testTarget(
            name: "FlipperClientSwiftTests",
            dependencies: ["FlipperClientSwift"]),
    ]
)
