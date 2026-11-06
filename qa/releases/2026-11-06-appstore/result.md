# Release test results — Viomni 0.1.11 (39)

## Verification

| ID | Result | Evidence |
|---|---|---|
| R39-01 | PASS | `flutter analyze`: no issues found |
| R39-02 | PASS | `flutter test`: 2,742 passed, 4 skipped, 0 failed |
| R39-03 | PASS | iPhone 17 Simulator launched `0.1.11 (39)` successfully |
| R39-04 | PASS | Sổ chi phí and notification suites passed in the full run |
| R39-05 | PASS | Bundle, Team, Firebase project, APNs entitlement, privacy manifest and production API references validated |
| R39-06 | PENDING | Signed App Store IPA export |
| R39-07 | PENDING | Signed artifact inspection |
| R39-08 | PENDING | App Store upload and processing |
| R39-09 | PENDING | App Store metadata preflight and submission |

## Current findings

- App Store Connect is signed in with the personal account Hoàng Trần.
- Current distributed version is `0.1.10 (38)`; this release uses the next version/build `0.1.11 (39)`.
- Bundle ID remains `vn.app.sunriseieco.viomni`; Apple Team remains `PN827425A2`.
- No blocker or critical defect is open at preparation time.
- Simulator artifact reports `CFBundleShortVersionString=0.1.11` and `CFBundleVersion=39`.
