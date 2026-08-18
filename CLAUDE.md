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
- The AppsFlyer dev key and Apple App ID are filled in in `AnalyticsConfig`, so the
  SDK now starts on every run, simulator included. Blank either constant to put it
  back to sleep — `isConfigured` gates the whole service.

QA overrides (the lead id is still not derivable at runtime — see open question 1):

```
SIMCTL_CHILD_AA_LEAD_ID=<user_id> xcrun simctl launch --console-pty booted j.newApp
```

Background task identifier: `j.newApp.push.refresh` (must stay in sync with
`BGTaskSchedulerPermittedIdentifiers` in Info.plist).

### Open questions (17.08.2026)

1. **`user_id` now comes from the web layer — but only in web mode.**
   `Services/Web/WebLeadBridge.swift` lifts `localStorage["tw-app-user-id"]` out of the
   page and `LeadIdentity.rawUserID` prefers it, so the funnel finally has an id the
   backend accepts. Verified end to end against prod with a seeded page: the bridge
   captured the id, `reconcile()` ran, and the id survives into launches that never
   reach the web view.

   The AppsFlyer UID stays as the tail of `rawUserID` only so `reconcile()` has
   something to compare before the bridge fires — it can never be accepted, because
   the backend parses the path segment as an integer (re-verified 18.08.2026):

   ```
   /userapi/user/1/push/pending                 → 200 {"has_push":false,"reason":"telegram_lead"}
   /userapi/user/1755467891234-5566778/…        → 422 int_parsing
   ```

   **Still open:** a native-mode install has no web layer and therefore no `user_id`,
   so it gets no funnel pushes at all. Closing that needs a native login (§6) against
   `POST /userapi/pocket/auth/{register,login}` — see the path correction below.

   **Spec correction.** §3 and §6 give the auth path as `/pocket/auth/register`; that
   is `405` on prod. The API is mounted under `/userapi`, so the real paths are
   `/userapi/pocket/auth/{register,login,google}`. They want `email` + `password`
   (password 6–128). There is no anonymous way to mint an id: `/lead/register` answers
   `{success, bot_url}`, not a `user_id`.
2. **Background fetch is provisional.** Under review; §5 of the spec is candid that
   iOS wakes a rarely-opened app only a few times a day. If dropped, delete
   `Services/Push/PushBackgroundRefresh.swift`, the `.backgroundTask` modifier in
   `newAppApp.swift`, and both `UIBackgroundModes` and
   `BGTaskSchedulerPermittedIdentifiers` from Info.plist. Foreground polling is
   self-sufficient.
3. **`X-App-Session` is never sent** — the token comes from the same auth response as
   `user_id`, and the bridge only recovers the id. Per §3 prod runs the check in shadow
   mode: re-verified 18.08.2026 that a deliberately bogus token still answers `200`.
   `PushAPI` sends the header the moment `LeadIdentity.session` is non-nil. To wire it,
   check the `WEB lead: localStorage keys […]` line the bridge prints on every load —
   it lists what the page actually stores, so the session key does not have to be
   guessed.
4. **`PrivacyInfo.xcprivacy` is missing** and blocks submission: the app uses
   `UserDefaults` (required reason CA92.1) and AppsFlyer needs `NSPrivacyTracking`
   plus tracking domains. Tracked as separate work.

## Web mode

A start-up gate decides, once per install, whether the app runs as this native
trainer or as a remote page. Layout: `Services/Web/` (`WebConfig`, `WebModeStore`,
`WebGate`) and `Features/Web/` (`WebShellView`, `WebRetryView`).

Order on a first launch, all inside `RootView`'s single sequencing `.task`:
DEBUG hooks → splash hold → `TrackingAuthorization.requestIfNeeded()` → `WebGate.decide()`.
The ATT prompt is answered before the probe by construction, not by timing: the
request `await`s the system alert, and the gate is the next statement. It is
skipped entirely when `TrackingAuthorization.isResolved` is false — that only
happens on a launch that never became `.active`, and the one-shot decision must
not be spent on a launch nobody saw.

Once decided, `AppRouter.init()` reads `WebModeStore` and sets `.web` **before the
first frame**: a returning learner pays no splash, no ATT, no network.

- **Paste the destination into `WebConfig.destination`.** While it is empty the
  gate answers native and the app behaves exactly as it did before web mode.
- The destination may be requested **at most twice for the lifetime of the
  install** (`WebConfig.maxHubRequests`): once to decide, once to rebuild a stale
  address from `pathid`. `WebModeStore.mayRequestHub` is checked before every
  request; do not add a third call site.
- A positive answer is `200...403`. A redirect chain that lands back on the
  destination is not positive; an address that simply answers in place is.
- **Anything else is native forever, including a transport failure** — a first
  launch with no network settles on the native trainer permanently. That is a
  deliberate product decision, not an oversight.
- Once web mode is active it never falls back to native. A failed page retries
  once via `pathid`, then shows `WebRetryView`.

QA overrides:

```
SIMCTL_CHILD_AA_WEB_URL=<https url>   replaces the destination (release too)
SIMCTL_CHILD_AA_WEB_RESET=1           clears the decision at launch   (DEBUG)
SIMCTL_CHILD_AA_WEB_FORCE=web         skip the probe, commit web      (DEBUG)
SIMCTL_CHILD_AA_WEB_FORCE=native      skip the probe, commit native   (DEBUG)
```

UserDefaults keys: `com.alphaacademy.web.{decision,destination,pathID,hubRequests,lastHubAt,leadUserID,didAskPush}`.

`WebLeadBridge` is installed on the shell's content controller: a
**`.atDocumentStart`** user script reads `localStorage["tw-app-user-id"]`, then
re-checks once a second for two minutes, because the id is minted by the page's
own registration call rather than being there on load. Document *start* is not a
detail: the real destination is a single-page app that holds its document open,
so `.atDocumentEnd` scripts never run on it at all. It reports on the first run regardless, so the
`WEB lead: localStorage keys […]` line shows up even for a page that has not
registered. The content controller holds only a weak proxy to the receiver —
holding it strongly leaks the entire web content process.

**The load is judged at `didCommit`, never at `didFinish`.** The real
destination commits in under a second and never finishes — it keeps fetching for
as long as it is open — so a watchdog on `didFinish` reported a perfectly healthy
page as broken and dropped every launch onto `WebRetryView`. A commit means the
server answered and the document is parsing; that is the only sane definition of
"the page is alive" for a single-page app.

The shell also requests notification permission once, on the first successful
load, flagged by `didAskPush`. `onPageReady` normally fires on `didFinish`, with
a 12-second fallback from commit for the same reason. Native onboarding is where the app normally asks
and it never runs in web mode, so without this `PushInbox` refuses to poll and
the declared `UIBackgroundModes: fetch` is inert for those installs.

DEBUG console, all prefixed so `--console-pty` output stays greppable — and all
compiled out of release, since a funnel response body is not something to leave
in a shipping log:

- `WEB store ── state at launch` — decision, saved address, `pathid`, requests
  spent, and the configured destination. Printed from `applyQAOverrides()` in
  `newAppApp.init()`, before anything acts on it.
- `WEB gate ── response` — requested and final URL, whether a redirect happened,
  status, every response header, and the body (truncated at 4000 characters).
  Dumped before classification, so a destination that goes native still shows why.
- `WEB gate:` — the verdict line.
- `WEB store:` — every write: decision committed, saved address updated.
- `WEB route:` — the branch actually taken this launch: `WEB (decided now)`,
  `WEB (decided earlier)`, or `NATIVE → main|onboarding`.
- `WEB nav:` — the navigation trace: `loading`, `started`, `main-frame status`,
  `committed`, `finished`, `failed`, `watchdog fired`. This is what to read first
  when the page does not appear.
- `WEB lead:` — the localStorage key list on every load, and the captured id.

### Deliberate deviations from the `check-app` audit

Both are direct requirements from the product owner. Do not "fix" them.

1. **Portrait everywhere, including web.** The audit expects `.all` in web mode
   via an AppDelegate. This app has no AppDelegate and stays portrait-locked;
   `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad` was deleted so no string
   in the project mentions landscape. (The audit's related rule — the WebView must
   not reload on rotation — holds anyway: `updateUIView` is gated on the last
   *requested* URL, never on `view.url`.)
2. **No safe area in the web shell.** `WebShellView` applies a bare
   `.ignoresSafeArea()`, so the page owns the strips behind the status bar and
   home indicator. Consequences already handled: `contentInsetAdjustmentBehavior`
   is `.never` (WebKit would otherwise inset a second time), the argument-less
   form also covers `.keyboard` (SwiftUI's avoidance compounds with WKWebView's
   and pushes a focused field off screen), and `.preferredColorScheme` is left
   nil in the web phase so a light page does not get a white-on-white status bar.

Also unlike the audit's template: no `NSAllowsArbitraryLoads`. ATS stays at its
strict defaults, so **the destination must be HTTPS across the whole redirect
chain** — a plain-`http` hop anywhere fails with `-1022` and silently commits the
install to native.

### Not done yet

- AppsFlyer attribution params in the URL (`sub1`/`sub2`/conversion data). Would
  need an `AppsFlyerLibDelegate`, which does not exist in this project.
- A `user_id` for native-mode installs. The bridge only fires in web mode, so a
  learner who never reaches the page still gets no funnel pushes — see open
  question 1.

## Design System

Always read DESIGN.md before making any visual or UI decision.
All font choices, colors, spacing, and aesthetic direction are defined there.
Do not deviate without explicit user approval.
In QA mode, flag any code that doesn't match DESIGN.md.

Three rules from DESIGN.md that are violated most often, so check them explicitly:

- **Exactly one `hot` button per screen.** A second one means the IA is wrong.
- **Exactly one `paper` (light) surface per screen**, reserved for the letter.
- **Every numeral the user reads is IBM Plex Mono with tabular figures.** No exceptions.
