# Release test plan — Viomni 0.1.6 (30)

## 0. Round info

- Date: 2026-10-12
- Target: Apple App Store production review
- Build: `0.1.6 (30)`
- Bundle ID: `vn.app.sunriseieco.viomni`
- Source baseline: `317a994` plus the current reviewed local UI/UX changes
- Test basis: `TEST_MATRIX.md`, `docs/app-review.md`

## 1. Go / No-Go targets

| Target | Required |
|---|---:|
| Planned checks executed | 100% |
| P0 checks passed | 100% |
| Open blocker / critical defects | 0 |
| `flutter analyze` | Clean |
| Automated Flutter tests | 100% passed |
| Signed App Store artifact | Valid |

## 2. Strategy

1. Smoke gate: static analysis, unit/widget tests, startup and primary navigation on iOS Simulator.
2. Scoped regression: new flat layouts, anchored menus, team/plan/task actions, customer and inbox filters, avatar/cover updates.
3. Integration: release build configuration, Firebase/APNs resources and production API configuration.
4. System: archive, export and inspect the signed IPA before upload.
5. App Store preflight: build selection, screenshots, privacy, review information and review status.

Any smoke failure or signing/privacy mismatch is a No-Go until repaired and retested.

## 3. Roadmap

| ID | Level | Scenario | Expected |
|---|---|---|---|
| R29-01 | Smoke | Run `flutter analyze` | No issues |
| R29-02 | Smoke | Run all Flutter tests | All pass |
| R29-03 | Smoke | Launch build on iPhone Simulator and navigate primary tabs | No crash/blocker |
| R29-04 | Regression | Run affected UI/UX widget suites | All pass |
| R29-05 | Integration | Validate bundle, privacy manifest, push/Firebase resources | Production values present |
| R29-06 | System | Archive/export App Store IPA | Signed IPA produced |
| R29-07 | System | Inspect IPA signature, entitlements, version and icons | Matches `0.1.6 (30)` |
| R29-08 | External | Upload and process in App Store Connect | Build selectable |
| R29-09 | External | Verify review metadata and submit | No blocking field |

## 4. Discovery log

Results and any release findings are recorded in `result.md`.
