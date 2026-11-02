# Release test results — Viomni 0.1.8 (33)

## Automated gates

| ID | Result | Evidence |
|---|---|---|
| R33-01 | PASS | `flutter analyze`: no issues found |
| R33-02 | PASS | `flutter test`: 2,690 passed, 2 skipped, 0 failed |
| R33-03 | PASS | iPhone 17 Simulator launched successfully; no `Zone mismatch` or startup exception |
| R33-04 | PASS | Startup, Timeline/KPI, notification, finance, customer, task and inbox suites passed in the full run |
| R33-05 | PASS | Bundle `vn.app.sunriseieco.viomni`; Firebase bundle matches; APNs entitlement, privacy manifest and production resources present |
| R33-06 | PENDING | Signed App Store IPA export |
| R33-07 | PENDING | Signed artifact inspection |
| R33-08 | PENDING | App Store upload and processing |
| R33-09 | PENDING | App Store metadata preflight and submission |

## Defects found and closed

- Fixed Flutter startup initialization so bindings, Firebase/FCM, Crashlytics and `runApp` use the same guarded zone.
- Fixed the Timeline KPI comparison row overflowing on narrow iPhone content widths; the comparison chip now moves to a second row without shrinking text.
- Synchronized the in-app version label with `pubspec.yaml` at `0.1.8`.

## Simulator artifact

- Device: iPhone 17, iOS 26.5 simulator
- Version/build: `0.1.8 (33)`
- App launched into the authenticated dashboard with production configuration.
