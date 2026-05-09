# Reticle & scope IP / trademark risk analysis

**Status: NEEDS LEGAL REVIEW BEFORE LAUNCH.** This document is the
engineering-side framing; it is NOT legal advice.

## What we currently do in LoadOut

1. We display third-party scope names (Vortex Razor HD Gen III, S&B
   PMII 5-25x56, etc.) — purely factual, identifying the scope.
2. We display third-party reticle names ("Horus TReMoR3", "Vortex
   EBR-7D MRAD", "Nightforce MIL-XT") as picker options.
3. We render an approximation of each reticle's geometry inside our
   target-plot / scope-view widget. The geometry is sourced from
   manufacturer-published subtension PDFs where available; some are
   approximated from qualitative descriptions and flagged
   `verified: false`.
4. Users select a named reticle so the solver can return holds in
   that reticle's mil/MOA grid.

## The three IP layers

### 1. Trademarks (the NAMES)

"TReMoR3" is a trademark of Horus Vision LLC. "EBR-7D", "MOAR",
"MIL-XT", "P4F-MIL" are trademarks of their respective scope brands.

**Nominative fair use** — a US doctrine — generally allows third-
party software to USE a trademark to identify the trademarked product
when:
- the product can't be identified without the mark (true here — you
  can't say "the TReMoR3 reticle" without saying TReMoR3),
- only as much of the mark as needed is used (we use the literal
  name, not the logo or stylized presentation),
- nothing suggests sponsorship or endorsement (we don't say
  "Horus-approved" or use Horus's color scheme).

**This is what most ballistic apps do** (Strelok Pro, Hornady 4DOF,
Applied Ballistics, JBM, Geoballistics BalisticArc). The risk is
LOW, provided we add a clear disclaimer and don't visually mimic
the trademark owner's branding.

### 2. Trade dress / design patents (the GEOMETRY)

This is the harder layer. Some reticles are protected by US design
patents (15-year term from grant date) covering the visual layout.
Horus Vision in particular has been aggressive about IP enforcement;
they have sued scope manufacturers for copying H-series and TReMoR
designs without a license.

Risk profile by category:

| Category | Risk | Why |
|---|---|---|
| Generic patterns (mil-dot, mil-hash, plex, duplex, MOA crosshair) | **NONE** | Public-domain; pre-date modern IP. |
| Brand-specific reticles (Vortex EBR-*, Nightforce MOAR / MIL-XT, S&B P4F, Leupold TMR / PR2-MIL) | **MEDIUM** | Each is owned by the scope brand. They generally don't pursue software that DESCRIBES (not reproduces) their reticle for ballistic-app purposes. But the scope brand could choose to enforce; nominative fair use covers the name, but rendering an approximate visual representation is grayer. |
| Horus-licensed (TReMoR2/3/4, H58/59, H37) | **HIGH** | Horus Vision LLC is litigious. They license these reticles to scope makers (S&B, Bushnell DMR, etc.) for substantial fees. Reproducing geometry — even approximate — could be claimed as design-patent infringement OR copyright infringement on the published reticle drawing. |
| Premier-designed (Generation II, etc.) | **MEDIUM-HIGH** | Premier is now defunct; rights status unclear. Treat as Horus-equivalent until clarified. |

### 3. Copyright (the published DRAWINGS)

Reticle subtension diagrams in manufacturer PDFs are copyrighted as
creative works. Reproducing the diagrams verbatim is infringement;
reproducing the GEOMETRY they describe is generally allowed under
"merger doctrine" (when there are limited ways to express a
factual idea — you can't paraphrase a hash spacing). But
manufacturers occasionally argue otherwise.

## What other apps do

| App | Approach |
|---|---|
| **Strelok Pro** | Lists named reticles (including Horus, Vortex EBR, etc.); shows reticle subtension data; renders approximate visuals. Licensing posture: unclear / unstated. Has been live for years without a public lawsuit. |
| **Hornady 4DOF** | Only Hornady-branded reticles + a few generics. Hornady sells to its own customers, has a built-in reason to limit. |
| **Applied Ballistics** | Sells reticle data as a paid product. Has commercial licensing relationships with Horus and other brands. The premium positioning. |
| **Geoballistics BalisticArc** | Lists named reticles; shows holds in those reticle units. No visual reticle rendering on top of a target — just numbers. |
| **JBM Ballistics** | Lists named reticles for subtension data; minimal visual rendering. |

The apps that go furthest with VISUAL reticle rendering (Strelok
Pro, our app) carry more IP risk than the apps that just use the
name as a label for holds (Hornady 4DOF, Geoballistics).

## Three paths forward

### (a) License from each rights holder — **Likely impossible**

- Horus Vision: would charge per-unit royalties; their commercial
  licensees are scope manufacturers paying $$ per scope sold.
- Scope brands: typically don't license reticle IP to software
  vendors at all.

### (b) Replace high-risk named reticles with generic descriptors — **Conservative path**

- Keep scope manufacturer + model names (factual: "Schmidt & Bender
  PMII 5-25x56" — describing what scope this IS, not infringing).
- Replace Horus-licensed reticle names in the PICKER:
  - "Horus TReMoR3" → "Horus-style dense grid (mil)"
  - "Horus H59" → "Horus-style grid (mil, narrower)"
- For brand-specific reticles, similar generic descriptions:
  - "Vortex EBR-7D MRAD" → "Vortex Razor Gen III reticle (MRAD)"
  - "Nightforce MIL-XT" → "Nightforce ATACR reticle (MRAD)"
- Render OUR OWN geometry pattern (a generic Christmas-tree mil
  grid we own) instead of the trademarked design.
- Lose some fidelity in the visual; preserve full subtension data
  for hold-off math (the math isn't trademarked).

### (c) Stay with the current approach + disclaimer + lawyer's blessing — **Industry-standard path**

This is what Strelok Pro et al. effectively do. We keep using the
real names, render approximate visuals, and add:

- An in-app disclaimer surfaced once (and accessible via Settings →
  About): *"Reticle names and geometric representations are used
  for identification purposes only. LoadOut is not affiliated with,
  sponsored by, or endorsed by Horus Vision LLC, Vortex Optics,
  Nightforce, Schmidt & Bender, Leupold, Applied Ballistics, or any
  other rights holder mentioned in this app. All trademarks belong
  to their respective owners."*
- The same disclaimer in the App Store / Play Store description.
- A "best-effort, not certified" caveat in the reticle picker UI.

This requires a **lawyer's review** before launch — specifically on
the Horus question. If the lawyer says it's OK with disclaimer, ship.
If they flag Horus, fall back to (b) for Horus-only and stay with
(c) for everyone else.

## Recommendation (pre-lawyer)

- **Path (c) for all reticles**, with the disclaimer above, AND
- **Build path (b)'s generic-grid renderer as a backup** — the
  `lib/widgets/reticle_renderer.dart` shouldn't bake in any
  specific brand's design as the default; default to a generic
  Christmas-tree mil grid, only render the brand-specific shapes
  when the user explicitly picks one.

This way, if the lawyer comes back with "drop Horus", we just hide
the Horus rows + scope-reticle joins from the picker; the rest of
the app keeps working with the generic fallback. Cost: one query
filter in `reticle_picker.dart` based on a `licensingTier` field
we'd add.

## Action items for legal review

The lawyer needs to answer **specifically**:

1. Does our use of "TReMoR3" / "H59" / "EBR-7D" etc. as reticle
   names in a picker constitute trademark infringement, or is
   nominative fair use sufficient?
2. Does our rendering of approximate geometry of these reticles
   constitute design-patent or copyright infringement?
3. Is a disclaimer enough, or do we need an opt-in licensing
   relationship with Horus?
4. If we ship path (c), what's our exposure if Horus sues?
   (Probable answer: small if they've never sued similar apps;
   non-zero if our user base or revenue grows enough to attract
   their attention.)
5. Do any of the scope-brand reticles require special licensing
   that the brands have separately negotiated?

This is **not** a "we'll figure it out post-launch" item. The
disclaimer text above wants their sign-off on wording; the
licensingTier filter wants their go/no-go on Horus.

## Why not just rename now and skip the lawyer?

- We'd lose information value: a user looking for "the reticle in
  my Schmidt & Bender PMII" needs to know the actual options the
  scope ships with. Renaming "Horus TReMoR3" to something else makes
  the picker harder to use.
- Other apps that ship with the real names haven't been sued (yet,
  visibly). The exposure may be low enough that disclaimer is
  sufficient.
- Some scope-brand reticles (Vortex EBR, Nightforce MOAR, etc.) are
  almost certainly fine under nominative fair use; renaming them all
  is over-correction.
- The lawyer might surface a 4th option we haven't considered.

But path (b) is the safe rollback if (c) fails legal review. Build
the generic-grid renderer NOW so it's ready.
