# Alpha Academy

Native iOS trainer for the NATO/ICAO phonetic alphabet. SwiftUI, iPhone only,
portrait, deployment target iOS 16.

## Project layout

The Xcode target uses `PBXFileSystemSynchronizedRootGroup`. New `.swift` files and
new subfolders under `newApp/newApp/` are compiled automatically — **never edit
`project.pbxproj` to add files.** The same applies to resources: any `.otf`, `.json`,
or stray file left in that tree ships in the bundle.

Build and verify:

```
xcodebuild -project newApp/newApp.xcodeproj -scheme newApp \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

A DEBUG self-check exercises the whole data pipeline (spaced repetition, the commit
funnel, streaks, achievements, persistence, callsign derivation):

```
SIMCTL_CHILD_AA_SELF_CHECK=1 xcrun simctl launch --console-pty booted j.newApp
```

QA can jump straight to a tab or a training mode:

```
SIMCTL_CHILD_AA_INITIAL_TAB=chart SIMCTL_CHILD_AA_INITIAL_MODE=encode \
  xcrun simctl launch booted j.newApp
```

## Push & attribution

The Pocket Alpha funnel is a **pull** model, spec in `Pocket_Alpha_iOS_Push_API.md`:
the app polls `GET /userapi/user/{user_id}/push/pending`, gets ready-made copy, and
raises a **local** notification. There is no APNs — no device token, no
`registerForRemoteNotifications`, and deliberately no `aps-environment` entitlement.
`UIBackgroundModes` is `fetch` only, purely for `BGAppRefreshTask`.

Layout: `Services/Push/` (`PushAPI`, `PushInbox`, `PushStore`, `LeadIdentity`,
`PushNotificationDelegate`, `PushBackgroundRefresh`) and `Services/Analytics/`
(`AppsFlyerService`, `TrackingAuthorization`, `AnalyticsConfig`).

- Funnel notifications use identifiers prefixed `push.`; the daily drills use
  `drill.0`…`drill.6`. **Never call `removeAllPendingNotificationRequests()`** —
  the two live in the same notification centre, so removal must be scoped.
- Notification permission is requested at the end of onboarding regardless of the
  "Daily reminder" toggle: the toggle governs the drills, but the funnel cannot show
  anything without permission either.
- Paste the AppsFlyer dev key and Apple App ID into `AnalyticsConfig`. While they are
  empty the SDK never starts, so simulator runs stay quiet.

QA overrides (the SDK yields no AppsFlyer UID in the simulator without a dev key):

```
SIMCTL_CHILD_AA_LEAD_ID=<user_id> xcrun simctl launch --console-pty booted j.newApp
```

Background task identifier: `j.newApp.push.refresh` (must stay in sync with
`BGTaskSchedulerPermittedIdentifiers` in Info.plist).

### Open questions (17.08.2026)

1. **BLOCKED: there is no working `user_id` source yet.** The plan was to send
   `AppsFlyerLib.getAppsFlyerUID()`, but prod settles it — the backend parses the path
   segment as an integer:

   ```
   /userapi/user/1/push/pending                 → 200 {"has_push":false,…}
   /userapi/user/1755467891234-5566778/…        → 422 int_parsing
   ```

   The AppsFlyer UID is a hyphenated string, so it can never be accepted. This matches
   §6 of the spec: `user_id` is the *lead* id minted by the backend in the
   `/pocket/auth/register` response, read from the web layer's
   `localStorage["tw-app-user-id"]` or obtained by logging in natively.
   `LeadIdentity.userID` therefore refuses any non-integer id and disables polling
   rather than hammering prod with 422s. Everything downstream is finished and tested
   with `AA_LEAD_ID`; it needs the web layer (or a native login) to go live.
2. **Background fetch is provisional.** Under review; §5 of the spec is candid that
   iOS wakes a rarely-opened app only a few times a day. If dropped, delete
   `Services/Push/PushBackgroundRefresh.swift`, the `.backgroundTask` modifier in
   `newAppApp.swift`, and both `UIBackgroundModes` and
   `BGTaskSchedulerPermittedIdentifiers` from Info.plist. Foreground polling is
   self-sufficient.
3. **`X-App-Session` is never sent** — there is no auth layer to get a token from yet.
   Per §3 prod runs the check in shadow mode, so unauthenticated requests still pass;
   `PushAPI` already sends the header the moment `LeadIdentity.session` is non-nil.
4. **`PrivacyInfo.xcprivacy` is missing** and blocks submission: the app uses
   `UserDefaults` (required reason CA92.1) and AppsFlyer needs `NSPrivacyTracking`
   plus tracking domains. Tracked as separate work.

## Design System

Always read DESIGN.md before making any visual or UI decision.
All font choices, colors, spacing, and aesthetic direction are defined there.
Do not deviate without explicit user approval.
In QA mode, flag any code that doesn't match DESIGN.md.

Three rules from DESIGN.md that are violated most often, so check them explicitly:

- **Exactly one `hot` button per screen.** A second one means the IA is wrong.
- **Exactly one `paper` (light) surface per screen**, reserved for the letter.
- **Every numeral the user reads is IBM Plex Mono with tabular figures.** No exceptions.
