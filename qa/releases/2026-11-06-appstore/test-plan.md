# Release test plan — Viomni 0.1.11 (39)

## 0. Round info

- Date: 2026-11-06
- Target: Apple App Store production review
- Build: `0.1.11 (39)`
- Bundle ID: `vn.app.sunriseieco.viomni`
- Source baseline: App Store version `0.1.10 (38)` through `87adb31`, plus the Sổ chi phí header and search refinements
- Apple account: Hoàng Trần / Team `PN827425A2`

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
2. Scoped regression: Sổ chi phí header, search, ledger calculations and notification behavior already present in the source baseline.
3. Integration: production API, Firebase, APNs, bundle and privacy resources.
4. System: archive, export and inspect the signed IPA.
5. App Store preflight: version/build, screenshots, privacy, review account, metadata and release notes.

Any smoke failure, runtime startup error, signing/privacy mismatch or incomplete App Store field is a No-Go until repaired and retested.

## 3. Roadmap

| ID | Level | Scenario | Expected |
|---|---|---|---|
| R39-01 | Smoke | Run `flutter analyze` | No issues |
| R39-02 | Smoke | Run all Flutter tests | All pass |
| R39-03 | Smoke | Launch `0.1.11 (39)` on iPhone 17 Simulator | No startup error or blocker |
| R39-04 | Regression | Run Sổ chi phí and notification suites | All pass |
| R39-05 | Integration | Validate bundle, privacy manifest, Firebase/APNs and production URLs | Production values present |
| R39-06 | System | Archive/export App Store IPA | Signed IPA produced |
| R39-07 | System | Inspect signature, entitlements, version, icon and embedded resources | Matches `0.1.11 (39)` |
| R39-08 | External | Upload and wait for App Store processing | Build selectable |
| R39-09 | External | Verify metadata, screenshots, privacy and submit | No blocking field |

## 4. Discovery log

Results and release findings are recorded in `result.md`.
