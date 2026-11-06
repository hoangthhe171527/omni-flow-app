# Release test results — Viomni 0.1.11 (40)

## Verification

| ID | Result | Evidence |
|---|---|---|
| R40-01 | PASS | `flutter analyze`: no issues found |
| R40-02 | PASS | Full `flutter test`: 2,743 passed, 4 skipped, 0 failed |
| R40-03 | PASS | Finance tests: 17 passed; menu/router regression: 41 passed |
| R40-04 | PASS | Automated policy coverage proves Admin access and rejects non-Admin fallback permissions for both menu and routes |
| R40-05 | PENDING | Production bundle/Firebase/privacy/APNs preflight |
| R40-06 | PENDING | Signed App Store IPA export |
| R40-07 | PENDING | Signed artifact inspection |
| R40-08 | PENDING | App Store upload and processing |
| R40-09 | PENDING | App Store submission |

## Current findings

- Backend role presets grant `finance.expenses` only to Admin; the mobile policy now follows that source of truth.
- Non-Admin permissions such as orders, membership, dashboard and the unsupported `.read` suffix no longer reveal finance UI.
- Menu visibility and route access use the same requirement, so a deep link cannot bypass the hidden navigation.
- Build 40 replaces build 39; marketing version remains `0.1.11` because that version has not been approved yet.
