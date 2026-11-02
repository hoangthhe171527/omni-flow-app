# Release test plan — Viomni 0.1.8 (33)

## 0. Round info

- Date: 2026-11-02
- Target: Apple App Store production review
- Build: `0.1.8 (33)`
- Bundle ID: `vn.app.sunriseieco.viomni`
- Source baseline: approved `0.1.7 (32)` through `2b07fbf`, plus the guarded-zone startup repair
- Test basis: existing Flutter suites, prior App Store release round, Apple review history

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

1. Smoke gate: static analysis, full Flutter tests, startup and primary navigation on iOS Simulator.
2. Scoped regression: notification bell filtering, finance directory/permissions, customer activity data, drag-and-drop and iOS interaction changes since build 32.
3. Integration: production API/Firebase/APNs resources and release configuration.
4. System: archive, export and inspect the signed IPA.
5. App Store preflight: version/build selection, screenshots, privacy, review account, metadata and release notes.

Any smoke failure, runtime startup error, signing/privacy mismatch or incomplete App Store field is a No-Go until repaired and retested.

## 3. Roadmap

| ID | Level | Scenario | Expected |
|---|---|---|---|
| R33-01 | Smoke | Run `flutter analyze` | No issues |
| R33-02 | Smoke | Run all Flutter tests | All pass |
| R33-03 | Smoke | Launch `0.1.8 (33)` on iPhone 17 Simulator | No startup error or blocker |
| R33-04 | Regression | Run changed notification, finance, customer, startup and task UI suites | All pass |
| R33-05 | Integration | Validate bundle, privacy manifest, Firebase/APNs and production URLs | Production values present |
| R33-06 | System | Archive/export App Store IPA | Signed IPA produced |
| R33-07 | System | Inspect signature, entitlements, version, icon and embedded resources | Matches `0.1.8 (33)` |
| R33-08 | External | Upload and wait for App Store processing | Build selectable |
| R33-09 | External | Verify metadata, screenshots, privacy and submit | No blocking field |

## 4. Discovery log

Results and release findings are recorded in `result.md`.
