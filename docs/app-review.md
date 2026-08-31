# App Review runbook — Viomni 0.1.0 (19)

## Reviewer account

- Use a dedicated, non-expiring account in the `Apple Review Demo` workspace.
- Disable two-factor authentication for this account.
- Give it access to Inbox, Customers, Opportunities, Channels and Account settings.
- Seed only fictional names, phone numbers, conversations, attachments and sales opportunities.
- Keep the production API and seeded channels available for the full review period.
- Put the username and password in App Store Connect's dedicated Sign-In Information fields, not in Review Notes.

## Suggested review path

1. Sign in and open the single preselected workspace.
2. Open Inbox and select a seeded conversation.
3. Review the fictional message history and customer context.
4. Open Customers and Opportunities.
5. Open More → Legal & Support to verify Privacy Policy and Support.
6. Open More → Account to verify the account deletion entry point. Do not complete deletion unless testing that flow intentionally.

## Screenshot set

Capture directly from the final build on Simulator with the same fictional demo account. Do not use the files in `design/screens/`; those are product mockups rather than captures of the app in use.

Use five portrait screenshots for each device family:

1. Omnichannel Inbox
2. Conversation thread
3. Customer detail
4. Opportunities pipeline
5. Opportunity detail or connected official channels

Required capture sizes:

- iPhone 6.9-inch: `1320 × 2868` from iPhone 17 Pro Max Simulator.
- iPad 13-inch: `2064 × 2752` from iPad Pro 13-inch Simulator.

Do not submit login, splash, notification-permission prompts, promotional mockups or any screen containing real customer data.

## Review Notes

```text
Viomni is a B2B CRM and omnichannel inbox application for business teams.

Sign-in is required. A non-expiring demo username and password are provided in the dedicated App Review Sign-In Information fields. The account belongs to one workspace named “Apple Review Demo”, has no two-factor authentication, and contains only fictional customers, conversations and sales opportunities.

Suggested review path:
1. Sign in.
2. Open Inbox and select a seeded conversation.
3. Open Customers and Opportunities.
4. Open More → Legal & Support.

No purchase, subscription, external payment or in-app purchase is offered in the iOS app. Viomni is a standalone companion for an enterprise service. Push notification permission is optional and declining it does not block app functionality.

The iOS connection flow exposes only official OAuth/API integrations. No personal social-network credentials, QR code, external computer or additional hardware are required to review the core app.

Privacy Policy: More → Legal & Support → Privacy Policy
Support: More → Legal & Support → Support
Account deletion: More → Account → Delete Account
```

## App Store Connect preflight

- Select build `0.1.0 (19)`, never rejected build 17.
- Replace both the iPhone and iPad screenshot sets with the final Simulator captures.
- App name: `Viomni - Nền tảng số`; display name below the icon: `Viomni`.
- App Privacy must match `PrivacyInfo.xcprivacy`, including Name, Email Address, Phone Number, Physical Address, User ID, Device ID, Emails or Text Messages, Customer Support, Other User Content, and Photos or Videos.
- Age Rating: answer Messaging and Chat and User-Generated Content accurately; do not leave the questionnaire at a default 4+ result without reviewing those capabilities.
- Sign-in required: enabled, with working demo username/password.
- App Review contact phone: `+84 845 880 643`.
- Privacy URL: `https://omni.app.sunriseieco.vn/privacy`.
- Support URL: `https://omni.app.sunriseieco.vn/support`.
