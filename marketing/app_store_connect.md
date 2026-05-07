# LoadOut — App Store Connect Listing

Source-of-truth copy for the App Store Connect "App Information" and
"Version Information" pages. Counts are tracked next to every field that
has a hard cap.

---

## Title (max 30 chars)

**Chosen:** `LoadOut: Reloading Tracker`

(26 / 30)

Rationale: leads with the brand, names the category in plain English.
Reloaders search for "reloading" before they search for "ballistics."
The longer alternate `LoadOut Precision Reloading` (27 chars) is held
back as the App Store Connect "App Name" field where the brand-first
phrasing reads better in store rails.

---

## Subtitle (max 30 chars)

**Chosen:** `Bench-grade reloading tracker.`

(30 / 30) — exact fit.

Why this one: leads with a quality claim ("bench-grade") that
reloaders recognize as a synonym for serious / shop-floor / not-toy,
then uses the most-searched category noun ("reloading tracker") to
reinforce the App Store category targeting. Drops the comma-list
parlor-trick of the discarded options below — those felt clever but
read as a list of fields, not a positioning line.

Backup options (all measured):
- `For reloaders, by reloaders.` (28 / 30)
- `A reloading app for reloaders.` (30 / 30)
- `Reloader-first. Bench-grade.` (28 / 30)
- `Recipes, brass, ballistics` (26 / 30)
- `Loads. Brass. Range data.` (25 / 30)

---

## Promotional Text (max 170 chars)

`The reloader's app. Log loads, track brass, run ballistics, capture range data, import from Excel or a notebook photo. Local-first. No cloud unless you ask.`

(156 / 170)

---

## Description (max 4000 chars)

```
LoadOut is the reloading app the precision-rifle community has been
waiting for. It is built around how reloaders actually work — the
recipe, the brass lot, the range day, the chronograph string — instead
of being a ballistics calculator with a notes field bolted on.

Every screen exists for a reason a reloader will recognize.

WHAT YOU CAN DO

  • Build a recipe.
    Caliber, powder, charge, bullet, primer, brass. Then the fields
    that matter — COAL, CBTO, seating depth, primer seating depth,
    shoulder bump, mandrel size, date established, and free-form notes.
    Reference catalogs ship with the app for cartridges, powders,
    bullets, primers, brass, and firearms. Add a wildcat or a hard-to-
    find component and it sticks around in your dropdowns.

  • Track a brass lot through its life.
    Headstamp, lot, caliber, count, firings, last annealed, last
    trimmed. Per-load entries link to a lot so you can see exactly
    how many firings each piece has on it.

  • Fire a batch and log the data.
    Velocity, ES, SD, group size, ambient temp, range notes. Per-shot
    or per-string. The same shape your Excel sheet has, but indexed
    by recipe and firearm so you can pull up a workup history later.

  • Run a real ballistics solver.
    G1 / G7 drag functions. Inputs for muzzle velocity, BC (auto-
    pulled from the bullet you picked), zero distance, sight height,
    wind, density altitude, and shooting angle. Output in MOA, MILs,
    and clicks at your scope's adjustment increment, plus a trajectory
    chart out to your target distance. Save environments and rifles as
    profiles for one-tap recall.

  • Run a range day.
    Group out targets on a tap-to-place plot, capture target photos,
    and tie everything back to the firearm and load. Connect a Garmin
    Xero, Kestrel weather meter, or Sig Kilo rangefinder over Bluetooth
    and the readings drop straight in.

  • Import what you already have.
    Photo OCR — point the camera at a notebook page, the on-device
    text recognizer reads it, and a heuristic parser fills in the
    fields. No image leaves your phone.
    Smart Excel and CSV import — header mapping with fuzzy matching,
    a preview screen, and a per-column override for anything the auto-
    matcher gets wrong.

  • Look up a SAAMI cartridge spec or a glossary term.
    Searchable. Always free. No paywall.

WHO IT'S FOR

LoadOut targets serious reloaders, not curious shoppers. PRS and NRL
shooters working a load up at 1000 yards. F-class and benchrest
competitors chasing single-digit SDs. Bench reloaders feeding a
deer rifle and a precision .22. The data model assumes you care about
the difference between CBTO and COAL.

It also has a Beginner Mode that hides the advanced fields, exposes a
guided process checklist, and links to the glossary inline. The
ramp from "I just bought a press" to "I'm chasing the node" is one
toggle in Settings.

PRIVACY-FIRST, BY DEFAULT

Your reloading data lives in a SQLite database on your device. We
don't run a backend that stores it. We don't sell it. We don't train
on it.

Cloud backup is optional and end-to-end encrypted on your device with
a passphrase you choose. The blob is uploaded to YOUR own iCloud Drive
or Google Drive — never to a LoadOut server. We can't read it, recover
it, or hand it to anyone, by design.

PRO

The free tier is the full reloading tracker. Pro unlocks Smart Excel
import, encrypted cloud backup, the ballistics solver beyond a single
saved profile, advanced load-development analytics, and a few
quality-of-life perks. Yearly $39.99 or one-time Lifetime $79.99 —
no monthly subscription, ever.

We are reloaders who got tired of using ballistics calculators with
notes fields. LoadOut is the app we wanted. Welcome to the bench.
```

(3,785 / 4000)

---

## What's New — version 1.0.0 (max 4000 chars)

```
Welcome to LoadOut 1.0.

This is the launch release. Everything is new. The highlights:

  • Recipes — full CRUD on loads, with the advanced fields a serious
    reloader actually uses. CBTO, seating depth, primer depth,
    shoulder bump, mandrel size, date established.

  • Firearms — track every rifle and pistol, including barrel length,
    twist rate, and a per-firearm round count.

  • Brass lots — track a lot's headstamp, firings, anneal date, trim
    date, and link recipes to it.

  • Range Day — tap-to-plot targets, capture photos, log group sizes,
    and connect a Garmin Xero, Kestrel, or Sig Kilo over Bluetooth.

  • Ballistics — G1 / G7 trajectory solver with wind, density
    altitude, shooting angle, and Coriolis. Output in MOA, MILs, and
    scope clicks.

  • Photo Import — point your camera at a notebook page and let the
    on-device OCR fill in the recipe. No image leaves your device.

  • Smart Import — bring in your Excel or CSV with fuzzy header
    matching and a per-column override.

  • Encrypted Cloud Backup — opt-in, passphrase-protected, uploaded
    to your own iCloud Drive or Google Drive.

  • Reference catalogs — cartridges, powders, bullets, primers, brass,
    firearms, and firearm parts. Updates ship over the air.

  • Beginner Mode — hides the advanced fields and exposes a guided
    process checklist. Toggle in Settings.

  • Glossary and SAAMI specs — always free, always searchable.

Thanks for trying LoadOut. We read every email at
support@loadout-precision-reloading.web.app and we ship fast.

— The LoadOut team
```

(1,578 / 4000)

---

## Keywords (max 100 chars)

`reloading,ballistic calculator,DOPE card,brass tracking,load development,precision rifle,PRS,reload`

(99 / 100)

Notes:
- Single-word `reload` catches "reloads," "reloading," and trailing-letter variants.
- `DOPE card` is shooter shorthand and worth the dedicated keyword.
- `PRS` is the most-searched discipline acronym in the audience.
- Comma-separated, no spaces — Apple's recommended form.

---

## URLs (placeholders)

| Field | URL |
|---|---|
| Marketing URL | `https://loadout-precision-reloading.web.app/` |
| Support URL | `https://loadout-precision-reloading.web.app/support` |
| Privacy Policy URL | `https://loadout-precision-reloading.web.app/privacy` |
| Terms of Use URL | `https://loadout-precision-reloading.web.app/terms` |
| EULA (optional) | Apple Standard EULA |

The marketing site is the same Firebase Hosting bucket that serves the
Universal Links AASA file (`loadout-precision-reloading.web.app`).
Replace these with the production landing-page URLs once the marketing
site is built out.

---

## App Store Connect — Categories

- Primary: **Sports** (broadest reach for shooting-discipline searches).
- Secondary: **Utilities** (the data-tracker framing).

Alternate primary if Apple Review pushes back on Sports: **Reference**
(matches the SAAMI / glossary content).

---

## Age Rating

17+.

Trigger checkboxes:
- Frequent / intense references to firearms.

We do not depict violence, drug use, gambling, or sexual content.
Reloading content is informational and educational; the in-app
disclaimer is shown before the first session.

---

## Privacy Practice Disclosures (App Privacy)

Data Linked to You:
- Email address (account, sign-in only).
- User ID (Firebase UID, sign-in only).

Data Not Collected:
- All reloading data — loads, firearms, brass lots, range data,
  ballistics profiles. Stored on device.

Tracking:
- None. We do not track users across apps or websites.
```
