# CLAUDE.md — Marketing knowledge brief for LoadOut

This file is the project knowledge for a Claude Project chat window
focused on **marketing ideas, content, copy, and outreach** for the
LoadOut precision-reloading app. Paste it into the Project's
instructions / knowledge base.

The engineering CLAUDE.md (`/CLAUDE.md` at the repo root) is the
implementation reference; this document is the pitch reference. Where
they overlap, both must stay accurate — but their audiences differ.

---

## 1. The one-line pitch

**LoadOut is the precision-reloading workspace for shooters who want
to win matches, conserve their barrel, and stop tracking their loads
on paper.**

For a longer pitch: "LoadOut is a local-first ammo reloading and
ballistics app for iOS, Android, macOS, web, Apple Watch, and Wear OS.
It catalogs every load, firearm, brass lot, and range-day session
without sending your data off the device — then layers a 6-DOF
ballistic solver, 290+ scope reticles, 2,500+ factory ammo entries,
real Hornady 4DOF measured drag curves, and Bluetooth integrations
with Kestrel, Garmin Xero, and four major rangefinders on top."

## 2. The brand frame

| | |
|---|---|
| App name | **LoadOut** |
| Store name | **LoadOut: Precision Reloading** |
| Tagline (working) | "Your reloading bench, in your pocket." |
| Alt tagline | "Precision reloading. Local-first. No tracking." |
| Brand colors | Charcoal `#1F2937` + brass `#C5A572` (deliberate gun-leather + brass-cartridge palette) |
| Voice | Direct, confident, technical-but-not-jargon-soaked. Treats reloaders as adults. Never patronizing about safety; always explicit that loads must be verified against a manual. |

**Avoid in copy:** "revolutionary," "game-changing," "AI-powered" (we
have AI but the framing is utility, not buzz), "for everyone" (we
have a specific audience), "easy" without qualification (reloading is
a serious activity; "easier than your notebook" is fine).

## 3. Who we're talking to (target demographics)

In priority order:

### A. Competition shooters (highest value, highest conversion)
PRS, NRL, F-Class, Bench Rest, 3-Gun, Service Rifle. They reload to
control velocity SD, group consistency, and cost-per-shot. Already
live in apps (timers, ballistics, range cards). Will pay for tools
that win matches. The Watch / Wear stage timer + glanceable DOPE
exists for them. The BLE Kestrel + rangefinder integrations exist
for them.

**Acquisition channels:** Sniper's Hide, AccurateShooter forum,
PrecisionRifleSeries.com, NRL Hunter Discord, r/longrange,
r/precisionrifle, PRS Match podcast sponsorship.

**Conversion pitch:** "Strelok stopped at the calculator. We give
you the calculator + the workspace where the loads that drive that
calculator actually live."

### B. Reloaders generally (broadest market, mid value)
Hunters, target shooters, plinkers who reload to save money or
control terminal performance. Recipe management, brass lifecycle,
SAAMI reference, glossary. Beginner Mode lowers the activation
barrier.

**Acquisition channels:** r/reloading, Cast Boolits forum,
Hodgdon / Hornady / Sierra Twitter audiences, hunting podcasts,
local gun-club Facebook groups.

**Conversion pitch:** "You already track this stuff somewhere — a
notebook, a spreadsheet, your head. LoadOut keeps it organized,
imports what you have, and never sends a byte to a server."

### C. Younger reloaders, 18–45 (active conversion target)
More open to mobile tools. Coming from spreadsheets or no tracking
at all. Most likely to go fully mobile with reloading.

**Acquisition channels:** Instagram Reels (reloading content has
strong organic reach), TikTok, YouTube tutorials, Discord servers
for shooting communities.

**Conversion pitch:** "You shouldn't have to learn Excel to track a
load. Open the app, tap +, type 'H4350 41.5 gr', save. Done."

### D. Pen-and-paper reloaders (active conversion target — biggest cohort by raw count)
Survey data: 66% of reloaders track loads on paper. Often older
(60+), notoriously loyal to their methods, but the ones who *would*
try an app haven't because the activation cost looks too high. We
make that cost approach zero.

**Conversion pitch:** "Snap a photo of any page from your notebook.
We read your handwriting on this device — never online — and turn
it into editable recipes in 60 seconds. Keep using paper if you want;
photo a page when you finish a session."

This persona has its own dedicated onboarding path ("I have a
notebook") and a printable sample-paper-page PDF feature. We're not
asking them to abandon paper; we're asking them to add a layer.

### E. Shooting course / instructor adoption (strategic)
Instructors teaching precision rifle, reloading basics, or
competitive disciplines can use LoadOut as the reference workspace
for their students. Glossary + SAAMI reference + Beginner Mode +
workflow templates make it teachable.

**Acquisition channels:** Mil/LE training community, Rifles Only,
Magpul Dynamics-adjacent instructor networks, NRA instructor
mailing lists.

### F. Who we're NOT targeting
Active app-haters, users without smartphones, users in regulated
environments where mobile devices are prohibited at the bench. They
exist; we don't bend product decisions around them.

## 4. The competitive landscape

### Primary competitor — Strelok / Ballistic Calculator 2026

The historical Strelok ballistic calculator was discontinued; its
replacement on Google Play is `com.ballistic.calculator.strelok`,
listed as "Ballistic Calculator 2026" with 100K+ downloads. **Same
team, same engine, modern packaging.** Their claim to fame:

- **~4,000 cartridge / factory-load library**
- **~3,000 scope reticle library** with hold-over visualization
- **Bluetooth ecosystem** (Kestrel, rangefinders, magnetometers)
- **Custom Drag Models (CDM)** for measured-bullet input
- **14 years of solver pedigree** trusted by mil/LE
- **Multi-language** (Russian + many)

Their pricing: **$19.99 / 3-month, $59.99 / year, $34.99 welcome
offer, no lifetime.**

### Where we beat Strelok (lead with these in marketing)

| Their feature | Our equivalent | Marketing angle |
|---|---|---|
| Ballistics calculator | Same 6-DOF solver + hit probability + post-shot correction + group stats | "We do the math AND tell you why your shot missed." |
| 4,000 cartridges | 200+ cartridges + **2,500+ factory ammo SKUs** | "Pick your factory ammo by the box label." |
| 3,000 reticles | 290 reticles + **Scope View Pro** with what-if probability rings + tap-a-hash callouts | "Their reticle viewer is static. Ours shows you where your shot will land." |
| Strelok loads on Android only | iOS + Android + macOS + web + Apple Watch + Wear OS | "Take it from the bench to the bag to the wrist." |
| Calculator-only | **Recipe management, brass lifecycle, batch tracking, lot tracking, range-day workspace** | "Strelok stopped at the calculator. We give you the workbench." |
| Russian-origin (sensitive post-2022) | US-based (Johnson Digital Systems) | Subtle in copy. Don't overplay. |
| No data sync | **Local-first + optional end-to-end encrypted Cloud Sync to YOUR cloud** | "Your data lives on your device. Sync it across devices through your own iCloud / Drive / OneDrive — we never see it." |
| $59.99/yr | **$39.99/yr + $79.99 lifetime + $24.99 first-year welcome offer** | "33% cheaper, with a lifetime option Strelok dropped." |

### Where Strelok still beats us (acknowledge candidly)

| Their advantage | Our gap | Closing it |
|---|---|---|
| 4,000 factory ammo entries | 2,500 today | Ongoing data work; Hornady 4DOF scrape covered 300 measured curves |
| 14 years of mil/LE field validation | New product | Build it via reviews, beta testers, podcast sponsorships |
| Multi-language already shipped | We ship 6 languages (English + DE/ES/FR/IT/RU); strings only ~30% migrated to ARB | v1.1 |

### Other competitors to know

- **Hornady 4DOF app** — free Hornady-specific calculator. Limited to Hornady bullets but pulls from the same dataset we now ingest.
- **Applied Ballistics Mobile** — premium ballistics, $120/year. More accurate than Strelok in some cases. Niche audience.
- **GeoBallistics BallisticsARC** — desktop-first, mil/LE focus.
- **Reloader's Reference / The Reloader's Log** — reloading-tracking-only apps with no ballistics. We win on integration.

## 5. Feature catalog (what we ship)

Group features by user job. Use these headings in landing-page copy.

### Track every load

- Recipe management with 60+ optional fields (powder, charge, bullet,
  primer, brass, COAL, CBTO, seating depth, mandrel size, shoulder
  bump, bushing size, jump to lands, custom fields)
- Lot tracking (powder lot, primer lot, bullet lot, brass lot — each
  with manufacturer, lot number, purchase date, notes)
- Brass lifecycle (firings count, anneal history, neck wall, retired
  flag) — lot-aware so you can track a 200-piece lot of Lapua across
  20 firings without losing history
- Batch tracking (rounds loaded by date, by recipe, by firearm)
- Custom fields (add your own data points beyond what we ship)
- Auto-save (no scrolling to a Save button — every keystroke saves)

### Catalog of components and reference data

- **2,500+ factory ammo SKUs** with published MV + G1 + G7 BC
- **300+ measured Hornady 4DOF custom drag curves** (real Cd-vs-Mach
  data, not derived)
- **200+ cartridges with SAAMI specs** (case dimensions, neck angle,
  shoulder angle, max pressure, primer size)
- **156 scope optics across 21 brands** (Vortex, Leupold, Nightforce,
  S&B, Trijicon, Burris, Bushnell, Sig, Athlon, Steiner, Maven,
  Kahles, Swarovski, Zeiss, EOTech, Aimpoint, Holosun, Primary Arms,
  US Optics, Riton, Hawke)
- **290 reticles with subtension data** + hold-over visualization
- **55 target shapes** (paper, cardboard, steel, reactive, game
  silhouettes from Caldwell, Birchwood Casey, AR500, Action Target)
- 7 reloading workflow templates (PRS, F-Class, Bench Rest, 3-Gun,
  Hunting, Plinking, Silhouette) — each pre-configures recipe +
  target + distance + zero range

### Ballistic calculator (the math)

- 6-DOF Modified Point Mass solver (RK4 integration)
- G1, G7, G2, G5, G6, G8 drag tables — interpolated with Fritsch-
  Carlson PCHIP (cubic Hermite, smoother than linear in transonic
  region)
- **Custom Drag Models (CDM)** — bring your own measured curve
- **Real Hornady 4DOF data** for 300+ bullets
- ICAO standard atmosphere + Tetens humid-air density
- Coriolis effect (horizontal + Eötvös vertical)
- Spin drift (Litz formula)
- Aerodynamic jump (wind-cross-component pitch)
- Spin stability (Miller formula) — surfaces a stability factor so
  shooters can warn before firing a marginal load
- True-north azimuth correction via World Magnetic Model lookup
- Cant correction (live tilt sensor)
- Sight scale factor (vertical + horizontal) — for scopes that don't
  track exactly to their advertised increments
- Powder temperature sensitivity (fps per °C)
- Zero atmosphere (separate from runtime atmosphere — eliminates "I
  zeroed at sea level but I'm shooting at 5,000 ft" error)
- Incline / decline angle (improved rifleman's rule)
- Output: drop, drift, time of flight, velocity, energy, stability
  factor, Mach number, contributing-component breakdown

### Range Day workspace

- Live ballistic solution as you change wind / distance / target
- Reticle picker + scope view (Pro)
- Aim-point placement on target before the shot
- **Hit probability calculation** based on ballistics + group MOA +
  wind uncertainty + range estimation error (Monte Carlo dispersion
  model)
- **Post-shot correction** ("hold 1.2 mil left, 0.4 mil up") in the
  user's preferred unit (MIL / MOA / inches)
- **Group stats** (extreme spread, mean radius, group MOA at
  distance) — updates live as shots are tapped
- Movable reticle (Pro) — drag aim point, see predicted impact
- Skill-level shoot timing (Pro) — beginner / intermediate / advanced
  / expert windows for moving-target shots
- Animated mover with leading-edge / center-mass ambush guides (Pro)
- Cant + magnetometer + inclinometer one-tap capture
- GPS-aware altitude + station pressure pull (Pro weather button)

### Pen-and-paper conversion suite

- **Photo OCR (free, on-device)** — snap a notebook page, ML Kit
  reads handwriting + printed text, our parser extracts caliber,
  powder, charge, bullet, weight, COAL, CBTO, primer, brass, notes
- **Multi-page batch import** — point at a notebook, get up to 50
  recipes in one pass
- **Handwriting alias dictionary** (444 entries) — recognizes
  "H4350" / "h 4350" / "Hodgdon 4350" as the same powder; same for
  bullets, calibers, primers
- **Mixed-fraction parsing** ("41 ½" → 41.5 gr)
- **Page-context inference** — if "6.5 CM" is written once at the
  top, the parser propagates that caliber to every row on the page
- **Smart CSV / Excel import** — pick file, confirm column-to-field
  mappings (auto-suggested via fuzzy match), import 50–500+ recipes
  in one wizard
- **Sample notebook PDF** — print our paper-friendly template,
  reload at the bench, photo it back into the app
- **Quick Add forms** — minimal 5-field forms for rapid entry

### Cross-platform

- iOS (universal — phone + iPad)
- Android phone + tablet
- macOS native
- **Web** (drift WASM + IndexedDB / OPFS) — full app in the browser
- **Apple Watch** — stage timer with haptic + audio beeps,
  glanceable DOPE card with digital crown range scrolling, motion +
  swipe shot capture
- **Wear OS** — same three features, native Compose for Wear OS

### Bluetooth ecosystem (all Pro)

- **Kestrel 5xxx Link** — live BLE temperature, station pressure,
  humidity, wind, density altitude
- **Garmin Xero C1 Pro** — `.fit` file import for chronograph
  velocities + ES + SD
- **Bushnell BDX**
- **Sig Sauer KILO BDX**
- **Vortex Razor HD 4000 / Fury HD AB**
- **Leica Geovid Pro**

### Cloud sync (Pro)

- Continuous end-to-end encrypted sync to the user's own iCloud
  Drive / Google Drive / Microsoft OneDrive
- AES-256-GCM with PBKDF2-200k passphrase derivation
- Auto-syncs on AutoSave / manual save
- Manual sync button + multi-device "newer changes available"
  banner
- LoadOut never sees the encrypted blob, runs no backend, has no way
  to access user data

### Authentication

- 7 sign-in methods: email/password, email-link (passwordless),
  anonymous, Google, Apple, Microsoft, Yahoo
- Sign-in is **optional** — anonymous users get every feature
  except continuous Cloud Sync (manual one-shot encrypted backup
  is still free)

## 6. The privacy story (this is a marketing asset)

This is our biggest differentiator from cloud-first competitors.
Memorize it; quote it accurately:

> **Your reloading data lives only on your device. We don't run a
> backend that stores recipes, firearms, or range-day sessions. We
> don't track what you do in the app. We don't sell your data. We
> don't have your data.**

What we DO see, narrowly scoped:

- **Firebase Auth** processes your email + OAuth tokens during
  sign-in only (when you sign in — sign-in is optional).
- **RevenueCat** sees your purchase events when you upgrade to Pro
  (this is how IAP works).
- **Crashlytics** sees fatal crash stack traces if you opt in
  (default ON; you can turn it off in Settings; PII redacted by
  the SDK).
- **open-meteo.com** sees your latitude / longitude when you tap
  the weather pull button (Pro feature; opt-in per use).

What we explicitly DO NOT see:

- Your recipes, loads, lots, brass, batches, range-day sessions,
  ballistic profiles, custom fields, AI chats.
- Your firearms inventory.
- What features you use, how long you use them, how often you open
  the app.
- Your photos (photo OCR runs entirely on-device via ML Kit).
- Your CSV / Excel imports (parsed on-device).
- Your encrypted backup or Cloud Sync blob — we never have the key
  to decrypt it; only your passphrase does.

This isn't a privacy policy disclaimer — it's the actual product
design. Competitors that store your data on their servers
**cannot** make this claim. Lead with it.

## 7. Pricing

### Current decision

| Tier | Price | What it gates |
|---|---|---|
| Free | $0 | Recipe management, ballistic calculator, range day basics, photo OCR, smart import, watch / wear, manual encrypted backup, every catalog, glossary, SAAMI |
| **3-month** | **$14.99** | Captures seasonal users (single PRS / hunting season). Unlocks Pro features. |
| **Yearly** | **$39.99 / year** | Default plan. |
| **Yearly welcome offer** | **$24.99 first year**, then $39.99/yr | First-time subscribers only. App Store Connect Introductory Offer / Play Console Subscription Offer. |
| **Lifetime** | **$79.99 once** | One-time. Pays for itself in 2 years vs yearly. Strelok dropped lifetime entirely; we keep it as a major differentiator. |

### Pricing math vs Strelok

| | Strelok BC 2026 | LoadOut | Margin |
|---|---|---|---|
| 3-month | $19.99 | $14.99 | **−$5** |
| Yearly | $59.99 | $39.99 | **−$20** |
| Welcome | $34.99 | $24.99 | **−$10** |
| Lifetime | not offered | $79.99 | **unique** |

**Marketing angle:** "Cheaper at every tier. Plus a lifetime option
they don't sell."

### What goes in the Pro pitch

Six clear feature buckets per the proposal:

1. **Cross-device cloud sync** (iCloud / Drive / OneDrive)
2. **Real Hornady 4DOF + custom drag curves** (300+ measured)
3. **Bluetooth devices** (Kestrel + 4 rangefinders + Garmin Xero)
4. **Scope View Pro + free-aim + moving-target training**
5. **Live weather + GPS altitude pull**
6. **AI Reloading Assistant** (v1.1)

## 8. Decisions log (the "why")

Reverse-chronological. When marketing copy needs the rationale
behind a positioning choice, it's here.

- **2026-05-08 — Pen-and-paper users elevated to active conversion target.** They were "welcomed but not optimized for"; survey data shows they're 66% of the reloader market. We added a dedicated "I have a notebook" onboarding path, photo OCR alias dictionary (444 entries), sample-notebook PDF, and multi-page batch import. Marketing should now actively pitch them.
- **2026-05-08 — Crashlytics-only analytics policy.** No Google Analytics, no Mixpanel, no usage event tracking. Even anonymized event analytics violates the privacy promise. The marketing copy can lean hard on "we don't track you" because we structurally can't.
- **2026-05-08 — Three-tier + welcome offer pricing.** Strelok's replacement (Ballistic Calculator 2026) shipped at $59.99/year and dropped lifetime. We undercut on every tier and keep lifetime.
- **2026-05-07 — Watch / Wear features stay free.** They're a hook to drive phone-app downloads, not a feature in themselves. The marketing pitch: "The only ballistics calculator on your wrist."
- **2026-05-07 — Real Hornady 4DOF integration.** Pulled 300 measured Cd-vs-Mach curves from Hornady's Azure backend. Replaces our prior G7-derived approximations. Differentiator: "We use Hornady's measured radar data, not a math approximation."
- **2026-05-07 — Web platform shipped.** Flutter web with drift WASM + IndexedDB/OPFS. Adds the "open it in any browser" entry point.
- **2026-05-06 — Apple Watch + Wear OS scaffolding shipped.** Native (SwiftUI / Compose for Wear OS). Three flagship features: timer, DOPE, motion shot capture.
- **2026-05-06 — Reticle library 290 entries + Scope View Pro.** Surpasses any reloading-app competitor; matches Strelok's reticle scope without copying their UX.
- **2026-05-06 — Cloud Sync (Pro) shipped.** Continuous, end-to-end encrypted, multi-provider (iCloud + Drive + OneDrive). Auto-syncs on save.
- **2026-05-05 — Range Day workspace shipped.** 6th tab, 55 targets, shot tracking, hit probability, post-shot correction, moving target lead, group stats.
- **2026-05-05 — Smart Import (CSV + Excel).** Wizard with auto-mapping, ~100% accuracy on test workloads.
- **2026-05-05 — Photo OCR Tier 1 (on-device).** Free, privacy-aligned. Tier 2 (AI Smart Import for messier handwriting) is Pro and depends on AI proxy backend (v1.1).
- **2026-05-04 — Multi-language scaffolding (DE/ES/FR/IT/RU).** ARB infrastructure + ~30 strings migrated. Native-speaker review pre-launch.
- **2026-05-04 — Beginner Mode toggle.** Recipe form opens in Basic detail level. Quick Add becomes the default new-recipe path. Aimed squarely at the conversion personas.
- **2026-05-03 — 6-DOF solver expanded.** Coriolis + spin drift + aero jump + Miller stability + cant + sight scale + powder temp sensitivity + zero atmosphere + incline angle. Surpasses Strelok in physical-model breadth (we have aero jump, sight scale, zero atmosphere; they don't surface these explicitly).

## 9. What's coming (don't market hard yet, but mention)

- **AI Reloading Assistant** (v1.1) — Anthropic-powered chat trained
  on reloading data. Coming Soon screen + "Notify me" button live
  in the app today.
- **AI Smart Import** (v1.1, Pro) — uses the AI assistant to parse
  messier handwriting. Frontend stub today.
- **Native-speaker translation review** — 5 ARBs flagged
  `// TRANSLATOR-REVIEW`; pre-launch task.
- **Multi-page notebook OCR Tier 3** improvements — automatic page-
  break detection at 50+ entries per import.
- **Apple Watch + Wear OS feature additions** — analytics on stage
  timing, multi-stage match recap.
- **Real-time atmosphere variation along the trajectory** — for ELR
  shooters; current model treats atmosphere as constant.
- **Custom reticle drawing tool** — let users sketch a custom
  reticle for scopes we don't have in the library.

These are signaling-only in marketing — they're roadmap, not promises.

## 10. Marketing channels + content angles

### Forums / communities (priority order)

1. **Sniper's Hide** — long-range / PRS audience. Honest reviewers.
   Pitch via thread in "Optics" or "Reloading" sub-forum.
2. **AccurateShooter forum** — bench rest / F-Class. Slightly older
   demographic; lifetime tier resonates.
3. **PrecisionRifleSeries.com** — PRS-focused. Watch / Wear stage
   timer is the lead feature.
4. **r/longrange** — younger, mobile-native.
5. **r/precisionrifle** — overlapping audience.
6. **r/reloading** — broadest reloader audience. Lead with the
   privacy story and pen-and-paper conversion pitch.
7. **r/handloading** — overlap with reloading; same pitch.
8. **NRL Hunter Discord** — niche but engaged.
9. **Cast Boolits forum** — older bullet casters; lifetime tier +
   privacy promise both resonate.
10. **Hodgdon Burn Rate Society Facebook group** — powder enthusiasts.

### Social

- **Instagram Reels** — short videos showing photo OCR converting a
  notebook page to a saved recipe in 30 seconds.
- **TikTok** — same pattern; "60-second reloading bench tour."
- **YouTube** — long-form: "From notebook to LoadOut in 5 minutes,"
  "Setting up your first PRS load," "Range day with LoadOut +
  Kestrel."
- **X / Twitter** — minimal; the audience is fragmented.

### Influencer / podcast partners

- Erik Cortina (PRS / F-Class)
- Frank Galli (Sniper's Hide podcast host)
- Mil Spec Mom (3-Gun / training)
- Gunwerks ballistics content team
- Cal Zant (PrecisionRifleBlog)
- Hodgdon-sponsored content creators

### Content series ideas

- "From notebook to app" video tutorial
- "Why your scope doesn't track what it claims" (sight scale factor explainer)
- "What's actually happening in a 1,000-yard shot" (Coriolis,
  spin drift, aero jump visualization explainer using our
  contribution breakdown)
- "Powder temperature sensitivity: how cold mornings move your zero"
- "Setting up your DOPE card on Apple Watch in 5 minutes"
- "Reading a Hornady 4DOF curve" (educational + product placement)

### App Store / Play Store

- Title (≤30 chars): "LoadOut · Precision Reloading"
- Subtitle (≤30 chars): "Reloading + Ballistics App"
- Keywords (≤100 chars):
  `reloading,ballistics,reload,ammo,reloader,powder,bullet,gun,rifle,precision,prs,scope`
- Screenshots: 8 per device size (iPhone, iPad, Android phone,
  tablet) showing — recipe form, ballistic calculator output, range
  day workspace with hit probability, scope view pro with reticle,
  watch glanceable DOPE, photo OCR review screen, smart CSV import,
  privacy posture statement.

## 11. Brand voice + style guide for marketing copy

- **Direct, second-person.** "You" not "the user."
- **Specific numbers over adjectives.** "290 reticles" not "many
  reticles"; "0.10 mil agreement with Hornady's measured curve" not
  "highly accurate"; "$20 cheaper than Strelok" not "great value."
- **Show the math when it earns trust.** "We use Fritsch-Carlson
  PCHIP for drag-table interpolation" is fine in long-form copy
  aimed at the technical audience; cut it for landing-page hero copy.
- **Privacy as a feature, not a disclaimer.** "Your data lives on
  your device" reads as a benefit, not a legal hedge.
- **No emojis in landing pages, App Store copy, or formal channels.**
  Limited use in social ok (one or two per post).
- **No exclamation marks in headlines.** Reloaders are deliberate;
  matching their tone earns credibility. Save them for casual social.
- **Always include the safety frame for any specific load data.**
  "These values are starting points from published reloading data.
  Always verify against your current reloading manual before
  loading. Never start at maximum charge." — same wording as the
  in-app disclaimer.

## 12. What NOT to claim (compliance + safety)

- **Never publish specific load data** as marketing content without
  the verify-against-manual disclaimer adjacent.
- **Never claim accuracy or velocity figures** as guarantees. The
  ballistic calculator is a tool; the shooter validates.
- **Never use "we don't track" without the precise scope.** We do
  see auth events, purchase events, opt-in crash logs, and weather-
  pull lat/lon. The privacy claim is "we don't see your reloading
  data" not "we don't see anything."
- **Never claim parity with a manufacturer's official data** without
  attribution. Hornady 4DOF curves: "courtesy of Hornady" attribution
  in the app and in any marketing reference.
- **Avoid suggesting LoadOut replaces a reloading manual.** It
  augments. Manuals are still the safety reference; we're the
  tracking + math layer.
- **Don't claim "patented" or "proprietary" anything.** We use
  established public-domain ballistic models (G7 drag, Litz spin
  drift, ICAO atmosphere). Honesty here builds trust with the
  technical audience.

## 13. Useful stats + numbers for copy

Cite these directly. They're current as of 2026-05-08:

- **2,500+ factory ammo SKUs** across 37 manufacturers
- **300+ measured Hornady 4DOF curves** (real Cd-vs-Mach radar data)
- **290 reticles** across 24 brands
- **156 optics** across 21 brands
- **200+ cartridges** with full SAAMI specs
- **55 target shapes** seeded
- **138+ tests** in the codebase ensure solver math accuracy
- **0.10 mil** — agreement between our derived G7 path and Hornady's
  measured 4DOF curve at 1,000 yd (sanity benchmark)
- **66%** of reloaders use pen-and-paper today (survey)
- **6 platforms** — iOS, Android, macOS, web, Apple Watch, Wear OS
- **5 languages** at launch (English + DE/ES/FR/IT/RU); native
  review in progress
- **7 sign-in providers** including anonymous (sign-in is optional)
- **6-DOF solver** with Coriolis + spin drift + aero jump + Miller
  stability
- **AES-256-GCM + PBKDF2-200k** encryption for cloud sync / backup
- **End-to-end encrypted Cloud Sync** — no LoadOut-operated backend
  receives reloading data

## 14. Standard objections + responses

| Objection | Response |
|---|---|
| "Strelok is cheaper / I already have Strelok." | "Strelok is a calculator. LoadOut is the workspace where the loads going into that calculator actually live — recipes, brass, batches, range day. We're 33% cheaper at the yearly tier ($39.99 vs $59.99) and offer a lifetime they don't." |
| "I don't trust apps with my data." | "Your reloading data never leaves your device unless you explicitly turn on Cloud Sync. Even then, it's encrypted with your passphrase before it leaves your phone, and we never have the passphrase. We have no backend that stores your loads. We can't see what we don't have." |
| "I'm too set in my ways to switch." | "You don't have to switch. Snap a photo of your notebook page when you finish a session — we'll extract the recipes in 60 seconds. Keep using paper if you want. The app becomes a searchable backup of your paper logs." |
| "I'm not technical." | "Open it. Tap the lightning-bolt FAB. Type your load like you'd write it on paper. Save. Done. Beginner Mode hides every advanced field; turn it off when you're ready." |
| "What if you go out of business?" | "Your data is local SQLite + JSON export at any time. If we shut down tomorrow, you keep everything. We can't lock you in because we don't host you." |
| "Why should I pay for a subscription on top of the lifetime?" | "You don't have to. The free tier covers recipe management, the ballistic calculator, range day basics, photo OCR import, watch / wear features, and the entire catalog. Pro adds Bluetooth Kestrel + rangefinders, real Hornady 4DOF curves, Cloud Sync, and the AI assistant when it ships. The lifetime is for users who want all of that forever." |

## 15. Hard truths we're up-front about

These come up in long-form / forum threads. Don't dodge them.

- **App Store reviewers can be slow on reloading apps.** Submission
  may take 2–3 review cycles to clear; the disclaimer screen and
  safety messaging must be airtight. We've designed the app
  conservatively for this reason.
- **The AI assistant is not yet live.** "Coming in v1.1" — set
  user expectations honestly. Don't market AI features that don't
  ship today.
- **Native-speaker translation review hasn't happened yet.** Don't
  claim "fluent in 6 languages" until the review is done.
- **iOS 26 simulator support is in flux** for builds because of
  GoogleMLKit's slice availability. Doesn't affect end users (they
  use real devices); only matters for our build pipeline.
- **The Hornady 4DOF data is sourced from a publicly-accessible
  Azure endpoint.** Attribution is preserved in the app; if Hornady
  ever objects, we have a clean migration path back to G7-derived
  curves.

---

This file should be updated whenever a major decision lands in the
engineering CLAUDE.md. The two files mirror each other from
different angles — engineering describes how it works, this one
describes what to say about it.
