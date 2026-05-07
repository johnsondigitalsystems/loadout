# LoadOut — Google Play Store Listing

Source-of-truth copy for the Play Console "Main store listing" page.
Counts are tracked next to every field that has a hard cap.

---

## App name (max 30 chars)

**Chosen:** `LoadOut: Precision Reloading`

(28 / 30)

The Play Store presents the full app name in a wider rail than Apple
does, so the longer brand-forward variant works better here than on
iOS. `LoadOut: Reloading Tracker` (26) is the alternate.

---

## Short description (max 80 chars)

**Chosen:** `Track every load, brass lot, and range day. Local-first. No cloud unless asked.`

(80 / 80) — exact fit.

Backup options:
- `The reloader's app. Recipes, brass, ballistics, range data — yours.` (66)
- `Built by reloaders. Loads, brass, ballistics, and range data on device.` (71)
- `A real reloading tracker. Not another ballistics calculator with a notes tab.` (77)

---

## Full description (max 4000 chars)

```
LoadOut is the reloading app the precision-rifle community has been
waiting for. It's built around how reloaders actually work — the
recipe, the brass lot, the range day, the chronograph string — instead
of being a ballistics calculator with a notes field bolted on.

Every screen exists for a reason a reloader will recognize.

▸ Recipes that fit your bench
Caliber, powder, charge, bullet, primer, brass — and the fields that
matter. COAL, CBTO, seating depth, primer seating depth, shoulder
bump, mandrel size, date established, free-form notes. Reference
catalogs for cartridges, powders, bullets, primers, brass, and
firearms ship with the app. Add a wildcat or hard-to-find component
and it sticks around in your dropdowns.

▸ Brass lifecycle tracking
Headstamp, lot, caliber, count, firings, last annealed, last trimmed.
Per-load entries link to a lot so you can see exactly how many
firings each piece has on it.

▸ Batch firing and load development
Velocity, ES, SD, group size, ambient temperature, range notes. Per-
shot or per-string, with the chronograph data tied to the recipe and
the firearm so you can pull up a full workup later.

▸ A real ballistics solver
G1 / G7 drag functions. Inputs for muzzle velocity, BC (auto-pulled
from the bullet you picked), zero distance, sight height, wind,
density altitude, and shooting angle. Output in MOA, MILs, and clicks
at your scope's adjustment increment, plus a trajectory chart out to
your target distance. Save environments and rifles as profiles for
one-tap recall.

▸ Range Day mode
Tap-to-plot targets on a graphical pad. Capture target photos. Tie
each group to the firearm and load. Connect a Garmin Xero
chronograph, a Kestrel weather meter, or a Sig Kilo rangefinder over
Bluetooth, and the readings drop straight in.

▸ Photo OCR import — free
Point your camera at a notebook page. The on-device text recognizer
reads the page, a heuristic parser fills in the fields, and you
review and save. No image leaves your phone. 66% of reloaders still
log to paper. We met you there.

▸ Smart Excel and CSV import — free in beta, Pro at launch
Bring in your existing Excel or CSV. Fuzzy header matching, a preview
of the first rows, and a per-column override for anything the auto-
matcher gets wrong. Round-trip back out as CSV or JSON whenever you
like.

▸ Encrypted cloud backup — your drive, your key
Optional and Pro. Backups are encrypted on your device with a
passphrase only you know, then uploaded to your own iCloud Drive or
Google Drive. We never see the encrypted blob. We can't recover a
lost passphrase. By design.

▸ Reference content, always free
SAAMI cartridge specs, a searchable reloading glossary, and the
component catalogs are free for everyone, signed in or not. The
catalogs update over the air so a corrected BC or a new powder hits
your phone without a store update.

▸ Beginner Mode
Hides the advanced fields and exposes a guided process checklist with
inline glossary links. Toggle in Settings. The same app grows with
you from "first press" to "chasing the node."

WHO IT'S FOR
PRS and NRL shooters working a load up at 1000 yards. F-class and
benchrest competitors chasing single-digit SDs. Hunters feeding a
deer rifle and a precision .22. Anyone who cares about the difference
between CBTO and COAL.

PRIVACY THAT'S NOT JUST A DASHBOARD CLAIM
Your reloading data lives in a SQLite database on your device. We
don't run a backend that stores it, we don't sell it, and we don't
train on it. Sign-in is optional — every core feature works
anonymously.

PRO
Free is the full tracker. Pro unlocks Smart Excel import, encrypted
cloud backup, advanced load-development analytics, and quality-of-
life perks. Yearly $39.99 or one-time Lifetime $79.99. No monthly
subscription, ever.

We are reloaders who got tired of using ballistics calculators with
notes fields. LoadOut is the app we wanted. Welcome to the bench.

— The LoadOut team
support@loadout-precision-reloading.web.app
```

(3,969 / 4000)

---

## What's New (per release, max 500 chars)

### Version 1.0.0 — launch

```
Welcome to LoadOut 1.0 — the launch release.

  • Recipes with the advanced fields (COAL, CBTO, mandrel, shoulder bump).
  • Brass-lot lifecycle tracking.
  • Range Day with target plotting and BLE chrono / weather meter / rangefinder support.
  • G1 / G7 ballistics solver with trajectory chart.
  • Free Photo OCR and Smart Excel import.
  • Encrypted cloud backup to your own iCloud or Google Drive.
  • Beginner Mode toggle.

Thanks for trying it. We ship fast — write us anytime.
```

(484 / 500)

---

## Categorization tradeoffs

Play Store lets you set one category and one tag list. The realistic
options:

| Category | Pros | Cons |
|---|---|---|
| **Tools** | Matches the data-tracker framing. Broad. Less competitive than Sports. Reloading apps in the store mostly sit here. | Doesn't match the "shooting discipline" intent of the search query. |
| **Sports** | Aligns with the discipline (precision rifle, PRS, hunting). Higher search volume. | More competitive. The sports-app feed is dominated by score-keepers and fitness apps that crowd the rail. |
| **Productivity** | A defensible third option for the "track + plan" framing. | Way off-target audience. Skip. |

**Recommendation:** **Tools** as primary. Reloaders Google "reloading
app for Android" and the store auto-populates the Tools rail with the
existing reloading apps; we want to be in that rail and unseat the
incumbents on quality. Add `Sports` as a secondary tag for cross-
discovery to the precision-rifle / hunting audience.

Tag list (up to 5):
1. Reloading
2. Ballistics
3. Precision rifle
4. Shooting sports
5. Field reference

---

## Content rating

ESRB Teen / PEGI 12 — based on Play Console's content questionnaire
for an app that:
- references firearms and ammunition extensively.
- contains no depictions of violence.
- has no in-app communication / chat (the AI Assistant is a one-way
  reference query, not user-to-user).
- has no profanity, sexual content, or substance use.

Australia: M. UK: PG. Brazil: 14.

If Play Console's automatic IARC rating returns a higher tier, accept
it; we should not push for a lower rating than the questionnaire
generates.

---

## Data Safety form

**Data collected:**
- Email address (account creation, sign-in).
- User ID (Firebase UID, sign-in).

**Data NOT collected:**
- Reloading data — loads, firearms, brass lots, range sessions,
  ballistics profiles. All on-device.
- Photos. Stored on-device or in the user's own gallery / cloud
  drive — never on a LoadOut server.
- Location, contacts, device or browsing history, financial data,
  health and fitness data.

**Data shared with third parties:** none.

**Encryption in transit:** yes (Firebase Auth + the user's chosen
cloud-drive provider over HTTPS).

**Data deletion:** in-app "Delete my data" wipes the local SQLite
database immediately. Sign-in account deletion is via support email
or in-app account-delete flow.

---

## URLs (placeholders)

| Field | URL |
|---|---|
| Website | `https://loadout-precision-reloading.web.app/` |
| Email | `support@loadout-precision-reloading.web.app` |
| Privacy Policy | `https://loadout-precision-reloading.web.app/privacy` |

Same hosting bucket that serves the Universal Links / App Links
files. Swap to a dedicated marketing domain when one is registered.
