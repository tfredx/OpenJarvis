# Shadow migration validation

Local command: swift test in earlier v0.2 portable fixture plus validated SQLite foundation and the exact two new rehearsal files. Linux x86_64, Swift 6.2.1, system SQLite 3.46.1. 28 tests executed, 0 failures; SQLiteShadowMigrationTests 5/5 passed. SHA verification: SQLiteShadowMigration.swift 401805aa38f1967e07249f208b8e73c67a88de82; SQLiteShadowMigrationTests.swift 831e12de15c56645e8ef0cf12bcdd0268eb76be4.

Cases executed: close/reopen parity and selective staging cleanup; source drift; invalid archive; source read failure before/after copy; missing scratch directory. Tests use synthetic data only. Linux run does not include iOS file protection or the merged coordinator/repository. Three new integration tests and one new hosted test plus extended busy test are CI-only pending. No device result.

Previous baseline: PR #17 run 45938278085, 65 tests passed, native archives published. New expected count 74, not yet confirmed.
