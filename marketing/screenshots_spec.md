# LoadOut — Screenshot Spec

Spec for the store-listing screenshots across every required platform.
Apple App Store and Google Play both rank the first three slots
heavily — those are the hero shots and they should sell the app on
their own.

Suggested narrative order, used across every device class:

1. Hero — recipes list (your bench, indexed)
2. Recipe form — the field set serious reloaders care about
3. Range Day — target plot, BLE devices wired in
4. Ballistics — trajectory chart with MOA / MIL / clicks
5. Photo Import — notebook page → parsed recipe
6. Smart Excel Import — header mapping with overrides
7. Brass Lots — lot lifecycle (firings, anneal, trim)
8. Encrypted Cloud Backup — your drive, your key
9. Glossary + SAAMI — free reference content
10. Beginner Mode — same app, different surface area

Treatment for every overlay:
- Wordmark in the upper-left corner of every shot.
- Headline (1 short line, ≤ 5 words) — the value claim.
- Supporting text (1 line, ≤ 12 words) — the proof.
- Background gradient: gunmetal blue → slate; never bright orange or
  bright red. Brand promise is "modern, trustworthy, tactile."
- Show a real device chrome where the platform expects it (rounded
  iPhone, flat Android, iPad with status bar).
- Use real-looking sample data — `H4350`, `Berger 140 Hybrid`,
  `Lapua 6.5 Creedmoor`, `1000 yds`. Avoid `Lorem ipsum`. Reloaders
  will spot fake data instantly and bounce.

---

## 6.5" iPhone Pro Max (1290 × 2796) — required, max 10

Used for: iPhone 15 Pro Max, 14 Pro Max, 13 Pro Max, etc. App Store
shows these in the top rail on iPhone Pro and Pro Max devices.

| # | Screen | Headline | Supporting text |
|---|---|---|---|
| 1 | Recipes list, populated with 6+ rifle loads, sorted by date. | **Your bench, indexed.** | Every load. Every revision. Searchable. |
| 2 | Recipe detail / form scrolled to show CBTO, seating depth, mandrel, shoulder bump. | **Fields serious reloaders use.** | CBTO. Mandrel. Shoulder bump. Date established. |
| 3 | Range Day target plot with 5 shots placed and a side panel showing Garmin Xero connected. | **Range Day, end to end.** | Plot the group. Read the chrono. Save the session. |
| 4 | Ballistics trajectory chart at 1000 yds with a 6.5 CM, MIL output. | **A real solver.** | G1 / G7. Wind, DA, angle. MOA, MILs, clicks. |
| 5 | Photo Import review screen — notebook page on the left, parsed fields on the right. | **Read your notebook.** | On-device OCR. No image leaves your phone. |
| 6 | Smart Import mapping screen — Excel headers on the left, app fields on the right with a couple of "Review" tags. | **Bring your spreadsheet.** | Fuzzy header matching. Override anything. Round-trip CSV / JSON. |
| 7 | Brass Lots list with a Lapua lot showing 4 firings, last anneal date, last trim date. | **Track every brass lot.** | Headstamp. Firings. Anneal. Trim. |
| 8 | Backup screen showing encrypted iCloud Drive entry + passphrase prompt. | **Your drive, your key.** | End-to-end encrypted. We can't read it. |
| 9 | Glossary screen open to "headspace," with the definition and a SAAMI link. | **Free reference, always.** | Glossary. SAAMI specs. No paywall. |
| 10 | Beginner Mode toggle on, recipe form simplified, glossary chip inline. | **Beginner Mode, anytime.** | One toggle. Same data. Less noise. |

---

## 6.7" iPhone (1320 × 2868 / 1290 × 2796) — required, max 10

Used for: iPhone 16 Pro Max and the larger non-Pro iPhones. Apple
will reuse the 6.5" set if 6.7" isn't supplied, but submit dedicated
shots — the layout is wider and a 6.5" upscaled looks soft.

Same 10-slot order and copy as 6.5". Differences:
- Crop slightly wider; show one more row in lists where the layout
  allows (Recipes list shows 7+ rows here vs 6 on 6.5").
- Range Day shot can include the device side panel a little roomier.
- Ballistics shot shows the trajectory chart full-width rather than
  with a sidebar.

---

## 12.9" iPad Pro (2048 × 2732) — required for iPad submission, max 10

Two-pane master/detail layout is the iPad story. Most shots become
side-by-side instead of single-column.

| # | Screen | Headline | Supporting text |
|---|---|---|---|
| 1 | Recipes list (left) + recipe detail (right), populated. | **Built for the workbench.** | Master / detail across every section. |
| 2 | Recipe form (right) with full advanced field set visible. | **Every field on one screen.** | No tabbing. No drilling down. |
| 3 | Range Day in landscape — target plot center, group stats right rail, BLE devices left rail. | **Range Day, table-ready.** | Plot. Connect. Capture. Save. |
| 4 | Ballistics solver in landscape — inputs left, trajectory chart right. | **The solver, side-by-side.** | Tweak inputs. Watch the curve update. |
| 5 | Photo Import — captured notebook page (left), parsed fields (right). | **OCR on a bigger canvas.** | The page on one side. The recipe on the other. |
| 6 | Smart Import — sheet preview top, mapping editor bottom. | **Spreadsheet to bench.** | Preview. Map. Override. Import. |
| 7 | Brass Lots list (left) + lot detail (right) showing per-firing log. | **The lifecycle of one lot.** | Anneal. Trim. Fire. Repeat. |
| 8 | Settings → Backup with iCloud Drive, Google Drive, and local export. | **Three ways out.** | Encrypted cloud. Local JSON. Anytime. |
| 9 | Glossary (left) + SAAMI cartridge spec (right). | **The reference shelf.** | Searchable. Free. No login. |
| 10 | Hero composite: dashboard tile collage showing recipes count, brass count, last range day, last ballistic solve. | **The reloader's app.** | Loads. Brass. Ballistics. Range data. Yours. |

---

## macOS app (2880 × 1800 or 1280 × 800) — max 10

LoadOut targets macOS via Mac Catalyst on Apple Silicon. The
screenshot set carries the iPad master/detail layout into a window
with macOS chrome.

| # | Screen | Headline | Supporting text |
|---|---|---|---|
| 1 | Two-pane Recipes list + detail in a windowed Mac frame, menu bar visible. | **Reload at the desk, too.** | Every iPad layout, in a window. |
| 2 | Recipe form + advanced fields, with a second LoadOut window pinned to the side. | **Multi-window for load development.** | Compare two recipes side by side. |
| 3 | Range Day on macOS with BLE device list and target plot. | **Same data. Bigger screen.** | Garmin Xero, Kestrel, Sig Kilo over BLE. |
| 4 | Ballistics solver running with a trajectory chart wider than the iPad equivalent. | **A solver that fits a desk.** | G1 / G7. Wind, DA, angle. Clicks. |
| 5 | Smart Import on macOS — file picker open showing an Excel sheet. | **Drag in the spreadsheet.** | Same import flow. Native picker. |
| 6 | Backup screen on macOS with iCloud Drive natively integrated. | **iCloud Drive, native.** | The encrypted blob, in your iCloud. |
| 7 | Glossary in a side-by-side reading layout. | **The glossary, browseable.** | Sized for a Mac window. |
| 8 | Cross-device frame: macOS, iPad, iPhone all showing the same recipe. | **One bench, every device.** | Sign in once. Restore from backup once. |
| 9 | Brass Lots dashboard. | **Brass lifecycle on a Mac.** | Headstamp, firings, anneal, trim. |
| 10 | Hero collage with the LoadOut wordmark and the line: "We are reloaders who got tired of ballistics calculators with notes fields." | **Welcome to the bench.** | Free to download. Pro to power-up. |

Mac App Store also accepts a hero image (poster) — use the same hero
collage as #10.

---

## Android phone (1080 × 1920 minimum, prefer 1320 × 2868) — max 8

Play Store also caps at 8 phone screenshots, not 10. Drop the lowest-
weighted two from the iPhone 6.5" set:

Use slots 1–8 from the 6.5" plan. Skip Glossary (slot 9) and
Beginner Mode (slot 10) — they appear in the feature graphic and
short description copy, and the eight-shot rail rewards starting
strong, not running long.

Same headlines, same supporting copy, Android chrome.

Additional required Play Store assets:
- **Feature graphic** (1024 × 500). Hero composite with the wordmark
  on the left and a recipe-detail screenshot on the right. Subtitle:
  "Loads, brass, ballistics, yours." Same gunmetal-blue gradient.
- **Phone hi-res icon** (512 × 512). Same icon as the in-app launcher,
  no text.

---

## Android tablet — max 8

Reuse the 12.9" iPad set, slots 1–8. Crop to the tablet aspect ratio
the Play Console expects (16:10 vs Apple's 4:3). Same headlines.

---

## Wear OS — placeholder

Not in v1.0.0. Apple Watch / Wear OS are roadmap (3.9). When that
ships, target screenshots:

1. Range timer (par time + delays).
2. Quick recipe lookup — read-only mirror of the active load list.
3. Last range day at a glance.

Until then, do not submit Wear OS screenshots — they would have
nothing to show.

---

## Production notes

- **Localization**: ship English-US and English-GB at launch. Spanish
  and German are roadmap; same screenshots, translated overlay copy.
- **Format**: PNG, no alpha, sRGB. JPEG is allowed but PNG renders
  text overlays cleaner.
- **Frame and trim**: Use `fastlane snapshot` for iOS or the Apple
  Configurator simulator workflow. For Android, use Android Studio's
  built-in screen capture and re-frame in Figma.
- **Avoid**: status-bar carrier names with "Verizon" / "T-Mobile"
  baked in, real GPS coordinates, real range names. Use a notional
  "100 yd" / "1000 yd" range with a generic photo backdrop.
- **Don't show**: a paywall as one of the first three shots. Apple
  has rejected apps for this; even when it doesn't, it tanks
  conversion.
