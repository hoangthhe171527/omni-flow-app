# Release test results — Viomni 0.1.6 (30)

| ID | Result | Evidence / observation |
|---|---|---|
| R29-01 | Pass | `flutter analyze`: no issues found |
| R29-02 | Pass | 2,506 tests passed; 2 explicitly skipped manual screenshot suites; 0 failed |
| R29-03 | Pass | Latest app launched on iPhone 17 Simulator; primary tabs and team long-press menu verified without crash |
| R29-04 | Pass | Full suite covered changed inbox, customer, opportunity, team/plan/task, menu, filter and design-system behavior |
| R29-05 | Pass | Bundle/Firebase IDs match; privacy manifest present; production APNs entitlement embedded |
| R29-06 | Pass | App Store archive and IPA exported successfully; IPA size 27 MB |
| R29-07 | Pass | Signed `0.1.6 (30)`; `get-task-allow=false`; profile `Omni App AppStore Local`; signature valid |
| R29-08 | Pass | Transporter accepted and delivered build `0.1.6 (30)` to App Store Connect; Apple processing started at 17:35 on 2026-10-12 |
| R29-09 | Pass | App Store Connect preflight passed: build `0.1.6 (30)` attached; iPhone and 13-inch iPad screenshots, metadata, privacy state, review credentials, contact details and review notes verified. Submission accepted by Apple and status changed to **Waiting for Review** |

## Defects

No open blocker or critical defect recorded.

The only build warning is that two current Flutter plugins do not yet support
Swift Package Manager. This release uses CocoaPods and built successfully, so
the warning is non-blocking for build 30.
