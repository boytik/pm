# Design System — Alpha Academy

> Source of truth for every visual decision in this app.
> Derived from a supplied reference screenshot (dark fintech instrument panel),
> extracted pixel-for-pixel, then mapped onto Alpha Academy's real screens.

## Product Context

- **What this is:** An iOS trainer for the NATO/ICAO phonetic alphabet. Teaches the
  practical skill of spelling information aloud — booking codes, passport series,
  emails, tracking numbers — so the other end never has to ask twice.
- **Who it's for:** People who dictate codes over the phone. Pilots, dispatchers,
  support staff, logistics, and ordinary people improvising "M as in Mike".
- **Space/industry:** iOS Education / Reference. A crowded category — at least eight
  direct competitors ship a NATO alphabet trainer today.
- **Project type:** Native iOS app (SwiftUI, iPhone only, portrait, deployment target 16).
- **The memorable thing:** *A serious instrument, not a game.* Every decision below
  serves that one impression. When a choice is ambiguous, pick the one that reads as
  equipment.

### Competitive findings that shaped this system

Researched August 2026 by visiting App Store listings directly.

- **Weak-spot tracking and flight-number practice are already shipped** by *NATO Alphabet
  Learning*. **Multi-alphabet (NATO + LAPD) is already shipped** by *Phonetic Trainer*.
  Neither is a differentiator.
- **The category is uniformly blue or green flat vector** — compasses, aircraft, or a
  letter "A". Icon and palette convergence is near-total.
- **Privacy is a visible competitive axis.** The two apps badged *Data Not Collected*
  sit at 5.0 stars. The one declaring Purchases / Location / Identifiers / Usage Data
  sits at 2.6.
- **Naming collision:** the developer of *Learn NATO Phonetic Alphabet* ships a family
  called Maritime Academy, Braille Academy, Sky Academy, Art Academy, Elements Academy.
  "Alpha Academy" reads as one of theirs. Flagged, not resolved here.
- **Nobody designs for the moment of use.** Every competitor is a study screen you read
  sitting down. The real moment is mid-phone-call, one-handed, needing a word in half a
  second. That reframes the reference chart from a cheat sheet into a primary surface.

## Aesthetic Direction

- **Direction:** Industrial / instrument panel. Deep navy field, elevated cards, a single
  hot action, semantic colour reserved for numbers.
- **Decoration level:** Minimal. Depth comes from tone separation, never from shadow.
- **Mood:** Reading a well-made instrument. Dense but calm. Nothing decorative, nothing
  celebratory, nothing that pressures.
- **Reference:** supplied screenshot of a dark trading/signals app (see Decisions Log).

### Four devices deliberately NOT carried over from the reference

The reference is a conversion-driven product. These four exist to push a payment, not to
help anyone learn, and in a free educational utility they are the exact 4.3 "spam design"
pattern that sank earlier submissions of this concept.

1. **Countdown clock on the home screen.** Would count down to nothing. The timer survives
   only in Speed Mode, where it *is* the exercise.
2. **Lime-to-pink gradient chips.** Pure decoration carrying no information.
3. **Gradient + outer glow on the hot button.** Slot-machine grammar. Flat fill instead.
4. **"Lv.1 / Not activated" lock badges.** Gating chrome for a paywall that does not exist.
   Rank still shows, as information rather than as a lock.

Also corrected: the reference uses two near-identical greens (hue 140 and hue 162) for one
job, and three different ambers. This system defines exactly one value per role.

## Color

**Approach:** restrained. Colour is information. A screen with no state to report is
navy, ink, and one orange button.

### Surfaces — depth by tone, never by shadow

| Token | Hex | Use |
|---|---|---|
| `bg` | `#11162C` | Page field. Everything sits on this. |
| `surface` | `#1C2137` | Standard card. Lighter than the field. |
| `surfaceDeep` | `#061944` | Session surfaces (encode, decode). Deeper and bluer, not darker. |
| `surfaceDeepAlt` | `#14264E` | Rows nested inside a deep card. |
| `tabBar` | `#0D1021` | Floating bar. The darkest thing on screen. |
| `chipNeutral` | `#282D41` | Neutral chips and badges. |
| `paper` | `#B6CCFB` | **The one light surface.** Letter cards only. |

### Accents

| Token | Hex | Use |
|---|---|---|
| `hot` | `#D26A05` | Flat fill, no gradient, no glow. **Exactly one per screen.** |
| `hotPressed` | `#B35309` | Pressed state for `hot`. |
| `blue` | `#2459F5` | All other interactivity. Mastery fill. |
| `blueBright` | `#448DFF` | Active tab item, combo multiplier. |
| `glow` | `#1B3A71` | Radial glow under the centre tab item. Nowhere else. |

### Semantic — one value per role

| Token | Hex | Use |
|---|---|---|
| `positive` | `#77D2B4` | Correct answers, accuracy, gains. |
| `negative` | `#F0616B` | Wrong answers. Never for anything else. |
| `amber` | `#EFC26A` | Due for review, weak letters. Text and icons. |
| `amberFill` | `#FFE047` | Timer chip fill only. Dark text on top. |
| `track` | `#2B3350` | Empty half of every meter, tile, and progress bar. |

### Text

| Token | Hex | Use |
|---|---|---|
| `ink` | `#F2F5FF` | Primary text on dark. |
| `ink2` | `#8B90AB` | Secondary text, inactive tab labels. |
| `ink3` | `#6A6F85` | Tracked uppercase micro-labels. |
| `onPaper` | `#0B1220` | Text on the light plate, including the letter glyph. |
| `onPaper2` | `#3C4A6B` | Pronunciation key and mnemonic on the light plate. |

**Dark mode:** This system *is* the dark mode. There is no light variant. `AccentColor`
in the asset catalog is `#2459F5` for both appearances so system chrome matches.

**Contrast:** `ink` on `bg` is well above 4.5:1. `ink3` at 10px is decorative label text
only and never carries information a user must read; the value beneath it always does.

## Typography

Three families, three jobs. Never more.

- **Display / the letter:** **Instrument Serif** (OFL, bundled, 62 KB) — used *only* on
  the light plate, in mastery tiles, and in the Chart table's symbol column. This is what
  makes the card read as a printed specimen instead of a UI panel, and it is the one
  element a competitor cannot copy without rebuilding their whole app.
- **Interface and headings:** **SF Pro** (system). Screen titles, card headings, body copy
  and controls all sit on the system face so Dynamic Type behaves natively.
- **Numbers:** **IBM Plex Mono** (OFL, bundled, Regular 129 KB + SemiBold 133 KB) with
  tabular figures. Every numeral the user reads: timer, score, combo multiplier, XP,
  percentages, counts. Also carries the pronunciation key (`BRAH-VOH`) and the encode
  target string (`BK7291`).
- **Never used:** SF Mono (reads as Xcode), any rounded face (reads as a toy), Inter,
  Poppins, Montserrat, Space Grotesk.

**Bundling:** drop `.ttf` files anywhere under `newApp/newApp/` — the target uses
`PBXFileSystemSynchronizedRootGroup`, so they are added as resources automatically.

> **`UIAppFonts` must list bare filenames, not paths.** The synchronized group copies
> resources **flat** into the bundle root regardless of the folder they live in on disk.
> A path like `Resources/Fonts/X.ttf` fails silently: the font never registers, and every
> `.custom()` call falls back to the system face with no warning and no log line. The
> DEBUG self-check asserts registration for exactly this reason.

Total bundled type: **324 KB**. Attribution for both OFL faces belongs in Settings → About.

### Scale

| Role | Font | Size | Weight | Treatment |
|---|---|---|---|---|
| Letter glyph (hero) | Instrument Serif | 120 | regular | On `paper`, capped at 150, drops to 64 at accessibility sizes. **Constrain the frame to `size × 0.86`** — the face carries a generous line box and the plate otherwise grows to twice the glyph height |
| Letter glyph (quiz prompt) | Instrument Serif | 104 | regular | Same frame constraint |
| Letter glyph (tile / chart) | Instrument Serif | 21 / 24 | regular | |
| Screen title | SF Pro | 26 | semibold | `-0.3` tracking |
| Card heading | SF Pro | 17 | semibold | |
| Code word | SF Pro | 19 | semibold | Uppercase, `+3` tracking |
| Body | SF Pro | 15–17 | regular | |
| Big numeral | IBM Plex Mono | 34 | semibold | `-1` tracking, tabular |
| Stat value | IBM Plex Mono | 15 | semibold | Tabular |
| Score readout | IBM Plex Mono | 22 | semibold | Tabular |
| Timer | IBM Plex Mono | 15 | semibold | On the `amberFill` chip |
| Pronunciation key | IBM Plex Mono | 13 | regular | `+1.5` tracking |
| Micro-label | SF Pro | 10 | semibold | Uppercase, `+1.3` tracking, `ink3` |
| Caption | SF Pro | 12 | regular | `ink2` / `ink3` |

> **Integer interpolation inserts grouping separators.** `Text("\(xp) XP")` runs the Int
> through a number formatter and renders `2340` as `2 340`, which breaks monospaced
> alignment. Use `Text(verbatim:)` for any numeral in a mono readout.

## Spacing

- **Base unit:** 4
- **Density:** comfortable
- **Scale:** 4 · 8 · 12 · 16 · 24 · 32
- **Screen gutter:** 16
- **Card padding:** 16
- **Rhythm between blocks:** 14
- **Rhythm between sections:** 24

## Layout

- **Approach:** grid-disciplined, single column. Answer options occupy a fixed block at
  the bottom of the screen and never move between questions — a shifting target costs
  thumb accuracy under time pressure.
- **Border radius:** cards 20 · buttons 14 · tab bar 28 · mastery tile 9 · chips full pill
- **Max content width:** full width minus gutters (iPhone only)
- **Orientation:** portrait locked

### Structural rules

- **One hot action per screen.** A second `hot` button means the screen has two primary
  actions and the information architecture is wrong. Fix the IA, not the colour.
- **One light surface per screen,** reserved for the letter. It is the loudest thing on
  screen by construction, which is correct — the letter is the product.
- **Zero shadows anywhere.** A card is lighter or bluer than its field, never floated.
- **Micro-labels sit above their value, never beside it.**
- **Every numeral the user reads is monospaced with tabular figures.** No exceptions —
  a ticking timer or a rising score must never shift the layout.
- **Tab bar floats:** inset 12 from each edge, 74 tall, radius 28. The centre item
  (Practice) carries a radial `glow` and is the primary action.
- **Sessions are `fullScreenCover` and hide the tab bar.** Only browsing surfaces
  (Home, Learn, Practice, Progress, Chart) show it.

## Motion

- **Approach:** minimal-functional. If an animation communicates state, keep it. If it
  celebrates, cut it.
- **Easing:** enter `ease-out` · exit `ease-in` · move `ease-in-out`
- **Durations:** answer state change 180ms · wrong-answer shake 240ms at 6pt amplitude ·
  mastery fill 450ms · phase crossfade 250ms
- **Haptics:** light impact on correct, error notification on wrong, success notification
  exactly once per session and nowhere else.
- **Banned:** confetti, particles, spring overshoot below 0.8 damping, scale pops above
  1.06, sound effects of any kind, screen-edge glow, "COMBO!" bursts, coin counters,
  3D card flips.
- **Reduce Motion:** shake becomes a 150ms crossfade, mastery fill becomes instant,
  summary stagger becomes a single fade.

## Settings

Built from the design system, **not** from `Form`. The stock inset-grouped list carries
its own greys, separators and corner radii; `.scrollContentBackground(.hidden)` hides the
backdrop but the rows still read as a different app. Components live in
`DesignSystem/Components/SettingsComponents.swift`: `SettingsGroup`, `SettingsRow`,
`RowDivider`, `RowValue`, `SettingsToggleRow`, `SettingsSegmentedRow`.

Rules: rows are 52 pt minimum; leading icons are `blue` and 22 pt wide; dividers inset
past the icon; a destructive row tints its label *and* its icon `negative`; segmented
choices are accent-filled pills, never the system's grey capsule.

## Avatar

Three forms, one circle: **initials** (derived from the callsign, in Instrument Serif, so
even the default is on-theme), a **curated icon** from an aviation/radio set, or a
**photo**.

- Tints are constrained to five palette values (`AvatarTint`). A free colour picker would
  let the user paint themselves outside the system.
- The photo is a JPEG on disk at ≤512 px, never base64 inside the state JSON — image data
  there would multiply the file and force a full rewrite on every debounced save.
- Photo selection uses `PhotosPicker`, which runs out of process and grants the app no
  library access. **This adds no permission prompt and no `NSPhotoLibraryUsageDescription`.**
  In this category the apps badged *Data Not Collected* are the ones rated 5.0 — keep it
  that way.

## Print — the shared record

The exported PDF is the **light counterpart** of the app, not a screenshot of it. In this
system `paper` is the printed artefact, so the record is the plate at full-page size. A
dark PDF would also be miserable to print.

Print-only palette (`PrintTheme`, the only colours outside the on-screen system):
page `#F3F6FC` · plate `#B6CCFB` · ink `#0B1220` · ink2 `#3C4A6B` · ink3 `#8592B0` ·
rule `#C7D3E8` · accent `#1F49C4` · track `#D9E1F2`.

A4 at 72 dpi (595 × 842). Structure: masthead with the serif A plate, identity block with
avatar and callsign, five mono stat cells, the mastery grid at 13 columns (26 letters land
as exactly two rows, digits as a third), per-mode accuracy bars, the full alphabet
reference in three columns, and a footer carrying the ICAO citation.

The reference strip is not filler. The real moment of use is mid-phone-call, so a printed
record you can pin to a monitor is worth more than white space.

> **Do not flip the context when rendering.** `ImageRenderer`'s render callback already
> applies the top-left-origin transform. Adding the usual CoreGraphics bottom-up flip
> cancels it and the whole page comes out mirrored.

## Accessibility

- The 120pt glyph uses a capped `ScaledMetric` and drops to 64pt at accessibility sizes —
  counter-intuitive but correct, since at those sizes the *words* need the room.
- Answer grids switch from two columns to one at accessibility sizes.
- Correct and wrong always carry a glyph (`checkmark` / `xmark`) alongside the colour.
  The sage/brick pair is ambiguous for roughly 8% of male users.
- The Speed Mode timer is `accessibilityHidden` — a ticking value must not re-announce.
- Decode by Ear always offers "Show the sequence", or the mode is unusable for deaf and
  hard-of-hearing learners.

## App Icon

Not yet produced. Blocker for submission — a blank icon is an automatic reject.

**Concept:** the light plate on the dark field, reduced to its essentials. A serif
**A** in `onPaper` on a `paper` rectangle, sitting on a `bg` navy ground. It is the app's
hero element at icon scale, and in a category of blue and green compasses and aircraft it
is the only light-on-dark typographic mark.

Requires three 1024×1024 PNGs (light, dark, tinted-grayscale), sRGB, no alpha, no baked
corner radius.

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-08-17 | Adopted dark instrument system from supplied reference | User supplied a reference screenshot and asked for a system derived from it. Replaces an earlier warm-paper light theme already implemented in `Theme.swift`. |
| 2026-08-17 | Memorable thing = "a serious instrument, not a game" | User choice. Every subsequent decision is judged against it. |
| 2026-08-17 | Kept reference structure and palette; dropped four conversion-pressure devices | Countdown, gradient chips, glowing gradient CTA, and lock badges are the 4.3 surface. Everything else in the reference is craft with no risk. |
| 2026-08-17 | Hot button flattened to `#D26A05`, no gradient, no glow | The gradient-plus-glow combination is the slot-machine tell. The "one hot action" hierarchy is good IA and stays. |
| 2026-08-17 | Instrument Serif for the letter glyph | The light plate already breaks the reference's all-sans rule by existing. A serif makes it a printed specimen rather than a card component, and it is the only element in this category that could be recognised as ours. |
| 2026-08-17 | Unified two greens into `positive`, three ambers into `amber` + `amberFill` | The reference uses hue 140 and hue 162 for the same job. Copying that defect would cost us in six months. |
| 2026-08-17 | `paper` kept at reference periwinkle `#B6CCFB` | Faithful to the supplied reference. A warm-paper variant (`#EDE8DC`) was considered and deferred; revisit after seeing the plate on real hardware. |
| 2026-08-17 | Implemented in code | `Theme.swift` and `Typography.swift` rewritten, three faces bundled, floating tab bar with a glowing centre item replaces `TabView` chrome, letter plate and quiz prompt moved onto `paper`. Verified on an iPhone 17 Pro simulator. |
| 2026-08-17 | Dropped General Sans; headings use SF Pro | A third bundled family for screen titles and card headings only, at ~200 KB, buys almost nothing over SF Pro semibold at those sizes. The differentiator is the serif glyph, not the headings. |
| 2026-08-17 | Custom `FloatingTabBar` instead of `TabView` | The reference's floating pill with a radial glow under the centre item cannot be expressed through `UITabBarAppearance`, and the system bar fights the dark field. Cost: tab screens must add `Theme.tabBarClearance` bottom padding themselves. |
| 2026-08-17 | Settings rebuilt from the design system | The stock `Form` carries its own greys, separators and radii; hiding the backdrop is not enough to make it belong. |
| 2026-08-17 | Avatar added: initials, curated icon, or photo | Personalisation without an account. Tints constrained to the palette; photo via `PhotosPicker`, which adds no permission prompt. |
| 2026-08-17 | Shared record is a light PDF, not a dark one | `paper` is the printed artefact in this system, and a dark A4 is miserable to print. Print-only palette documented above. |
| 2026-08-17 | Record carries the full alphabet reference | Fills the page with the thing the user actually needs mid-call, instead of white space. |
| 2026-08-17 | App Store ID left nil until the listing exists | Share falls back to the description with no link. Shipping a dead URL to everyone the user invites is worse than shipping no URL. |
| 2026-08-17 | Chart stays the fifth tab | Research suggests promoting it to first would match the real moment of use (mid-call, one-handed). Not adopted in this pass — it is a product IA change, not a design system change. Open. |

## Open Items

- **App icon** — release blocker, needs a designer.
- **AppsFlyer SDK is linked and unused**, alongside an unused push entitlement and
  `remote-notification` background mode. In a category where *Data Not Collected* correlates
  with 5.0 ratings and tracking correlates with 2.6, this is the largest non-visual risk in
  the repo.
- **Bundle id `j.newApp`** must become real reverse-DNS.
- **Name collision** with a competitor's "* Academy" family.
- **Warm-paper variant** of the light plate, deferred.
