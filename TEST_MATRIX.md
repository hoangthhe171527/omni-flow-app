# Test Matrix

## Config

- subagent_profile:
- base_url: https://appstoreconnect.apple.com/apps/6805800851/testflight
- api_url: https://app.sunriseieco.vn
- max_parallel_servers: auto
- target_release: `0.1.0 (19)`

## Roles

| Role | Email | Authentication |
|------|-------|----------------|
| Account Holder / internal tester | tranhoang1112003@gmail.com | Existing signed-in Apple/Firebase sessions |
| External tester | levannguyen.aquarius@gmail.com | Invitation email / TestFlight |
| External tester | 1989.vimaru@gmail.com | Invitation email / TestFlight |

## Flows

| ID | Feature | Role | Steps (summary) | Pass criteria | Mode | Last result |
|----|---------|------|-----------------|---------------|------|-------------|
| F1 | Push backend isolation and delivery | Developer | Run focused API tests for registration, tenant isolation, Android/APNs payloads, retry and invalid-token handling | All tests pass; no cross-tenant token selection; transient errors retry without deleting valid tokens | automated | PASS — focused suites 17 tests / 78 assertions |
| F2 | Mobile push lifecycle | Developer | Run Flutter tests for Android/iOS initialization, APNs wait, token refresh, foreground/tap handling and logout cleanup | Analyze and all tests pass; unregister runs before credentials are cleared | automated | PASS — `flutter analyze` clean; 80/80 tests pass |
| F3 | Android release artifact | Developer | Build signed release with production Firebase config and inspect merged manifest/resources | Package is `vn.app.sunriseieco.viomni`; Firebase app matches; notification channel/sound/permission are present | live | PASS — AAB/APK built; package `vn.app.sunriseieco.viomni`, version `0.1.0 (18)`, POST_NOTIFICATIONS and FCM receiver present |
| F4 | iOS archive integrity | Developer | Archive/export build 18 and inspect signature, entitlements, embedded profile, plist and icons | Bundle/version/build match; `aps-environment=production`; Firebase plist is bundled; icons are valid | live | PASS — archive/export succeeded; bundle `vn.app.sunriseieco.viomni`, `0.1.0 (18)`, signed APNs production, Firebase plist and icon resources present |
| F5 | Production backend readiness | Developer | Deploy API branch; inspect worker queue/config/logs and registered token count | Mongo queue worker is healthy; FCM HTTP v1 config loads; no Redis NOAUTH; no credentials in logs | live | PASS — backend merged/deployed; API and Mongo worker healthy; JWT/FCM materialized without fatal startup or Redis auth errors |
| F6 | TestFlight upload and processing | Account Holder | Upload build 18; inspect Build Uploads and TestFlight processing | Upload is Complete and build `0.1.0 (18)` is selectable | live | PASS — Transporter delivered; App Store Connect upload status Complete and build 18 is selectable |
| F7 | Internal tester availability | Account Holder | Attach build 18 to internal group and inspect tester eligibility | Accepted internal tester can install without Beta App Review | live | PASS — `Omni Internal` contains build 18 with status Testing |
| F8 | External tester availability | Account Holder | Attach build 18 to external group, submit beta review if required and inspect tester rows | Approved build is available and testers are notified; blocker is explicitly shown otherwise | live | PASS — build 18 submitted with automatic notification and now shows Testing in `Omni Beta Testers`; pending users remain Invited rather than No Builds Available |
| F9 | Physical-device message push | Tester | Login on one iPhone and one Android device, allow notifications, background app, receive a new inbox message, tap alert | One timely alert per message; correct conversation opens; token remains registered after resume; logout removes token | live | BLOCKED — requires build 18 installed on physical devices |
| F10 | App Review metadata | Account Holder | Select build 19, replace iPhone/iPad screenshots, complete privacy, age rating and review information | All screenshots are final Simulator captures with fictional data; build 19 and demo credentials are selected | live | PENDING |
| F11 | App Review privacy controls | Developer | Verify legal links, account deletion, Photos purpose strings and privacy manifest | Privacy/Support work before login and in More; deletion requires password and schedules removal; plist/manifest are valid | automated/live | PASS — mobile analyze and 83 tests pass; API flow 13 assertions pass |

## Cases

| ID | Feature | Who (role/auth) | Precondition / state | Action | Expected outcome | Priority | Flow |
|----|---------|-----------------|----------------------|--------|------------------|----------|------|
| C1 | Tenant isolation | Developer | Tenant scope enforcement disabled in test | Execute `SendInboxPush` with tokens in two tenants | Only tokens whose explicit `tenant_id` matches the job are sent | P0 | F1 |
| C2 | Android payload | Developer | Android token exists | Build/send FCM payload | Android package, high priority, channel and custom sound are correct | P0 | F1 |
| C3 | APNs payload | Developer | iOS token exists | Build/send FCM payload | APNs topic, alert/sound and deterministic collapse ID are correct | P0 | F1 |
| C4 | Credential mismatch | Developer | FCM returns `SENDER_ID_MISMATCH` | Execute sender/job | Delivery fails and retries; token is not deleted | P0 | F1 |
| C5 | Invalid token | Developer | FCM returns an explicit unregistered/invalid-token response | Execute sender/job | Only that invalid token is soft-deleted | P1 | F1 |
| C6 | Token registration | Authenticated mobile user | Valid tenant session and Firebase token | Start app / refresh token | API receives platform-specific token for the active tenant/user | P0 | F2 |
| C7 | iOS APNs readiness | Authenticated iPhone user | Notification permission allowed | Start push runtime | App waits for APNs token before requesting FCM token and registers successfully | P0 | F2 |
| C8 | Foreground notification | Authenticated user | App is foregrounded | Receive inbox push | One local alert appears where needed; iOS does not duplicate a remote notification alert | P1 | F2 |
| C9 | Notification tap | Authenticated user | Valid `conversation_id` in payload | Tap OS/local notification from foreground/background/terminated state | App opens the matching inbox thread after session/router are ready | P0 | F2 |
| C10 | Logout cleanup order | Authenticated user | Token is registered | Logout normally and with unregister network failure | DELETE runs while auth/tenant exist; logout still completes if DELETE fails | P0 | F2 |
| C11 | Android identity/config | Developer | Production JSON is present | Build and inspect release artifact | Firebase client and application ID both equal `vn.app.sunriseieco.viomni` | P0 | F3 |
| C12 | Android notification capability | Developer | Release artifact exists | Inspect merged manifest/resources | Android 13 permission, FCM service metadata, channel and `omni_message_alert` exist | P0 | F3 |
| C13 | iOS identity/signing | Developer | Archive exists | Inspect app/profile/code-signature entitlements | App identifier matches and production `aps-environment` is embedded | P0 | F4 |
| C14 | iOS Firebase config | Developer | Archive exists | Inspect Runner.app resources | `GoogleService-Info.plist` exists and its bundle/project IDs match production | P0 | F4 |
| C15 | Production worker | Developer | API deployment complete | Restart/inspect worker and logs | Worker uses Mongo queue; new job class loads; no Redis auth loop or secret leakage | P0 | F5 |
| C16 | Build metadata | Account Holder | Build 18 uploaded | Compare IPA and App Store Connect metadata | Version `0.1.0`, build `18`, bundle and platform agree | P0 | F6 |
| C17 | Internal distribution | Account Holder | Build 18 processed | Add build to internal group | Eligible accepted internal user sees build without Beta App Review | P0 | F7 |
| C18 | External review/notification | Account Holder | Build 18 processed | Attach to external group and submit/notify | UI shows approval/testing state; approved testers receive access/email | P0 | F8 |
| C19 | iPhone delivery | External tester | Build 18 installed; permission allowed; logged in | Background app and receive customer message | One audible alert arrives and tap opens correct thread | P0 | F9 |
| C20 | Android delivery | External tester | Build 18 installed; permission allowed; logged in | Background app and receive customer message | One audible alert arrives and tap opens correct thread | P0 | F9 |
| C21 | Logout revocation | External tester | Device completed C19/C20 | Logout, then send another customer message | Logged-out device receives no further alert | P0 | F9 |
| C22 | iPhone App Store screenshots | Reviewer demo user | Build 19 and fictional demo workspace | Capture Inbox, thread, customer, pipeline and opportunity at 1320×2868 | Every image shows the actual app in use; no login, prompt, mockup or real customer data | P0 | F10 |
| C23 | iPad App Store screenshots | Reviewer demo user | Build 19 and fictional demo workspace | Capture the same core flows at 2064×2752 | Every image shows the actual iPad app in use without stretching errors or overlays | P0 | F10 |
| C24 | Legal links | Signed-out and signed-in user | Public website available | Open Privacy and Support from login and More | Correct HTTPS pages open and include current contact/deletion information | P0 | F11 |
| C25 | Account deletion | Authenticated owner | Current password known | Confirm deletion from More → Account | API returns 202; account, sessions and push delivery are disabled immediately; scheduled date is within 7 days | P0 | F11 |
| C26 | App Store-only channels | iOS user with channel write permission | Open connection sheet | Inspect available channels | Only official OAuth/API channels are offered; personal cookie/agent pairing is absent | P0 | F11 |

## Known issues / data prerequisites

- Build 17 has no `aps-environment` entitlement and cannot be used. App Review must use build 19 after the metadata/privacy fixes.
- External TestFlight builds may require Beta App Review; internal App Store Connect testers do not require that review after processing.
- Production currently has zero registered device tokens. C19–C21 require an actual iPhone and Android installation, login, and notification permission.
- The Firebase Android/iOS app records match `vn.app.sunriseieco.viomni`; the APNs authentication key is configured for both development and production.
- The local Android release uses the debug signing certificate fallback. It is suitable for artifact/push verification but must not be uploaded to Google Play until a production Android keystore is configured.
- A single tenant/user currently retains one token per platform. Testing two devices on the same platform for the same user is outside this release scope.
- Final App Store screenshots require a dedicated `Apple Review Demo` workspace containing only fictional data.

## Repeatable scripts

- API: focused PHPUnit suites under `tests/Feature/Notification` and `tests/Unit/Notification`.
- Mobile: `flutter analyze` and `flutter test`.
- Native artifacts: Gradle release build, Xcode archive/export, then `codesign`, `security cms`, `plutil`, and archive inspection.
