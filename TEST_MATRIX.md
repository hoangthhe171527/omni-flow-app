# Test Matrix

## Config
- subagent_profile:
- base_url: https://appstoreconnect.apple.com/apps/6805800851/testflight
- api_url:
- max_parallel_servers: auto

## Roles
| Role | Email | Authentication |
|------|-------|----------------|
| Account Holder / internal tester | tranhoang1112003@gmail.com | Existing signed-in App Store Connect session |
| External tester | levannguyen.aquarius@gmail.com | Invitation email / TestFlight |
| External tester | 1989.vimaru@gmail.com | Invitation email / TestFlight |

## Flows
| ID | Feature | Role | Steps (summary) | Pass criteria | Mode | Last result |
|----|---------|------|-----------------|---------------|------|-------------|
| F1 | iOS artifact integrity | Developer | Inspect project, archive, IPA, signing and embedded assets | Bundle ID/version/build/signing/icons match App Store Connect build 17 | live | PASS — IPA, signing, profile, arm64 slice, icons and metadata verified |
| F2 | Local iOS runtime | Developer | Build and launch Runner on a booted Simulator | Build succeeds and the expected app launches without packaging/runtime blockers | live | PARTIAL — simulator and Release device builds pass; launch not run because no Simulator was booted |
| F3 | App Store Connect upload | Account Holder | Compare Transporter delivery, Build Uploads and TestFlight build status | Upload is Complete and build metadata matches the IPA | live | PASS — build `0.1.0 (17)` delivered and processed under the expected app |
| F4 | Internal tester availability | Account Holder | Inspect build 17, internal group and eligible App Store Connect users | Internal tester group contains build 17 and eligible accepted users can test without Beta App Review | live | PARTIAL — `Omni Internal` has 1 tester and 1 build; tester invitation still needs acceptance |
| F5 | External tester availability | Account Holder | Inspect external group, build review state, tester rows and notification state | Approved build is attached to group; invited testers receive access, otherwise UI clearly identifies the blocking review state | live | BLOCKED BY APPLE — 3 testers and build 17 are attached; build is `Waiting for Review` |

## Cases
| ID | Feature | Who (role/auth) | Precondition / state | Action | Expected outcome | Priority | Flow |
|----|---------|-----------------|----------------------|--------|------------------|----------|------|
| C1 | IPA identity | Developer | Local archive/IPA exists | Inspect Info.plist and project settings | `vn.app.sunriseieco.viomni`, `0.1.0`, build `17` agree everywhere | P0 | F1 |
| C2 | Distribution signing | Developer | Exported IPA exists | Verify code signature, entitlements and embedded provisioning profile | Valid App Store distribution signature/profile with matching application identifier | P0 | F1 |
| C3 | App assets | Developer | Exported IPA exists | Inspect Assets.car and icon declarations | Marketing and device icons are embedded, opaque and correctly declared | P1 | F1 |
| C4 | Local runtime | Developer | iOS Simulator is booted | Build and launch Runner | Build/launch succeeds and expected bundle is installed | P1 | F2 |
| C5 | Upload processing | Account Holder | Build 17 uploaded | Inspect Transporter and Build Uploads | Transporter is Delivered and App Store Connect upload is Complete | P0 | F3 |
| C6 | Build metadata | Account Holder | Build 17 processed | Compare App Store Connect metadata to IPA | Version, build, bundle and platform agree | P0 | F3 |
| C7 | Internal distribution | Account Holder | Build 17 is processed | Inspect internal group and tester eligibility | Accepted App Store Connect user with app access can receive build immediately | P0 | F4 |
| C8 | External first-build review | External tester | Build is Waiting for Review | Inspect tester and group status | `No Builds Available` persists until Beta App Review approves the attached build | P0 | F5 |
| C9 | External post-approval notification | External tester | Build becomes approved | Inspect auto-notify/manual notify and invitation | Tester receives access/email or a manual Notify Testers action is clearly available | P0 | F5 |
| C10 | Device compatibility | External tester | Approved build is available | Compare minimum OS/device family to tester device eligibility | Supported iPhone/iPad on iOS 15+ is eligible; incompatible devices are identified | P1 | F1 |
| C11 | Persistence | Account Holder | Build/group assignments exist | Refresh and revisit group/build pages | Build-group-tester mapping remains unchanged | P1 | F4 |
| C12 | Subsequent build | External tester | First external build has been approved | Upload a later build of the same version | Later build is eligible for Start Testing or a lighter review path | P2 | F5 |

## Known issues / data prerequisites
- The prior TestFlight groups were missing and build 17 showed `Groups (0)`. The mapping was repaired by creating `Omni Internal` (`fe0328bd-7702-4982-a1ab-5ac4604fe7d5`) and `Omni Beta Testers` (`8b08bd87-996c-4564-9fe1-b8b434cef564`), then attaching build 17 and the intended testers. The assignment survived a page reload.
- External build `0.1.0 (17)` is currently `Waiting for Review`; external testers correctly remain `No Builds Available` until Apple approves it.
- Internal tester `tranhoang1112003@gmail.com` is attached to build 17 but remains `Invited` until the TestFlight invitation is accepted.
- Supported tester devices must run iOS 15 or later.
- The archive does not contain an `aps-environment` entitlement. This does not affect TestFlight availability, but remote push notifications will not work until APNs is configured.

## Repeatable scripts
- None.
