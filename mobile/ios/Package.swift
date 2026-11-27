// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "JarvisCore", platforms: [.iOS(.v18), .macOS(.v15)], products: [.library(name: "JarvisCore", targets: ["JarvisCore"])], targets: [.systemLibrary(name: "CSQLite", pkgConfig: "sqlite3", providers: [.apt(["libsqlite3-dev"])]), .target(name: "JarvisCore", dependencies: ["CSQLite"]), .testTarget(name: "JarvisCoreTests", dependencies: ["JarvisCore"])])
