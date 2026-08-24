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
SIMCTL_CHILD_AA_SELF_CHECK=1 xcrun simctl launch --console-pty booted com.rainerhansen.globoton
```

QA can jump straight to a tab or a training mode:

```
SIMCTL_CHILD_AA_INITIAL_TAB=chart SIMCTL_CHILD_AA_INITIAL_MODE=encode \
  xcrun simctl launch booted com.rainerhansen.globoton
```

## Push & attribution

Pushes are sent **by the server through APNs**. The contract is the client's
`Пуши в iOS-прилу.md` (22.08.2026). The app used to poll `/push/pending` and
raise a *local* notification instead; that superseded spec is kept for reference
at `docs/superseded/Pocket_Alpha_iOS_Push_API.md` and no longer describes this
app in any respect.

Three layers have to agree and none of them knows the whole picture on its own:
the native side knows the APNs token, the bundle id, the locale and the
AppsFlyer id but not who the lead is; the web layer knows the lead but none of
that; the server joins them by **`device_id`**.

`device_id` is the bridge. The app mints it itself, once, and stores it in the
**Keychain** — `UserDefaults` is wiped on delete, and a reinstalled learner
would arrive as a new device with the lead link dropped and the install
attribution lost.

```
launch
  ├─ native →  POST /userapi/device/register {device_id, bundle_id, …}
  ├─ native →  registerForRemoteNotifications() → POST again with {apns_token, apns_env}
  └─ native →  window.__native.device_id = … injected into the page
                   → the page reports it with the lead's identity
                   → the server marks the device owned
```

Layout: `Services/Push/` (`DeviceIdentity`, `APNSEnvironment`, `PushConfig`,
`DeviceRegistrar`, `DeviceRegistrationStore`, `PushClickReporter`, `PushRoute`,
`PushNotificationDelegate`, `LegacyFunnelCleanup`, `DebugPushProbe`),
`Services/Security/Keychain.swift`, `AppDelegate.swift`, and
`Services/Analytics/` (`AppsFlyerService`, `TrackingAuthorization`,
`AnalyticsConfig`).

- API host is `https://signals.tradingwithtyler.com` (`PushConfig`), **not**
  `WebConfig.destination` — that is a keitaro cloaking address for a *page*.
- `registerForRemoteNotifications()` is called unconditionally in
  `didFinishLaunchingWithOptions`, on every launch. It does **not** need
  notification permission — permission governs whether an arriving alert is
  displayed. Gating it on the prompt would be much worse than it sounds: in web
  mode that prompt fires 4–34s after launch and only once per install, and in
  native mode only at the end of onboarding.
- **`apns_env` is the most dangerous field in the integration.** It is read from
  the built binary's `embedded.mobileprovision`, never hardcoded and never from
  `#if DEBUG` (a Release build signed with a development profile is sandbox).
  Get it wrong and every sandbox build fails with `BadDeviceToken` while the app
  shows no error at all. Never use `appStoreReceiptURL`'s `sandboxReceipt` as an
  input — a normal TestFlight build has that receipt *and* a production gateway.
- The APNs token is lowercase hex with no separators.
  `String(describing: deviceToken)` yields `"<a1b2c3d4 …>"` and is silently
  discarded; `DebugSelfCheck` asserts on the encoding for this reason.
- A remote push is told from a local `drill.*` reminder by
  `trigger is UNPushNotificationTrigger`, never by identifier — a remote push's
  identifier is whatever `apns-collapse-id` the server chose.
  **Never call `removeAllPendingNotificationRequests()`**: `drill.0`…`drill.6`
  share the notification centre.
- A tapped push routes through `PushRoute` into the **live** web view. Assigning
  `AppRouter.phase = .web(pushURL)` does nothing — `WebShellView` seeds its
  `@State` only on first materialisation — and `.id(url)` would rebuild the
  WKWebView, costing the 5–30s cold boot described under Web mode. A native
  install has no shell, so it gets `PushWebSheet` and reports the click itself.
- Notification permission is still requested at the end of onboarding regardless
  of the "Daily reminder" toggle: the toggle governs the drills, but an APNs
  alert cannot be displayed without permission either.
- There is **no** `UIBackgroundModes` and no `BGTaskScheduler`. `remote-notification`
  is deliberately absent — the server sends alert pushes, not silent ones, and
  declaring an unused background mode invites review questions.

QA overrides:

```
SIMCTL_CHILD_AA_PUSH_PROBE=1   dump the whole integration state at launch
SIMCTL_CHILD_AA_PUSH_PROBE=2   …and perform a live registration round trip
SIMCTL_CHILD_AA_DEVICE_RESET=1 clear the Keychain entry, forcing a mint  (DEBUG)
SIMCTL_CHILD_AA_PUSH_BASE_URL=<https url>  replace the API host (release too)
```

Acceptance, with the admin key:

```
GET  /userapi/admin/devices?device_id=<id>
POST /userapi/admin/devices/<id>/test-push
```

`has_apns_token` — not the 200 — is the answer to "is my integration working".
`linked` flips to true once the page has reported `window.__native.device_id`
alongside the lead — confirmed against prod on 24.08.2026, with the page
storing the id under `localStorage["tw-native-device-id"]`.

### Open questions (24.08.2026)

1. **The APNs auth key is not on the backend yet.** Everything else is
   verifiable without it — registration, token, `apns_env`, the device→lead
   link — but nothing is delivered until they hold a `.p8` plus its Key ID and
   Team ID, scoped to team `6WBSBWSNWN` and bundle `com.rainerhansen.globoton`.
   A key for a different bundle id answers `DeviceTokenNotForTopic`, which from
   the client is indistinguishable from "nothing happened".
2. **Push Notifications capability.** Enabling it on the App ID needs App
   Manager or Admin rights on the team. The entitlement file already says
   `aps-environment: development`; Xcode rewrites it to `production` when
   signing with a distribution profile.
3. **`locale` format is unconfirmed.** We send BCP-47 (`es-MX`); the spec's
   examples are ambiguous between that and the POSIX form.
4. **`X-App-Key` has not been issued.** `PushConfig.appKey` is nil and the
   header is omitted. It may start being enforced without warning.
5. **`PrivacyInfo.xcprivacy` is missing** and blocks submission: the app uses
   `UserDefaults` (required reason CA92.1), now also the Keychain, and AppsFlyer
   needs `NSPrivacyTracking` plus tracking domains. Tracked as separate work.

## Web mode

A start-up gate decides, once per install, whether the app runs as this native
trainer or as a remote page. Layout: `Services/Web/` (`WebConfig`, `WebModeStore`,
`WebGate`, `WebHostPolicy`, `WebWindowPolicy`, `WebNativeBridge`, `WebLeadBridge`) and
`Features/Web/` (`WebShellView`, `WebRetryView`, `PushWebSheet`).

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
SIMCTL_CHILD_AA_WEB_HOSTS=a.com,b.com  extra first-party hosts (release too)
```

The client's link probe lives at
`https://signals.tradingwithtyler.com/linktest.html`. Point the shell at it with
`AA_WEB_URL` and tap all four: "Клик по ссылке" and "window.open в жесте" must
say **ушли из приложения**; the other two staying inside is the popup blocker
working as intended, not a bug. It also prints "Нативная обёртка: да" when
`window.__native.device_id` arrived.

UserDefaults keys: `com.alphaacademy.web.{decision,destination,pathID,hubRequests,lastHubAt,leadUserID,didAskPush,hostPolicyMigrated}`
and `com.alphaacademy.device.{idMirror,lastRegisterAt,lastRegisterOKAt,lastSentToken,lastSentEnv,lastLinked,lastHasAPNsToken,pendingToken,didPurgeLegacyNotifications}`.
The `device_id` itself is in the Keychain, not here.

### External links leave the app

Third-party pages — the Pocket cashier, its registration — are handed to the
system browser rather than opened inside the shell. They are laid out for a
normal browser, and this shell has no address bar, no back button and no safe
area, so a foreign header slides under the notch.

`WebHostPolicy` decides what "ours" means, and the list is deliberately **not** a
compile-time constant: `WebConfig.destination` is a keitaro cloaking address, so
the funnel's real host is the end of a redirect chain and is unknown until the
app has followed it. The list is the anchor `signals.tradingwithtyler.com`, the
configured destination's host, the saved destination's host, and `AA_WEB_HOSTS`.
Subdomains match, the apex `tradingwithtyler.com` does not.

- **`createWebViewWith` is the load-bearing half.** `target="_blank"` is how the
  front end opens the cashier, and WKWebView creates no window on its own — with
  no `WKUIDelegate` the learner taps "Deposit" and *nothing happens at all*.
  All four cases on the client's `linktest.html` go through this method, not
  through a main-frame link. `WebWindowPolicy` handles the three shapes such a
  request takes; each one fails as "nothing happens" if it is missed, which is
  indistinguishable from having no delegate at all:
  a `window.open` inside the tap, one **after** awaiting the server, and
  `window.open('', '_blank')` with the address assigned later.
- **`javaScriptCanOpenWindowsAutomatically` is deliberately `true`.** Its
  default of `false` is what made "Deposit" do nothing: the front end opens the
  cashier after a server round trip, by which point the tap's gesture is spent
  and WebKit discards the call without ever asking the UI delegate — no
  callback, no log line, no symptom beyond silence. Turning it on does not let
  the page open windows; it lets the request *reach* us. What keeps an ad from
  abusing it is `sourceFrame.isMainFrame` in `WebWindowPolicy`, not the blocker.
- Real Safari (`UIApplication.shared.open`), not `SFSafariViewController`: the
  latter has its own storage, so a lead already signed in to Pocket in Safari
  arrives at the cashier logged out.
- Sub-frames never bounce (`targetFrame.isMainFrame`) — an ad, a captcha or a
  payment iframe is third-party by host and entirely legitimate. A cross-origin
  **POST** never bounces either: rebuilding it as a URL drops the body.
- **The cashier is not on `pocketoption.com`.** Observed 24.08.2026, Deposit
  opens `https://go1.urlpress.co/cabinet/deposit-step-1?token=…`, and that host
  rotates. This is why the policy is an allowlist of what is ours rather than a
  denylist of Pocket's domains — the latter would have missed this entirely.
- A third-party `.other` navigation is kept inside **while a load of ours is
  still resolving** (`isResolvingLoad`). That is the cloaking chain, and it is
  the only way an install finds the funnel again after it moves domain; bouncing
  it would send the shell to Safari on every launch and leave `WebRetryView`
  behind, permanently. The allowlist then *learns* the host it landed on
  (`adoptChainDestination`) — the same trust `WebGate.decide()` already extends.
- **`noteAddress()` is host-guarded.** Before this, it saved *any* main-frame URL
  as `WebModeStore.destination`, so a learner who tapped "Deposit" made the app
  relaunch into the Pocket cashier before the first frame, forever.
  `migrateHostPolicyIfNeeded()` repairs those installs once, on the first launch
  after this shipped, by re-deriving the address from the configured seed.

`WebNativeBridge` injects `window.__native = { device_id, platform }` at
**`.atDocumentStart`**, main frame only, and calls `window.twSetNativeDeviceId`
once the page defines it (idempotency is a marker on `window`, never a Swift
flag — `window` is per-document, so a real navigation legitimately gets its own
call). Main-frame-only is a privacy decision: `window.__native` inside a
third-party iframe hands the device id to an ad network. There is deliberately
no message handler — `evaluateJavaScript`'s completion (`already` / `absent` /
`called` / `threw`) is a better acknowledgement than a message would be.

`WebLeadBridge` is installed on the shell's content controller: a
**`.atDocumentStart`** user script reads `localStorage["tw-app-user-id"]`, then
re-checks once a second for two minutes and then every five seconds for as long
as the page is open. It never stops on purpose: per Ruslan (18.08.2026) the id is
minted the moment the lead registers on Pocket, which can be at any point in a
session — and a single-page app never reloads, so a bounded window would not get
a second chance until the next cold start. Document *start* is not a
detail: the real destination is a single-page app that holds its document open,
so `.atDocumentEnd` scripts never run on it at all. It reports on the first run regardless, so the
`WEB lead: localStorage keys […]` line shows up even for a page that has not
registered. The content controller holds only a weak proxy to the receiver —
holding it strongly leaks the entire web content process.

Pushes no longer need that id — the backend links device to lead by `device_id`
— so its only remaining consumer is `AppsFlyerService.setCustomerUserID`, which
ties the install to the lead and is otherwise never set on this platform.

**The load is judged at `didCommit`, never at `didFinish`.** The real
destination commits in a couple of seconds but can take another twenty to boot,
so a 7-second watchdog on `didFinish` reported a perfectly healthy page as
broken and dropped every cold launch onto `WebRetryView`. A commit means the
server answered and the document is parsing; that is the only sane definition of
"the page is alive" for a single-page app.

**After the commit the load is judged on movement, not on time**
(`WebConfig.stallWatchdog`, 25s). `estimatedProgress` is observed; every tick
pushes the deadline out, `didFinish` and progress `1.0` cancel it. A stall means
the page committed and then stopped receiving bytes — the site's own splash
stays on screen with nothing ever arriving behind it, and the commit watchdog is
long spent by then. Progress going quiet is necessary but not sufficient: a page
that finished parsing and holds a socket open looks identical from outside, so
the verdict is only reached after `document.readyState` confirms it is still
loading. A stall goes straight to `WebRetryView` — the address is fine, the
bytes stopped, so spending the one `pathid` rescue on it would waste it.

Cold-start timings measured against prod (20.08.2026): commit ~2s, `didFinish`
5–30s depending on how the origin feels. The spread is the origin's, not the
app's — `signals.tradingwithtyler.com` is a bare nginx with no CDN serving
`/assets/index-*.js` at 1.17 MB **uncompressed** (`vary: Accept-Encoding` is set
but no `content-encoding` comes back) at 70–130 KB/s. gzip would take it to
330 KB. Warm launches are ~2s: the assets are `immutable, max-age=2592000` and
WebKit caches them, so only the very first launch is slow.

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
  `committed`, `finished`, `failed`, `watchdog fired`, `stalled at <progress>`.
  This is what to read first when the page does not appear. A trace that reaches
  `committed` and stops there for tens of seconds is the origin being slow, not
  the app being stuck.
- `WEB lead:` — the localStorage key list on every load, and the captured id.
- `WEB bridge:` — whether `window.twSetNativeDeviceId` took the device id:
  `called`, `already`, or `absent` (a page that never defines the hook — which
  includes `linktest.html`, so `absent` there is a pass, not a failure).

And the push side, on the same principle:

- `PUSH device:` — the Keychain: `minted`, `keychain hit`, `keychain restored
  from mirror`, or `keychain unreadable (…) — deferring, NOT minting`. The
  second line is the one that proves a reinstall kept its identity.
- `PUSH env:` — `aps-environment` as read from the built binary, the resolved
  `apns_env`, and where it came from. Read this first on any `BadDeviceToken`.
- `PUSH reg:` — every `/device/register` call: `ok linked=… has_apns_token=…`,
  `throttled`, the retry ladder, or `rejected … — contract bug`.
- `PUSH apns:` — the token, its length, its gateway, and `[CHANGED]` when it
  differs from the last one sent. A token that changes every launch is usually a
  provisioning mismatch.
- `PUSH tap:` — the `pid`, `post_id` and `url` of a tapped push.

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
- The four buttons on `linktest.html` have not been tapped one by one, though
  the real thing has: on 24.08.2026 the funnel's own Deposit button bounced to
  Safari and the backend answered `linked=true`, which is the whole chain.
- `apns_env` has only been observed as `sandbox` from a simulator. The
  `profile:development` and `profile:production` branches are untested until
  someone builds to a device and to TestFlight.

## Design System

Always read DESIGN.md before making any visual or UI decision.
All font choices, colors, spacing, and aesthetic direction are defined there.
Do not deviate without explicit user approval.
In QA mode, flag any code that doesn't match DESIGN.md.

Three rules from DESIGN.md that are violated most often, so check them explicitly:

- **Exactly one `hot` button per screen.** A second one means the IA is wrong.
- **Exactly one `paper` (light) surface per screen**, reserved for the letter.
- **Every numeral the user reads is IBM Plex Mono with tabular figures.** No exceptions.
