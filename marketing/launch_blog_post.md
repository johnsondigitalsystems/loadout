# Why we built LoadOut, and what's in version 1.0

*Posted to the LoadOut blog the day of launch. Audience: precision-rifle
shooters, F-class and benchrest competitors, hunters who reload, and
anyone who has ever opened an Excel sheet at the bench.*

---

If you reload, you have a system. It is part bench setup, part
spreadsheet, and part notebook page covered in pencil marks and
ballistic-tape rings. Powder weights, COAL measurements, brass
firings, chronograph strings. Probably a column for primer lot, a
column for shoulder bump, a column you started to track CBTO and gave
up on after twelve loads because the cell width stopped fitting.

We have that system too. We have used it for years across half a
dozen rifles in four cartridges. We have a 6.5 Creedmoor workup that
lives in a Numbers file with three sheets, two pivot tables, and a
revision history that goes back to 2021. We have brass we have
annealed eight times.

We also have, on our phones, four different reloading apps. Each one
does roughly one thing well. One is a ballistics calculator with a
notes field. One is a glossary with a built-in DOPE card generator.
One is a load library that wants to charge us monthly to import a
spreadsheet. One is a chronograph companion. None of them is the app
we actually want.

So we built it.

## What LoadOut is

LoadOut is a reloading app built around how reloaders actually work.
The architecture is a recipe-first, brass-tracking, range-day-aware
data model — not a calculator with a notes field bolted on. Every
screen exists for a reason a reloader will recognize.

You log a recipe and it has every field a serious reloader cares
about, including the fields most apps quietly omit: CBTO, seating
depth, primer seating depth, shoulder bump, mandrel size, date
established. You attach a brass lot to it and the lot tracks its own
firing count, anneal date, and trim date. You take it to the range,
you fire a batch, you log velocity, ES, SD, and group size against
the recipe. You run the ballistics solver on the resulting muzzle
velocity to plan the next shoot. The same data flows through every
screen, because it is the same data.

The reference content — cartridges, powders, bullets, primers, brass,
firearms, parts — ships with the app and updates over the air. The
glossary and SAAMI viewer are free, and they will stay free, because
they are how new reloaders find us. We are reloaders. We were once
new. We remember.

## What's actually in version 1.0

Specifics, in plain English.

**Recipes.** Caliber, powder, charge, bullet, primer, brass. The
advanced fields a precision reloader uses every session — COAL,
CBTO, seating depth, primer seating depth, shoulder bump, mandrel
size, date established. Add a custom powder or wildcat cartridge and
it lives in your dropdowns from then on.

**Firearms.** Manufacturer, model, type, action, caliber, barrel
length, twist rate, round count. Reference catalog of common
factory rifles ships with the app. Add a custom barrel and it
shows up alongside.

**Brass lots.** Headstamp, lot, caliber, count, firings, last
annealed, last trimmed. Per-load entries link to a lot so you can see
exactly how many firings each lot has on it. The shape your
spreadsheet has, indexed by recipe and firearm.

**Range Day.** Tap-to-place groups on a graphical target plot,
capture a target photo, tie everything to the firearm and load.
Connect a Garmin Xero chronograph, a Kestrel weather meter, or a Sig
Kilo rangefinder over Bluetooth, and the readings drop in. No copy-
pasting. No transcribing.

**Ballistics solver.** A real one. G1 and G7 drag functions. Inputs
for muzzle velocity (auto-pulled from your latest range data when
you have it), BC (auto-pulled from the bullet you picked), zero
distance, sight height, wind, density altitude, and shooting angle.
Output in MOA, MILs, and clicks at your scope's adjustment increment,
plus a trajectory chart. Save environments and rifles as profiles
for one-tap recall.

**Photo OCR import — free.** Point your camera at a notebook page,
the on-device text recognizer reads it, a heuristic parser fills in
the recipe fields, you review and save. No image leaves your phone.
We did the survey: 66% of reloaders log to paper. We met you where
you actually are.

**Smart Excel and CSV import — Pro.** Bring in your existing Excel
or CSV. Fuzzy header matching with a confidence score, a preview of
the first rows, and a per-column override for anything the auto-
matcher gets wrong. We tested it on real-world reloading sheets that
had columns labeled "Crg.," "BTO," "Powder Mfr.," and "Brass Lot # /
Anneal Date" — and the matcher hit them all on the first pass. For
the cases it missed, the override is a single dropdown and you move
on.

**Encrypted cloud backup — Pro.** Optional. Your backup is encrypted
on your device with a passphrase only you know, then uploaded to your
own iCloud Drive (iOS) or Google Drive (anywhere). LoadOut never sees
the encrypted blob. We can't recover a lost passphrase. By design.
You bought this software once; you do not now have to trust us with
the data you put into it.

**Beginner Mode.** A toggle in Settings that hides the advanced
fields and exposes a guided process checklist with inline glossary
links — deprime, tumble, resize, trim, chamfer, prime, charge, seat,
crimp. The same app grows with you from "first press" to "chasing the
node."

**Reference content.** The glossary, the SAAMI cartridge specifications,
and the component catalogs are free for everyone, signed in or not.
The catalogs update over the air so a corrected BC or a new powder
hits your phone without a store update.

## Why local-first

We are reloaders. We are also software people. We have been around
long enough to know that "data in the cloud" is a phrase that means
"data we will eventually be embarrassed about." Reloading data is
yours. It is intimate, in the sense that it describes how you shoot
and how your rifles behave. We don't want it. We don't want to host
it. We don't want to sell it. We don't want a subpoena to ever
arrive asking for it.

So we built LoadOut local-first. Every load, every firearm, every
brass lot, every range session, every ballistics profile — all of it
lives in a SQLite database on your phone. There is no LoadOut
backend that stores user reloading data. There is no opt-in server
sync that runs in the background. The only personal data that ever
leaves your device is the email address you use to sign in, and
sign-in itself is optional. Every core feature works as a guest.

When you opt into cloud backup, the backup goes to your own iCloud
Drive or Google Drive — never to us — and it is encrypted on your
device with a passphrase before it leaves. We architecturally cannot
read it. This is not a privacy promise that lives in a marketing
deck. It is the only design that makes the promise actually true.

## The platforms

LoadOut ships on iPhone, iPad, Android phone, Android tablet, and
macOS, all from the same codebase, with native chrome on each. The
iPad and Mac builds use a master/detail two-pane layout that fits how
you reload at a desk. Apple Watch and Wear OS are on the roadmap;
they are not in 1.0 because the screen is too small for the data
entry that matters.

A web companion would mean uploading your reloading data to a server
we operate, and we are not doing that. If a future feature is worth
breaking the local-first promise — we will tell you in advance, in
plain English, and we will let you keep using LoadOut without it.

## Pricing, and a word on subscriptions

LoadOut is free to download and the free tier is the full reloading
tracker. Unlimited recipes, unlimited firearms, unlimited brass lots,
unlimited custom components. Photo OCR import is free. The glossary
and SAAMI viewer are free.

Pro unlocks Smart Excel import, encrypted cloud backup, advanced
load-development analytics, and a few quality-of-life perks. Pro is
$39.99 a year — billed yearly, not monthly — or $79.99 once for a
Lifetime license. There is no monthly subscription, and there will
not be one. Reloading is a slow-cycle hobby; monthly subscriptions
churn hard on hobby tools, and we are tired of installing apps that
demand a recurring fee to do something we did once a quarter.

If you cancel Pro, your data stays. The Pro-only screens stay
readable. New edits to Pro features pause until you renew. Your
recipes, your firearms, your brass lots, your range days — all of it
stays accessible forever.

## What's next

We are reloaders. We use LoadOut at our own benches. The roadmap is
public, and the priorities are the ones you would expect: inventory
tracking, cost-per-round, an Apple Watch range timer, more BLE
device integrations, a Spanish localization. We will ship those when
they are ready, not on a calendar.

If you have been waiting for a reloading app that takes your data
seriously, takes your privacy seriously, and was built by people who
spend their weekends behind a press — welcome.

Download LoadOut on the App Store and Google Play today.

— The LoadOut team

*support@loadout-precision-reloading.web.app*
