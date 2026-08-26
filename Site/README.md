# Alpha Academy — website

Marketing, privacy and support pages for **Alpha Academy**, the iOS trainer for the
NATO/ICAO phonetic alphabet. Built on the app's own design system (`../DESIGN.md`):
deep navy field, elevated cards, exactly one hot action per page, one light "paper"
surface reserved for the letter, zero shadows, and every numeral in IBM Plex Mono
with tabular figures.

## Files

```
Site/
├── index.html     // Landing page     → served at /
├── privacy.html   // Privacy Policy   → served at /privacy
├── support.html   // Support & FAQ    → served at /support
└── style.css      // Shared styles — design tokens live at the top
```

Contact address throughout: `support@silentspeakstudio.com`.

## Design rules this site keeps

The three most-violated rules from `DESIGN.md`, checked on every page:

- **One `hot` button per page.** `index.html` spends it on the App Store link,
  `support.html` on "Email support", `privacy.html` has none. A second one means the
  page has two primary actions and the structure is wrong.
- **One `paper` (light) surface per page,** reserved for the letter. On this site that
  is the hero plate on `index.html` — `A / Alfa / AL-FAH`. Nothing else may be light.
- **Every numeral the reader sees is IBM Plex Mono with tabular figures** — the `.mono`
  / `.num` classes, and the `.stat .value` and `.chart td.key` rules.

Also carried over: depth comes from tone (`--surface` is lighter than `--bg`), never
from a shadow; micro-labels sit above their value, never beside it; motion is
functional only, and `prefers-reduced-motion` switches it all off.

Type: **Instrument Serif** for the letter glyphs, **IBM Plex Mono** for numerals and
pronunciation keys, the system UI face for everything else — both web fonts load from
Google Fonts, nothing else is fetched.

## Hosting (Cloudflare Pages)

1. <https://dash.cloudflare.com> → **Workers & Pages** → **Create** → **Pages** →
   **Upload assets**.
2. Name the project (e.g. `alpha-academy-site`) and drag in the **contents** of this
   `Site/` folder — the four files, not the folder itself.
3. Deploy. Clean URLs come for free:
   `…/` · `…/privacy` · `…/support`.

Any static host works the same way (GitHub Pages, Netlify, Vercel).

## Wiring the URLs into App Store Connect

Once hosted, fill in `alpha.md`:

- **Support URL** → `…/support`
- **Privacy Policy URL** → `…/privacy`
- **Marketing URL** → `…/`

## Keep in sync with the app

- The App Store button on `index.html` points at
  `https://apps.apple.com/app/id6802423819` — the Apple ID from `alpha.md`. It only
  resolves once the app is live.
- `privacy.html` describes what the app actually does today: local-only training data,
  a random `device_id` in the Keychain, APNs push, AppsFlyer install attribution with
  IDFA gated behind ATT, and embedded web content. **If a service is added or dropped,
  update that page and its "Last updated" date** — the App Store review reads it.
- The counts on the landing page (36 symbols, 3 alphabets, 6 practice modes,
  34 achievements, 5 mastery levels, 4 ranks) come from `AlphabetCatalog`,
  `TrainingMode.practiceModes`, `AchievementCatalog`, `LetterProgress.maxLevel` and
  `UserProfile`. Change one of those and the numbers here go stale.
