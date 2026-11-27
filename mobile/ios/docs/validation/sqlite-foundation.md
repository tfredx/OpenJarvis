# SQLite local validation

Command: swift test. Linux x86_64, Swift 6.2.1, system SQLite 3.46.1. Earlier v0.2 portable fixture (16 existing tests) plus exact new package/module/store and tests. Executed 23 tests, with 0 failures; SQLiteSessionStoreTests executed 7, with 0 failures. No full integrated or Apple runtime tests executed locally.

Tested Git blobs:
- Package.swift 40f460a016f0db88e35db01e178d13c9c3dece2c
- module.modulemap 0a291b5e206495789da0b517a1e500707eabac9d
- shim.h f52e1f09e6bbfc8a3cb0c03c6f4624b77a664277
- SQLiteSessionStore.swift 5735d45d74e9cdd57a3f1cc2525067635f33ca88
- SQLiteSessionStoreTests.swift c2242842e53e9a93e1a4f66b78a24989e42b77ba

Rollback test uses a synthetic trigger to reject second insert, verifies archive absent, then removes trigger and successfully imports. No personal data. Full integrated CI and on-device SQLite validation are outstanding.
