# LoadOut — Product Roadmap

A planning document for what we ship next, mid-future, and far-future, plus
how we split features between Free and Pro tiers. This is opinionated and
amendable. Where I think a decision is non-obvious I've flagged it; the
"Open questions" section at the bottom collects the calls the user still
needs to make to advance the roadmap.

This roadmap is **product features only**. Pre-launch operations
(keystores, JWT rotation, Apple Developer org conversion, etc.) live in
`LAUNCH_CHECKLIST.md`. Don't duplicate them here.

---

## 0. Resolved decisions (from open-questions review)

These are decisions the product owner has made. They are now treated as
ground truth for the rest of the roadmap. Future contributors: change
these only by going back to the user.

1. **Three subscription SKUs.** We will ship Monthly, Yearly, and
   Lifetime. The original price points ($4.99 / $39.99 / $79.99) were
   judged too expensive; final pricing is deferred until closer to launch.
   Gating logic must support all three from day one.

2. **No record-count limits on the Free tier.** Free users get unlimited
   loads, unlimited firearms, and unlimited custom components. The
   Free/Pro split is on **features**, not on row counts.

3. **Photos are a real feature, designed in two modes.**
   - **Local-only mode** (Free + Pro). Photos save to a user-visible
     gallery folder — `LoadOut` album in iOS Photos, `Pictures/LoadOut/`
     on Android — not the app sandbox. The app stores only references
     in SQLite. The user keeps full ownership and can manage these
     photos with their normal phone tools.
   - **Cloud-backup mode** (Pro only, opt-in). Photos sync to a
     Firebase-Storage bucket scoped to the user's UID. **This triggers a
     privacy-policy revision** because we'd then host user-uploaded
     content.

4. **Smart import is a committed Pro feature.** Most reloaders keep
   their data in Excel or Google Sheets today. The import flow accepts
   `.xlsx`, `.xls`, and `.csv` (with `.tsv` and `.numbers` deferred),
   uses fuzzy column-name matching, and for unrecognized columns shows
   a "Review mappings" screen where the user can map to an existing
   field, create a custom field on the fly, or skip the column. This
   is a power-user upsell hook — Free users get the in-app create form.

5. **Recipe sharing is a committed feature, with three delivery
   channels.**
   - Email — JSON or formatted text body via the system Mail composer
     (Free).
   - Photo — recipe rendered as a styled card image, shared via the
     system share sheet (Free).
   - SMS deep link — short URL pointing at our backend; the recipient
     sees the recipe in-app if installed, otherwise in a web view with
     a "Get LoadOut" prompt (Pro).

   Sharing is opt-in per-share. A safety disclaimer is auto-appended to
   every shared payload: "This load was made for one person's specific
   firearm. Always verify against current manufacturer load data
   before reloading."

6. **Subscription handling via RevenueCat.** Their Free tier covers
   monthly tracked revenue up to $2.5K; 1% of MTR after. Saves us from
   building a receipt-validation backend.

7. **Cloud sync is a Pro feature, in Mid-term.** Triggers a
   privacy-policy revision (same wave as #3 cloud photos).

8. **No hard launch deadline.** Phases are ordered by **dependency**, not
   by calendar date.

9. **Pricing levels deferred.** Provisional ranges (Monthly $1.99–$3.99 /
   Yearly $14.99–$24.99 / Lifetime $39.99–$59.99) — calibrate after
   competitor pricing review.

10. **A serious design-language refresh is scheduled.** Existing
    reloading apps "look dull, with text boxes and no soul." LoadOut
    target: modern, trustworthy, tactile. Dark-mode default, refined
    accent (oxblood / gunmetal blue / muted brass — not consumer-loud
    orange/red/green), strong typographic hierarchy, custom iconography.
    Pro users get theme variants / accent choices.

11. **User-defined custom fields on loads + firearms** (and eventually
    inventory). Free tier: up to 2 custom fields per record type. Pro:
    unlimited. Storage via JSON column on the row for v1; can migrate
    to a relational `custom_field_values` table later if we need to
    filter on them. Custom fields plug directly into the smart-import
    flow.

---

## 1. What's already done (MVP scope)

The MVP is feature-complete for v1.0.0 and ready for store submission once
the launch-checklist items clear.

| Capability | Notes |
|---|---|
| Authentication with seven providers | Email/password, email-link (passwordless), anonymous, Google, Apple, Microsoft, Yahoo. All wired through `lib/services/auth_service.dart`. |
| Local-first storage via drift | SQLite is the only persistent store. No cloud sync. No Firestore at runtime. |
| Reference catalogs | Cartridges, powders, bullets, primers, brass, firearms, firearm parts. Seeded from `assets/seed_data/*.json` on first launch. |
| Loads CRUD | Basic + advanced views. Fields include caliber, powder, charge, bullet, primer, brass, COAL, CBTO, seating depth, primer depth, shoulder bump, mandrel, date established, notes. |
| Firearms CRUD | Name, manufacturer, model, type, action, caliber, barrel length, twist rate, shots-fired counter, optional reference-firearm link, notes. |
| Custom-component additions | Powders/bullets/primers/brass/cartridges typed by the user are saved in `CustomComponents` and reappear in dropdowns later. |
| Glossary | Searchable reloading-terms reference. |
| SAAMI specification viewer | Cartridge picker plus spec card. |
| Universal Links / App Links | Email-link sign-in works from links opened on this device. |
| Disclaimer + privacy posture | In-app privacy dialog (`HomeScreen._showPrivacyDialog`). Marketing claim: data never leaves the device. |

What is **not** done that the MVP arguably should ship with: a real app
icon, launch screen, email-verification gate, cross-device email-link UX,
and a proper test suite. Those are listed in `LAUNCH_CHECKLIST.md` and
near-term below.

---

## 2. Near-term (ship before / soon after first store release)

These are concrete, well-scoped items that build on the MVP. Sequenced
by dependency rather than calendar date — most of section 2 should land
across the first two-to-three releases. Effort is rough engineering
days: S = ≤2 days, M = 3–7 days, L = 8+ days.

### 2.1 RevenueCat + paywall plumbing (M, **Free** screen, **Pro** unlock)

The gating dependency for everything Pro. Wire the `purchases_flutter`
SDK, configure entitlements in the RevenueCat dashboard, build the
paywall UI, and stub a `EntitlementService` that exposes
`bool isPro` and a `requireProForFeature(...)` helper.

We can land 2.2–2.10 without gating anything (everyone is "Pro" in
testing), then flip the gate on once 2.1 is verified.

### 2.2 Design language refresh (M, **Free**)

Driven by decision 10. Concrete work:

- Dark-mode default theme, refined accent color (test oxblood,
  gunmetal blue, and muted brass — pick one).
- Display typeface (slab-serif or refined serif: IBM Plex Serif,
  Source Serif, Recoleta) for headings; sans (Inter or IBM Plex Sans)
  for body. Drop generic Roboto everywhere.
- Replace the placeholder bottom-nav icons (`straighten`, `menu_book`,
  `handshake`) with custom glyphs.
- Commission an app icon that nods to reloading without being on-the-nose
  (no bullets, no skulls — think headstamp typography, refined
  cartridge-shoulder silhouette).
- Generous whitespace and a strong typographic hierarchy throughout.

This bakes in the brand promise — modern, trustworthy, tactile — and
unblocks the Pro perk "theme variants / accent color choices."

### 2.3 Custom fields on loads + firearms (L, **Free** with limits / **Pro** unlimited)

Driven by decision 11. Users can extend the schema themselves with
fields the app didn't model. Field types: text, number, date, boolean.
Each field has a name, optional unit label, and display order.

Free: up to 2 custom fields per record type (so up to 2 on UserLoads,
2 on UserFirearms). Pro: unlimited.

Implementation sketch in section 6.6. This is also the foundation for
2.4 (smart import) — it's how unrecognized columns get a home.

### 2.4 Smart import from Excel / CSV (L, **Pro**)

Driven by decision 4.

- Parse `.xlsx`, `.xls`, `.csv`. Defer `.tsv` and `.numbers` to a
  later release (open question).
- Auto-detect column → field mappings via fuzzy string matching
  (e.g. "Powder Brand" → `powder`, "Charge (gr)" →
  `powder_charge_gr`, "BTO" or "CBTO" → `cbto_in`). Ship with a
  tuned mapping dictionary plus a Levenshtein/cosine-similarity
  fallback for novel column names.
- For columns the app doesn't recognize, present a "Review mappings"
  screen. Each unrecognized column shows three choices:
  1. Map to an existing schema field (dropdown of all UserLoads /
     UserFirearms columns including custom fields).
  2. Map to a **new custom field** the user creates inline (this calls
     into 2.3).
  3. Skip — don't import this column.
- Run the import in a single Drift transaction; show a result summary
  ("Imported 47 loads, 3 had warnings, 1 row skipped").

This is the strongest upsell hook for users coming from Excel /
Google Sheets. Free users get the in-app create form.

### 2.5 Photo storage — local-only mode (M, **Free + Pro**)

Driven by decision 3. Photos are for context — a snapshot of the
powder canister, a target image, a chronograph readout. Implementation:

- iOS: write to a custom Photos album named `LoadOut` via
  `photo_manager` (or `image_gallery_saver`). Need
  `NSPhotoLibraryUsageDescription` and
  `NSPhotoLibraryAddUsageDescription` strings in `Info.plist`.
- Android: write to `Pictures/LoadOut/` in shared storage
  (MediaStore on API 29+). On API 33+ photo permissions split into
  `READ_MEDIA_IMAGES`.
- The app stores only the file URI (iOS) or content URI (Android)
  on the row. Users can browse, share, and back up these photos via
  their normal phone tools.

The app **does not** own the photo bytes — uninstalling LoadOut leaves
the photos in the user's gallery. Privacy posture is unchanged.

### 2.6 Photo storage — cloud-backup mode (M, **Pro**, **privacy flag**)

Opt-in upgrade to 2.5. Photos uploaded to Firebase Storage scoped to
the user's UID. Triggers a privacy-policy revision — see section 7.

Worth keeping under a feature flag while we measure storage costs.

### 2.7 Recipe sharing (M, **Free** for email + image, **Pro** for SMS deep link)

Driven by decision 5.

- **Email** — render the load as JSON or as a formatted text body,
  open the system Mail composer. Free.
- **Image** — render the load as a styled "recipe card" image, share
  via the OS share sheet. Free. Implementation: a Flutter
  `RepaintBoundary` + `toImage()` capture into a temp PNG.
- **SMS deep link** — generate a short URL
  (`https://loadout-precision-reloading.web.app/load/<short-id>`)
  pointing at the recipe payload. Pro, because it requires backend
  storage.

Sharing is **opt-in per-share** with a confirmation modal: "this load
will be uploaded to enable sharing." Auto-append the safety disclaimer
to every shared payload.

Backend sketch in section 6.5.

### 2.8 Inventory tracking (M, **Pro**)

Quantity-on-hand for the four consumable component types: powder
(grams or grains), primers (count), bullets (count), brass (count).
Two operations:

- "Stock in" — manual add, e.g. bought 1 lb of H4350.
- "Loaded N rounds with recipe X" — decrement powder by `charge × N`,
  primers by `N`, bullets by `N`. Optionally use brass batch `Y`.

Schema additions: `ComponentInventory` (kind, name, quantity, unit) and
`InventoryTransactions` (componentId, delta, reason, timestamp,
loadId/batchId nullable). Already noted in `LAUNCH_CHECKLIST.md` under
"App functionality."

### 2.9 Load development data (M, **Pro**)

A `LoadBatches` table linked to `UserLoads` and a `LoadFirings` table
for individual measurements. Fields: chronograph velocity, ES, SD,
group size (MOA / inches at distance), ambient temperature, date,
range notes. Matches the user's existing Excel workflow per
`LAUNCH_CHECKLIST.md`. The minimum viable shape is a recipe-level
summary (average velocity, best group); full batch/firing history can
land in 3.x or later.

### 2.10 Brass batch tracking (M, **Pro**)

A `BrassBatches` table: batch name, headstamp, lot, caliber, count,
date acquired, current firing count, last annealed, last trimmed,
notes. Per-load entries link to a batch so the user can see how many
firings each batch has. Mirrors the user's current spreadsheet exactly.

### 2.11 Cost-per-round (S, **Pro**)

Optional unit price on each component (per pound of powder, per primer,
per bullet, per piece of brass). When a load has all prices populated,
show calculated cost-per-round on the load detail view and in the loads
list. No price-history tracking yet — just the latest unit price.

### 2.12 Range log / session notes (S, **Pro**)

A simple "session" entity: date, location, weather, attached firearms,
attached loads, freeform notes, optional photos. The lightest version
of 3.4 (range session tracker). Ship the simple version now, expand
later.

### 2.13 Export to CSV / JSON (S, **Pro**)

User-driven backup. One-tap "export everything" produces a `.zip` of
CSVs (loads, firearms, brass batches, inventory, sessions) plus a
JSON manifest, sharable via the OS share sheet. Already on
`LAUNCH_CHECKLIST.md` as optional. Mirrors the smart-import format so
a user can round-trip their data.

### 2.14 Better app icon and launch screen (S, **Free**)

Replaces the default Flutter icon. Pre-launch blocker per
`LAUNCH_CHECKLIST.md`. Now folded into 2.2 (design refresh) but called
out separately because it's also an operational launch blocker.

### 2.15 Email verification gate (S, **Free**)

Banner on home screen when `emailVerified` is false, with a "resend
verification email" action. Optionally gate write operations behind it.
Listed in `LAUNCH_CHECKLIST.md`.

### 2.16 Cross-device email-link UX (S, **Free**)

When `tryCompleteEmailLink` returns null because the pending email
isn't in `SharedPreferences` on this device, prompt the user to enter
their email. Listed in `LAUNCH_CHECKLIST.md`.

### 2.17 Password reset UI (S, **Free**)

A "Forgot password?" link on the email/password sign-in form that
calls `sendPasswordResetEmail`. Currently missing from `LoginScreen`.

### 2.18 Reloading process checklist / step tracker (S, **Free**)

A guided checklist for a reloading session: deprime → tumble → resize
→ trim → chamfer → prime → charge → seat → crimp. The user customizes
the steps once. Useful for new reloaders especially. **Free** because
it's a learning-aid feature aligned with the educational tone of the
glossary and SAAMI tabs.

---

## 3. Mid-term (after the first wave of Pro features lands)

Larger features that build on the inventory + load-development +
range-log + custom-fields foundation. Roughly ordered by user value
per engineering day.

### 3.1 Cloud sync (L, **Pro**, **privacy flag**)

The big one. Driven by decision 7. **This changes the privacy posture.**
Today the in-app privacy dialog and any future App Store Privacy
Disclosures say data doesn't leave the device. Adding cloud sync —
even opt-in — means:

- Updating `HomeScreen._showPrivacyDialog` text.
- Updating App Store privacy disclosures and Play Store Data Safety
  form.
- Updating `PRIVACY_POLICY.md` (the on-disk policy at the root) and
  any landing-page copy.
- Choosing a backend. Recommended: **Firebase Firestore** (Auth is
  already in place). Encrypt sensitive fields at rest if we want a
  "we cannot read your data" guarantee — recommend it given the
  audience.

This pairs naturally with 2.6 (cloud photos) and 2.7's SMS deep-link
backend — see consolidation in section 6.7.

Treat as a multi-month project, not a single feature.

### 3.2 Ballistics calculator (L, **Pro**)

Drop chart at user-specified distance (yards or meters), expressed in
MOA, MIL, and clicks at the user's scope adjustment increment. Inputs:
muzzle velocity (pulled from load development data when available),
bullet BC (pulled from `Bullets` reference table), zero distance,
sight height, and environmentals (see 3.5).

Use one of the open-source ballistic engines (G1/G7 trajectory math is
well-documented). Don't try to invent it.

### 3.3 Trajectory chart visualization (M, **Pro**)

Pairs with 3.2. Drop, drift, and time-of-flight curves out to max
distance. Possibly velocity and energy curves. `fl_chart` or
`syncfusion` both work.

### 3.4 Load comparison tool (M, **Pro**)

Pick 2–4 loads and see them side-by-side: components, charges, MV, ES,
SD, group sizes, cost-per-round. Useful when narrowing a load
development workup. Powerful with 2.9 data and 3.2 ballistics together.

### 3.5 Range session tracker, full version (M, **Pro**)

Expansion of 2.12: per-shot or per-string scoring, target photos
geo-tagged or labeled, score by ring or distance to point of aim,
aggregate stats per session. The simple version from 2.12 covers the
common case; this one is for serious load development sessions.

### 3.6 Wind / DA / temperature inputs for ballistic calc (S, **Pro**)

Wind speed and angle, density altitude (or station pressure +
temperature + humidity), shooting angle, latitude (for Coriolis at
long ranges). Most of this is already in any ballistics engine —
exposing the inputs is the work.

### 3.7 Component price tracking + "where to buy" links (M, **Free** with limits, **Pro** unlimited)

Track price history per component. Optional URL field for the vendor.
History of price changes per component lets the user see when a powder
they want to restock came back into stock at a reasonable price.

**Where to buy** links are free (it's just a URL); the price *history*
is Pro.

### 3.8 Suggested-loads engine using manufacturer load data (L, **Pro**, **legal flag**)

When the user picks a cartridge + powder, suggest published charge
ranges. **This requires either a license deal with Hodgdon /
Vihtavuori / Alliant / etc., or a careful scrape** — and scraping
load data is exactly the kind of thing manufacturers' lawyers care
about. There are also serious **safety implications** if our
suggestions don't track manufacturer revisions exactly.

Phase 2, contingent on a clean data source. We can ship a placeholder
("see manufacturer's website" deep link) much sooner.

### 3.9 Apple Watch companion (M, **Pro**)

Range timer (par time + delays), quick load lookup (read-only mirror
of the active load list). No data entry on watch — the screen is too
small. Watch app stores nothing locally; pulls via the iOS app's
local DB through WatchConnectivity.

### 3.10 iPad-optimized layout (M, **Free**)

Master/detail layout for loads and firearms screens, side panel for
glossary and SAAMI. The data model already supports it; this is a
layout pass. **Free** because it's just adapting existing features.

### 3.11 Localization — Spanish first (M, **Free**)

US shooting demographics make Spanish the strongest second-language
ROI. Use `flutter_localizations` + `intl`. Reference data (cartridge
names, SAAMI specs) generally stays in English; UI strings get
translated. Glossary terms would need translated definitions, which
is content work, not engineering work.

### 3.12 Recipe versioning / change log (S, **Pro**)

When a user edits a recipe (changes charge, swaps primer), keep the
old version. Show a small history at the bottom of the load detail
screen. Implementation: append rows to a `LoadRevisions` table on
edit instead of updating in place.

### 3.13 Theme variants / accent picker (S, **Pro**)

Pro perk that builds on the design refresh in 2.2. Two or three
curated themes (e.g., "Oxblood," "Gunmetal," "Brass") plus the
default. Stored as a user preference in SQLite.

---

## 4. Long-term (speculative — needs validation before committing)

Big bets, dependencies on other platforms / hardware, or things that
need a lot of validation before committing engineering time.

### 4.1 Community recipe library (read-only, verified data)

A curated library of manufacturer-published loads, browsable in-app,
importable into the user's load list. **Solves the legal problem of
3.8 by being explicitly licensed or explicitly first-party.** This is
basically buying a data feed from one or more manufacturers, or
partnering with one.

### 4.2 Integration with electronic powder dispensers

RCBS ChargeMaster, Auto-Trickler, Hornady Auto Charge Pro. Most use
Bluetooth. Send a charge weight from the app, dispenser throws it,
confirmation comes back. Hardware integration is fiddly and the user
base is narrow but devoted.

### 4.3 Integration with chronographs

LabRadar, Garmin Xero C1 Pro, Caldwell ChronoConnect, MagnetoSpeed.
Most have Bluetooth or a cable export. Pulling shot strings directly
into the load development screen is a real time-saver and a strong
"why do I pay for Pro" feature.

### 4.4 Bullet pull / barrel life tracking

Each firearm has a bullet count from `shotsFired`. Add round-count
classes per powder (more 4350-ish powders are kinder to barrels than
overbore magnums). Estimate barrel life and warn the user when a rifle
is approaching it. Schema is small, math is heuristic.

### 4.5 AI-assisted load suggestions based on user history

Given a user's history (what works, what didn't, which firearm),
suggest a starting workup for a new powder/bullet combo. Needs
guardrails — **we are not in the business of telling a user "load
51.0 grains of H4350 under a 140 ELD-M."** Phrasing would be "users
similar to you have started workups in this powder at X% to Y% of
book max."

### 4.6 "Spot the pressure sign" image classifier

User photographs a fired primer, app analyzes for cratering, pierced
primer, ejector swipe. **Heavy safety implications** — false negatives
could let someone keep firing dangerous loads. Probably best framed as
an educational tool with strong "consult published data" caveats, not
a diagnostic.

### 4.7 Browser-based dashboard (web companion)

Read-only dashboard you can pull up on a laptop to plan load
development across all your firearms. Depends on 3.1 (cloud sync)
because the desktop won't have the user's local DB. Flutter Web is
the obvious path.

---

## 5. Pricing and Free vs Pro breakdown

LoadOut is freemium. Free is a complete reference + tracker with no
record-count limits. Pro is the power-user toolkit: cloud, calculation,
import, analysis.

### 5.1 What's in each tier

| Feature | Free | Pro |
|---|---|---|
| Reference catalogs (cartridges, powders, bullets, primers, brass, firearms, parts) | yes | yes |
| Glossary | yes | yes |
| SAAMI specifications | yes | yes |
| All seven sign-in providers | yes | yes |
| Loads stored | unlimited | unlimited |
| Firearms stored | unlimited | unlimited |
| Custom components (user-added powders/bullets/etc.) | unlimited | unlimited |
| Basic load fields | yes | yes |
| Advanced load fields (CBTO, seating depth, primer depth, shoulder bump, mandrel, date established) | yes | yes |
| Photos for loads + firearms (local-only mode, save to user's gallery) | yes | yes |
| Recipe sharing — email | yes | yes |
| Recipe sharing — image card | yes | yes |
| Reloading process checklist | yes | yes |
| Custom fields per record type | up to 2 | unlimited |
| iPad-optimized layout (when shipped) | yes | yes |
| Localizations (when shipped) | yes | yes |
| Photos — cloud backup | — | yes |
| Recipe sharing — SMS deep link | — | yes |
| Smart import (Excel / CSV with field mapping) | — | yes |
| Inventory tracking | — | yes |
| Load development data (chronograph, ES/SD, group sizes) | — | yes |
| Brass batch tracking | — | yes |
| Cost-per-round | — | yes |
| Range session log | — | yes |
| Export / backup (CSV, JSON) | — | yes |
| Ballistics calculator + trajectory chart | — | yes |
| Load comparison tool | — | yes |
| Recipe versioning | — | yes |
| Apple Watch companion | — | yes |
| Cloud sync (when shipped) | — | yes |
| Theme variants / accent picker | — | yes |
| Priority support | — | yes |
| Early access to new features | — | yes |

### 5.2 Reasoning

Free is intentionally generous on **reference content and record
counts** because that's the marketing hook. Reloaders Google "what's
the BC of a 140 grain ELD-M" constantly; getting them into the app for
that — and letting them store unlimited loads / firearms — is the
funnel. The reference catalogs, glossary, and SAAMI viewer are also
low marginal cost — they ship in the bundle.

Pro features cluster around four pillars:

1. **Power-user data** — inventory, brass batches, cost, advanced
   load development data. The user already does this in Excel; we
   charge for replacing that workflow.
2. **Migration + portability** — smart import, cloud sync, cloud
   photo backup. These are the "I'm putting my whole shop in your
   app" features.
3. **Calculation + analysis** — ballistics, trajectory, comparison,
   AI suggestions.
4. **Personalization** — theme variants, accent pickers, priority
   support, early access.

The three "drops" most likely to convert a Free user into Pro:

- Importing their existing Excel sheet (smart import).
- Hitting the 2-custom-field limit on a record type.
- Wanting cost-per-round once they've populated component prices.

### 5.3 Provisional pricing

| Tier | Provisional range | Notes |
|---|---|---|
| Pro Monthly | $1.99 – $3.99 | Standard subscription. |
| Pro Yearly | $14.99 – $24.99 | ~33% discount over monthly. |
| Pro Lifetime | $39.99 – $59.99 one-time | "Founder" / "early supporter" pricing. Considered capping at a fixed number of seats once we have launch data. |
| Free trial | 14 days of Pro on first install | Lets the user try the gated features before deciding. |

These ranges are provisional. We will calibrate to final dollar
amounts after a competitor pricing review and (ideally) a small launch
survey. The original draft ($4.99 / $39.99 / $79.99) was judged too
expensive for the audience.

The lifetime SKU is committed (decision 1). Pros: signals confidence
in the product, removes the ad-hoc "is this worth $5/mo forever?"
decision, drives word-of-mouth. Cons: caps revenue from the
biggest fans at one transaction; can't be sustained if cloud features
become heavy ongoing server costs. If we cap lifetime sales at a
fixed number (say 500) and then discontinue, that mitigates both
downsides — early supporters got their deal, future users see only
sub pricing.

### 5.4 Gating behavior

When a user falls off Pro (cancels, trial expires; lifetime is never
an issue), we **do not delete or hide their data**. Specifically:

- Already-saved loads, firearms, custom components, custom fields,
  inventory rows, brass batches, photos all stay accessible.
- Pro-only fields and screens stay readable; **edits** to Pro-only
  features are blocked until the user resubscribes.
- Cloud sync (when added) silently pauses; local data is intact.
- Cloud photo backup pauses; local photos remain in the gallery.
- Custom fields above the Free limit (2 per record type) stay visible
  in read-only form. Adding a new one shows the paywall.

This is a moral commitment to user data ownership and avoids a class
of App Store rejection: stores have a track record of pushing back
hard against apps that hold user data hostage.

---

## 6. Technical implications

### 6.1 IAP via RevenueCat

Decision 6: **commit to RevenueCat** with the `purchases_flutter` SDK.
Their Free tier covers monthly tracked revenue up to $2.5K; 1% of MTR
after, which is acceptable given they remove the entire receipt
validation problem.

Configure these in RevenueCat + App Store Connect + Play Console:

- Product IDs: `pro_monthly`, `pro_yearly`, `pro_lifetime`.
- Entitlement: a single entitlement `pro` granted by any of the three
  products.

The SDK handles validation and exposes the entitlement to the client.
Webhooks fire on subscription events for analytics and re-engagement.

### 6.2 Pro entitlement check

Local-first. The app loads the cached entitlement from SQLite at
startup, lets the user use Pro features immediately, and refreshes the
entitlement against RevenueCat once per day (or on launch after 24
hrs).

**Grant offline-Pro for ~30 days.** App Store and Play Store both
verify periodically (typically every few days for active subs), but a
30-day grace covers travel, no-data situations, and store outages. The
grace expires only after 30 days of failed verification, not 30 days
since the last successful check.

### 6.3 Schema additions for IAP

Add a `Subscriptions` table:

```dart
class Subscriptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get firebaseUid => text()();
  TextColumn get tier => text()(); // 'free', 'pro_monthly', 'pro_yearly', 'pro_lifetime'
  DateTimeColumn get expiresAt => dateTime().nullable()();
  DateTimeColumn get lastVerifiedAt => dateTime()();
  TextColumn get revenueCatAppUserId => text().nullable()();
}
```

Bumps `schemaVersion`. Needs a `MigrationStrategy.onUpgrade` step.

### 6.4 Photo storage

Driven by decision 3.

- **Plugin**: `photo_manager` is the most flexible cross-platform
  option. `image_gallery_saver` is lighter but less control.
- **iOS permissions**: `NSPhotoLibraryUsageDescription` and
  `NSPhotoLibraryAddUsageDescription` strings in `Info.plist`.
- **Android permissions**: `READ_MEDIA_IMAGES` (API 33+),
  `READ_EXTERNAL_STORAGE` (API 32-), `WRITE_EXTERNAL_STORAGE` (API 28-
  only). Use MediaStore on API 29+ to write to `Pictures/LoadOut/`
  without WRITE permission.
- **iOS album**: create a custom `LoadOut` album via
  `PHAssetCollection`. Photos go there.
- **Schema**: add a `LoadPhotos` and `FirearmPhotos` link table, or
  store a `photo_uris_json` column on `UserLoads` / `UserFirearms` —
  recommend the link tables for ordering and per-photo metadata
  (caption, taken-at).
- **Cloud-backup mode (Pro)**: upload bytes to Firebase Storage
  bucket `loadout-precision-reloading.appspot.com` under
  `users/<uid>/photos/<photoId>`. Storage rules restrict read/write
  to the owning UID. Triggers privacy-policy update — section 7.

### 6.5 Smart import architecture

Driven by decision 4.

- **Sheet parser**: `excel` package (MIT) or
  `syncfusion_flutter_xlsxio` (commercial — check licensing before
  adopting). For CSV: `csv` package (MIT).
- **Fuzzy matching**: `string_similarity` package or roll a small
  Levenshtein implementation. Pre-seed a mapping dictionary from
  common spreadsheet column names ("Powder", "Charge (gr)", "OAL",
  "BTO", "CBTO", "Brass Lot", "Primer Lot", "Date").
- **Mapping UI flow**:
  1. User picks a file via `file_picker`.
  2. Parse headers + first 5 rows for preview.
  3. Auto-match each header to a known field by similarity score.
  4. For unmatched headers, show "Review mappings" with three radio
     options per column: existing field, new custom field, skip.
  5. On confirm: import rows in a single Drift transaction. Validate
     types as we go; collect warnings.
  6. Show a result summary screen.
- **Custom-field creation inline**: when the user picks "new custom
  field," prompt for name + type (text / number / date / boolean) +
  optional unit label. The new field definition is persisted in the
  custom-fields system (6.6) before the import row is inserted.

### 6.6 Custom fields schema

Driven by decision 11.

```dart
class CustomFieldDefinitions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get target => text()(); // 'user_loads' | 'user_firearms'
  TextColumn get name => text()();
  TextColumn get fieldType => text()(); // 'text' | 'number' | 'date' | 'boolean'
  TextColumn get unitLabel => text().nullable()();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
}
```

For v1, store custom values as a JSON column on the row:

- Add `customFieldsJson TEXT` to `UserLoads`.
- Add `customFieldsJson TEXT` to `UserFirearms`.

Shape:

```json
{ "1": "Hornady ELD-M", "2": 0.020, "3": "2026-04-18" }
```

Keys are `CustomFieldDefinitions.id`. Decode at the repository
boundary. This is simpler than a relational `custom_field_values`
table and adequate for display + edit. **Trade-off**: filtering /
sorting on a custom-field value requires JSON1 SQL functions or
in-memory filtering. If the product later needs to filter on custom
fields, we migrate to a relational table — a one-time job.

Free-tier limit (2 per `target`) is enforced at the repository
layer when inserting a new `CustomFieldDefinitions` row.

### 6.7 Sharing infrastructure

Driven by decision 5.

The SMS-deep-link channel needs server-side storage because URL length
can't hold a full load payload (and we don't want to expose schema in
URLs anyway).

Two viable backends:

- **Firebase Hosting + Cloud Functions + Firestore** — natural fit
  given Firebase Auth is already in place. Function `createShareLink`
  takes a payload, writes a doc keyed by a short ID
  (e.g. base62 random 8 chars), returns the URL. The Hosting rewrite
  for `/load/:id` calls a function that fetches the doc and returns
  HTML for the web fallback or 302s into the app's deep link.
- **Cloudflare Worker + KV** — smaller, faster, cheaper at scale, but
  introduces a second platform to operate.

Recommendation: **Firebase Functions + Firestore**. Even though we
removed Firestore from the runtime app, re-introducing it on the
server side **for sharing/cloud-sync only** keeps everything under one
roof. The privacy stance must be updated to clarify that user reload
data is still local **unless** the user explicitly enables cloud sync
or shares a specific load.

Other notes:

- Short IDs: base62 + collision check; expire after 90 days unless
  user is Pro and the link is "permanent."
- Payload schema: a JSON snapshot of the `UserLoads` row (and any
  custom-field values), plus the safety disclaimer.
- Email + image channels are entirely client-side and need no server.

### 6.8 Backend consolidation

Four roadmap features need a backend or function service:

1. **Cloud sync** (3.1).
2. **Cloud photo backup** (2.6).
3. **Recipe sharing — SMS deep link** (2.7).
4. **Smart import** server-side fallback (only if we add server-side
   parse for very large files; v1 is fully client-side).

Recommendation: **consolidate on Firebase Functions + Firestore +
Firebase Storage** for all of the above. Keeping it under one
Firebase project (`loadout-precision-reloading`) avoids running a
second platform. Trade-off: requires the Blaze plan because Functions
isn't on Spark. Cost on Spark to date is $0; a small Functions
deployment is on the order of a few dollars a month at our scale.

The cloud sync feature is what justifies this (the others are too
small alone). Once cloud sync is committed, the others become
incremental work.

### 6.9 Privacy implications (consolidated)

We are committing to several features that change the privacy posture:

1. **Subscription state** (RevenueCat) — minimal, processes purchase
   history. Already a typical disclosure.
2. **Cloud photo backup** (Pro, opt-in) — user-uploaded image
   content lives on our Firebase Storage bucket.
3. **Recipe sharing** (per-share opt-in) — load JSON lives on our
   Firestore for the lifetime of the link.
4. **Cloud sync** (Pro, opt-in) — user reload data lives on
   Firestore.

Required updates when each lands:

- `HomeScreen._showPrivacyDialog` — update copy.
- `PRIVACY_POLICY.md` — add a "Data we send to a server" subsection
  per feature.
- App Store Privacy Disclosures (in App Store Connect).
- Play Store Data Safety form.
- Public landing page (currently `public/index.html`).

The umbrella claim shifts from **"data never leaves the device"** to:

> Your reloading data stays on this device unless you explicitly enable
> cloud sync, opt in to cloud photo backup, or share a specific recipe.

### 6.10 Gating in code

A `EntitlementService` (or `ProGate`) injected via Provider, exposing
`bool isPro` and `Future<bool> requireProForFeature(BuildContext, {required String featureName, required String featureDescription})`.
Repositories call it on Pro-only inserts/updates and bail with a
paywall route if the user is not Pro.

**Important:** the gate runs only on insert/update, never on read,
and never silently deletes. A user who downgrades from Pro to Free
keeps everything they entered.

### 6.11 Migration / schema discipline

The app is at `schemaVersion = 1` with no `MigrationStrategy` because
nothing has shipped. Every roadmap item from 2.3 onward adds tables
or columns:

- 2.3 — `CustomFieldDefinitions`, `customFieldsJson` columns on
  `UserLoads` + `UserFirearms`.
- 2.5 — `LoadPhotos` + `FirearmPhotos`.
- 2.7 — no schema change for shares (the payload is built on demand).
- 2.8 — `ComponentInventory` + `InventoryTransactions`.
- 2.9 — `LoadBatches` + `LoadFirings`.
- 2.10 — `BrassBatches`.
- 2.11 — unit price columns on the relevant component tables.
- 2.12 — `RangeSessions`.
- 6.3 — `Subscriptions`.
- 3.12 — `LoadRevisions`.

Once v1.0.0 hits the store, every schema change needs a migration
step or existing users' DBs corrupt on update. Already in
`LAUNCH_CHECKLIST.md` ("Database migrations") and `CLAUDE.md`
(section 6).

---

## 7. Open questions

These are the decisions that remain genuinely open after the
open-questions review. Listed in roughly the order they affect
engineering planning.

1. **Final price points for Monthly / Yearly / Lifetime — what's our
   market research?** We have provisional ranges (5.3) but the final
   numbers are TBD. Inputs we want before committing: competitor
   pricing (Reloading Assistant, Reload-IT, GunDataPro, etc.), a
   small launch survey to early users, and a cost projection that
   includes Firebase Functions / Storage / Firestore costs once cloud
   sync ships.

2. **Apple Photos library access requires
   `NSPhotoLibraryUsageDescription` and
   `NSPhotoLibraryAddUsageDescription` — what wording do we use?**
   Apple is strict about clarity. A draft starting point: *"LoadOut
   saves photos of your loads, firearms, and range sessions to a
   LoadOut album in your Photos library, and lets you attach existing
   photos to loads and firearms."*

3. **Smart import: do we ship `.numbers` support in v1, or defer?**
   Apple Numbers files are ZIP-wrapped property lists, not the iWork
   binary format. Parsing is doable but requires a custom reader (no
   well-maintained Dart package). Defer recommendation: ship `.xlsx`
   / `.xls` / `.csv` first; add `.numbers` based on user demand.
   Open question.

4. **Recipe-sharing deep-link infrastructure — Firebase Hosting +
   Functions, or Cloudflare Worker, or both?** Recommendation in 6.7
   is Firebase. Open in case the user has Cloudflare experience or
   strong preference.

5. **Custom-field migration strategy — at what point (if any) do we
   migrate the JSON-blob storage to a relational
   `custom_field_values` table?** We start with JSON-on-row in v1
   (6.6). The trigger for migration is *needing to filter or sort on
   a custom field*. We'll watch for that need; if it comes, the
   migration is a one-time script that fans the JSON out into
   `(field_id, row_id, value_text, value_number, value_date,
   value_bool)` rows.

6. **Do we cap the Lifetime tier at a fixed seat count?** Decision 1
   committed Lifetime as a SKU. Capping at, say, 500 seats and then
   discontinuing it (in 5.3) is one mitigation for unbounded
   server-cost obligations. Open: cap or no cap.

7. **Anonymous → permanent account linking UX
   (`linkWithCredential`).** Listed in `LAUNCH_CHECKLIST.md` —
   product decision: do we offer "convert your guest account to a
   real account" prompts at sign-out / from a settings menu, or just
   from the paywall screen?

8. **Email-verification strictness.** 2.15 ships a banner. Open: do
   we soft-block (banner only) or hard-block writes until email is
   verified? Hard-block is safer; soft-block is friendlier for
   evaluators.

---

## 8. Things explicitly *not* on the roadmap

To avoid scope creep and to make the roadmap honest:

- **Social network features** (follow other reloaders, comment, like).
  Off-mission. Recipe sharing (2.7) is the only social-adjacent
  feature.
- **Selling reloading components in the app.** Off-mission, plus
  payment / age-verification / shipping complications.
- **AI chat / "ask me anything about reloading."** The hallucination
  risk on a topic where mistakes can hurt people is too high. A
  curated glossary and SAAMI viewer is the right shape.
- **Rifle-shooting score-keeping for competitions** (PRS, NRL, etc.)
  unless 3.5 (range sessions) naturally grows into it. Different app
  category, different audience.
- **Direct firearm purchase / sale tracking** (4473 form data, FFL
  transfers). Regulatory minefield. Stay out.

---

## 9. Quick reference — sequencing summary

The natural sequence, by dependency:

1. **Foundational launch polish** — design refresh (2.2), better
   icon (2.14), email verification banner (2.15), cross-device
   email-link UX (2.16), password reset UI (2.17). Ship MVP 1.0.0
   when these land.
2. **Paywall plumbing** — RevenueCat + entitlement service (2.1)
   wired but not yet enforced; everyone is "Pro" in test. Ship
   alongside or right after 1.0.0.
3. **Custom fields + smart import** — (2.3, 2.4). The biggest
   single conversion lever; pairs naturally because import depends
   on custom-field creation.
4. **Photo storage local-only** — (2.5). Lightweight, ships before
   any cloud features.
5. **Recipe sharing — email + image** — (2.7 free channels).
   Marketing fuel; no backend dependency.
6. **First Pro data wave** — inventory (2.8), load development
   (2.9), brass batches (2.10), cost-per-round (2.11). Flip the
   paywall on with this release.
7. **Range log + export** — (2.12, 2.13). Round-trip data
   portability.
8. **Backend consolidation kickoff** — set up Firebase Functions +
   Firestore for sharing (2.7 SMS channel), then cloud photos (2.6),
   then cloud sync (3.1) layered on the same backend.
9. **Mid-term Pro analytics** — ballistics (3.2), trajectory (3.3),
   comparison (3.4).
10. **Localization + iPad layout** — (3.10, 3.11). Free-tier polish
    that broadens the funnel.

The point is to ship MVP fast, then iterate. The custom-fields +
smart-import combo is the early-conversion lever; cloud sync is the
late-conversion lever; the rest is power-user retention.
