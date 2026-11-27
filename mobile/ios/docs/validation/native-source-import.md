# Native source import — validation

Source: original v0.2.0 archive, SHA-256 151c029a383a8f94e932e6ac542b803bce6968a1915563c413ed6109276eb650.
Local environment Swift 6.2.1 Linux x86_64, no Cargo or Xcode.

Executed:
- swift test --scratch-path /tmp/oj-v022-test: 16 tests, 0 failures (2026-11-27 02:51:25 UTC).
- swiftc -frontend -parse ios/App/*.swift: success; syntax only.
- bash -n scripts/{build-rust-bridge,setup-ios,audit-upstream}.sh: success.
- clang -x c -fsyntax-only bridge/include/OpenJarvisBridge.h: success.

Native Rust compilation, three authored Rust tests, dependency lockfile, Apple targets, XCFramework, SwiftUI SDK compile/link, real inference and device tests are pending.

Original local Git blob hashes (compare to final committed tree):

| Path | SHA |
| --- | --- |
| bridge/Cargo.toml | ebf64ca082f26cb5c8aa0ab647180115e57c9e00 |
| bridge/include/OpenJarvisBridge.h | 8d49aaf9e15025ff1a084b711cbf0716d3cde14e |
| bridge/include/module.modulemap | 939ada13b07d52b265b45ea2cf9314c4f86b04e8 |
| bridge/src/lib.rs | e5eceef39cceb25955b15c40eee60394cea27150 |
| ios/App/NativeBridge.swift | 3508c5eeb2bb83d1f093e0da8f9e76cd42239fb0 |
| ios/App/OpenJarvisApp.swift | d0fa5a958155945639babe16dbda391028945306 |
| ios/project-native.yml | 3fe9bebbd251be81767966f95c7aca2de070b4aa |
| ios/project.yml | d22ec1da23228740b85b550d36fdcaffc5f8baae |
| scripts/build-rust-bridge.sh | 3192f7c079e4847da00ae99d29a8361e49dee2f1 |
| scripts/setup-ios.sh | 000b3976a39d00517df7a711ccf0263aaa0dc32f |
| scripts/audit-upstream.sh | cc3e0bfea873aa55269bccbea2634deff35239cf |
