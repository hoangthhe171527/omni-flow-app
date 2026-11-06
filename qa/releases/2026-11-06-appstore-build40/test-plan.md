# Release test plan — Viomni 0.1.11 (40)

## 0. Round info

- Date: 2026-11-06
- Target: Apple App Store production review
- Build: `0.1.11 (40)`
- Bundle ID: `vn.app.sunriseieco.viomni`
- Change scope: hide Sổ chi phí and Tổng hợp chi phí from every non-Admin mobile role; enforce the same permission on deep links
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

1. Smoke gate: static analysis and the full Flutter test suite.
2. Scoped regression: Admin sees both finance entries; non-Admin roles see neither; routes and menus share one access requirement.
3. Integration: validate production API, Firebase, APNs, bundle and privacy resources.
4. System: archive, export and inspect the signed IPA.
5. App Store preflight: replace build 39 with build 40, then verify metadata, screenshots, privacy and review fields before resubmission.

Any smoke failure, access-control regression, signing/privacy mismatch or incomplete App Store field is a No-Go until repaired and retested.

## 3. Roadmap

| ID | Level | Scenario | Expected |
|---|---|---|---|
| R40-01 | Smoke | Run `flutter analyze` | No issues |
| R40-02 | Smoke | Run all Flutter tests | All pass |
| R40-03 | Regression | Run finance, menu and router suites | All pass |
| R40-04 | Security | Open finance menu/routes with Admin and non-Admin policies | Admin allowed; non-Admin denied |
| R40-05 | Integration | Validate bundle, privacy manifest, Firebase/APNs and production URLs | Production values present |
| R40-06 | System | Archive/export App Store IPA | Signed IPA produced |
| R40-07 | System | Inspect signature, entitlements, version, icon and embedded resources | Matches `0.1.11 (40)` |
| R40-08 | External | Upload and wait for App Store processing | Build selectable |
| R40-09 | External | Replace build 39 and submit build 40 | Status `Waiting for Review` |

## 4. Discovery log

Results and release findings are recorded in `result.md`.
