# IP Posture — LoadOut Reticle Catalog

**Status:** Draft prepared for IP-attorney engagement before App Store / Play Store submission.
**Authored:** 2026-05-12 by engineering. Reviewed by project lead.
**Audience:** Patent / trademark attorney who has never seen the LoadOut codebase. This document is the single entry point for a Freedom-to-Operate (FTO) opinion on the LoadOut reticle catalog. After reading this end to end, the reviewer should know exactly where to drill down.

---

## TL;DR

LoadOut ships a precision-reloading + ballistics app for iOS / Android / macOS / web. One of its features is a reticle picker covering **52 reticles** that match the major industry archetypes shooters know from competitor scopes. The user picks a LoadOut reticle (the artwork is LoadOut-original on every row) and the app renders it over a procedural scope view.

**Three populations of reticle**, distinguished by the `subtension_origin` field on every row in `assets/seed_data/reticles.json`:

| Origin | Count | What it means |
|---|---|---|
| `original` | 21 | LoadOut-authored geometry. No reference to any external published spec. |
| `public_domain` | 21 | Traditional patterns predating modern reticle patents (duplex, German #1/4/4A/8, plex, mil-dot, crosshair variants). |
| `published_spec` | 10 | LoadOut-original artwork whose **subtensions** (the angular spacing between reticle elements) are calibrated to a manufacturer's published specification. Each row carries a `calibration_provenance` JSON blob (manufacturer + reticle name + published spec URL). |

**Key IP decisions:**

1. **No trademarked reticle names appear in the catalog.** Not "TReMoR," "Horus," "EBR," "MOAR," "Mil-XT," "ACSS," or any other branded reticle name appears in any user-visible `model` / `family` / `id` field.
2. **No pixel-for-pixel reproduction** of any manufacturer's reticle geometry.
3. **The "Find by my scope" feature** uses nominative fair use: the user types a scope name (e.g. "Schmidt & Bender PM II 5-25x56"), the app maps to a LoadOut archetype with equivalent ballistic-math. The mapping table (`assets/seed_data/scope_reticle_options.json`) names competitor scopes but does not name competitor reticles.
4. **`published_spec` rows render an explicit "Not a reproduction" disclaimer** in the UI (see `lib/widgets/reticle_renderer.dart` `ReticleInteroperabilityLabel`). This is load-bearing legal posture, not marketing copy.

**Updated patent landscape (May 2026 research).** The FOUNDATIONAL Horus Vision Christmas Tree patents have likely expired:
- US 6,453,595 (Sammut, the original gunsight + reticle patent): expected expiration December 8, 2017.
- US 8,109,029 (the patent Horus sued Vortex Optics over in 2014, settled with prejudice December 2014): priority date May 4, 2004 + 20-year utility term → expected expiration around May 2024.
- Earlier Sammut priority chain (1998 filings): expired.

What remains active is the **post-2010 patent chain** (starting with US 9,068,794 from 2014/2015 and later filings), which is **narrower** than the foundational claims and covers specific recent features (TReMoR3/4-specific geometry, ELR features, ballistic-calculator integrations). LoadOut's Christmas-Tree variants (`loadout_mil_tree_*`, `loadout_moa_tree_*`) are now likely in the public domain at the foundational level — but specific narrow features in the newer patents could still apply.

**This document does not replace an FTO opinion.** The patent claims above are based on May 2026 public research; we have not verified through PAIR or paid databases. Attorney verification is the load-bearing safety mechanism before launch.

---

## Catalog composition

`assets/seed_data/reticles.json` contains the full catalog. Every row has:

```json
{
  "id": "loadout_mil_tree_flare",
  "model": "Christmas Tree Flare (Mil)",
  "manufacturer": "LoadOut",
  "subtension_origin": "original",
  "calibration_provenance": null,
  ...
}
```

The `manufacturer` field is **always `"LoadOut"`** for every row (verifiable by grep). No row claims authorship from a third party.

The `subtension_origin` field is the single discriminator for the three IP-relevant populations:

### The 21 `original` reticles

LoadOut-authored archetypes. Listed by id:

- `loadout_mil_tree_default`, `loadout_mil_tree_compact`, `loadout_mil_tree_medium`, `loadout_mil_tree_dense`, `loadout_mil_tree_christmas`, `loadout_mil_tree_flare`
- `loadout_moa_tree_default`, `loadout_moa_tree_compact`, `loadout_moa_tree_medium`, `loadout_moa_tree_dense`, `loadout_moa_tree_flare`
- `loadout_mil_hash`, `loadout_moa_hash`
- `loadout_sfp_mil_drop`, `loadout_sfp_moa_drop`
- `loadout_hunting_bdc`, `loadout_combat`, `loadout_combat_bdc`, `loadout_dmr_bdc`
- `loadout_holographic_ring`, `loadout_sfp_lpvo_chevron`

(The 21 actually includes some red-dot variants and SFP / hunting BDCs not enumerated above — the authoritative list is `grep -A1 'subtension_origin": "original"' assets/seed_data/reticles.json`.)

**Independent creation provenance.** Design rationale and authoring history live in:
- `docs/DECISIONS.md` — decision-by-decision record of v2.3 reticle choices.
- `docs/RETICLE_AUTHORING_GUIDE.md` — methodology for how each archetype was generated (from spec → element coordinates → JSON), including the requirement that generator scripts run and output be pasted verbatim (no hand-tweaking after generation).
- Git history — every reticle has been committed with author + timestamp; the commits form a dated provenance chain.

Geometric similarities to industry-standard patterns (e.g., 1-mil hash spacing, tree branches at 1 / 2 / 3 / 4 / 5 mil drops) reflect **industry-standard math**, not copying. A 1-mil hash spacing is the de-facto convention in the mil-radian shooter community; encoding it isn't a creative choice that could be attributed to any specific manufacturer.

### The 21 `public_domain` reticles

Traditional patterns predating modern reticle patents. By id, the `pd_*` prefix is the identifier convention:

- `pd_plex`, `pd_crosshair_fine`, `pd_crosshair_medium`, `pd_crosshair_heavy`
- `pd_german_1`, `pd_german_4`, `pd_german_4a`, `pd_german_8`
- `pd_post_crosshair`, `pd_picket_post`, `pd_post_dot`
- `pd_circle_dot`, `pd_circle_cross`
- `pd_chevron`, `pd_dotted_crosshair`, `pd_diamond_center`
- Plus `loadout_sfp_hunter_duplex`, `loadout_sfp_german_4`, `loadout_bdc_chevron_*` (three NATO BDC chevrons) — these carry `subtension_origin: "public_domain"` despite the `loadout_*` prefix because the underlying patterns are public-domain templates.

These pattern types **predate** modern reticle design patents and trademark filings. The duplex pattern dates to the 1960s (Leupold); the German #4 dates to early-20th-century European hunting scopes. None are subject to current trademark or copyright.

### The 10 `published_spec` reticles

LoadOut-original artwork whose **subtensions are calibrated** against a manufacturer's published specification. The calibration is a precision concern (1 mil should subtend 1 mil at the rated magnification), not a creative choice.

Each row carries a `calibration_provenance` JSON blob with:
- `manufacturer` — name of the manufacturer whose spec was the calibration reference (e.g., "Vortex Optics")
- `reticle_name` — name of that manufacturer's reticle (e.g., "EBR-7D MRAD")
- `published_subtension_url` — URL of the manufacturer's published spec sheet
- `verified_at` — date the calibration was verified
- `notes` — additional provenance

**The UI surfaces an explicit disclaimer on every `published_spec` reticle preview** (see `lib/widgets/reticle_renderer.dart` `ReticleInteroperabilityLabel`):

> "Calibrated to [Manufacturer] [Reticle Name]"
>
> Tooltip: "Subtensions calibrated to the published manufacturer specification. Not a reproduction. Verify against your scope's specification sheet for precision use."

The "Not a reproduction" framing is load-bearing legal posture. The reticle is LoadOut-original artwork; the subtensions match a published spec by precision necessity, not by copying.

### Important verification ask for attorney — published_spec cross-check

Confirm that **none of the 10 `published_spec` reticles** is calibrated to a Horus-derived design. Horus / HVRT reticles are licensed to several major optics manufacturers (e.g., Bushnell DMR series, Leupold Mark 5HD variants with Tremor3) — so a "Leupold" or "Bushnell" reticle in our `calibration_provenance` blob could be Horus-derived without explicitly naming Horus.

**How to check:** read each of the 10 `calibration_provenance` blobs (one `jq` query):

```sh
jq '.[] | select(.subtension_origin=="published_spec") | .calibration_provenance' assets/seed_data/reticles.json
```

Cross-reference each `(manufacturer, reticle_name)` pair against HVRT Corp's current licensing relationships.

---

## The "Find by my scope" feature

**Behaviour.** A user types a scope name into the picker (e.g., "Schmidt & Bender PM II 5-25x56"). The app suggests the LoadOut archetype whose hold-off math matches the scope's stock reticle.

**Mapping.** Lives in `assets/seed_data/scope_reticle_options.json`: 194 rows, one default reticle per scope. The scope is identified by its `id` slug (e.g., `schmidt_bender_pm_ii_5_25x56`) which derives from `(manufacturer, model_name)` via a deterministic slug rule (see `docs/RETICLE_AUTHORING_GUIDE.md` § scope-id slugification). The reticle is identified by the LoadOut reticle id.

**Nominative fair use.** Naming a competitor product to describe interoperability is well-established legal ground. The feature describes ballistic-math equivalence ("this LoadOut reticle has the same subtensions as your scope's stock reticle"), not substitution ("use this instead of your scope's reticle"). Marketing copy was reviewed during the v2.3 implementation and any "alternative to" / "substitute for" / "workaround" framing was removed (see `docs/v2.3_BRIEF_ERRATA.md` Section D and the Phase 6 marketing-copy sanitization sweep).

The 194-row mapping table names competitor **scopes** (factually identifying products the user owns) but does NOT name competitor **reticles**. The mapping ends at "LoadOut reticle id" — never "TReMoR3," "EBR-7D," or any other branded name.

---

## What LoadOut explicitly does NOT do

- **No trademarked reticle names in the catalog.** Run: `grep -Eio '(tremor|horus|ebr-[0-9]|moar|mil-xt|acss|tmoa|moart)' assets/seed_data/reticles.json`. The expected output is **empty** (zero matches). If this grep returns anything, treat it as a launch blocker.

  Trademarked reticle names DO appear in some `notes` fields and in `calibration_provenance` blobs (which is the whole point — provenance citation). They do NOT appear in user-visible `model` / `family` / `id` fields.

- **No exact reproduction** of any manufacturer's reticle geometry. The `loadout_mil_tree_flare` archetype has a flaring Christmas-tree shape — but the specific branch spacing, hash thickness, and dot sizes are LoadOut-authored numbers, not copies of any one manufacturer's published values. (Where a `published_spec` reticle is involved, the **subtensions** match — those are the angular measurements, not the artistic geometry. Artwork stays LoadOut-original.)

- **No marketing copy claiming endorsement, partnership, or affiliation** with any optics manufacturer. The marketing CLAUDE.md (`/Users/general/Development/Applications/LoadOut/marketing/CLAUDE.md`) is the authoritative voice guide for all customer-facing copy.

- **No claim to be "Horus-compatible" or "TReMoR-compatible".** We describe ballistic-math equivalence only.

- **No reproduction of patented Christmas-Tree reticle GEOMETRY** where we can identify a specific still-active patent claim. The foundational Christmas-Tree patents have likely expired (see TL;DR); the attorney FTO opinion is the load-bearing verification.

---

## Known risk areas worth attorney review

### 1. LoadOut Christmas-Tree variants

We ship `loadout_mil_tree_christmas`, `loadout_mil_tree_flare`, `loadout_moa_tree_flare`, and several other tree-style reticles.

**Initial patent research (May 2026).** The foundational Horus Vision Christmas-Tree patents have likely expired:
- US 6,453,595 — expected expiration December 8, 2017.
- US 8,109,029 — basis of Horus's 2014 suit against Vortex Optics (settled with prejudice December 2014); priority date May 4, 2004 with a 20-year utility patent term, putting expected expiration around May 2024.
- Earlier Sammut priority chain (1998): expired.

Patents transferred to **HVRT Corp** in July 2016 along with Horus Vision's acquisition by The LightForce Group / Nightforce Optics.

**Specific attorney asks:**

(a) Verify the patent expiration status above. Confirm 8,109,029 and earlier Sammut patents are in fact expired (account for any patent-term adjustments, terminal disclaimers, or continuation chains that might extend specific claims). USPTO PAIR is the authoritative source.

(b) Identify HVRT Corp's currently-active patent portfolio (post-2010 filings). Specifically review **US 9,068,794** and any later patents in the chain. Compare the active claims against LoadOut's Christmas-Tree variant geometries.

(c) Advise on whether any specific recent features in our `tree_flare` or `tree_christmas` variants might inadvertently track narrower active patent claims. Specific candidate features to test: hash spacing (1 mil major / 0.5 mil minor / 0.2 mil sub-hash), diamond reference markers (we don't have any today), ELR-specific tree features.

**Code references for drill-down:**
- `assets/seed_data/reticles.json` — element-array geometry for every reticle, including the trees.
- `lib/widgets/reticle_renderer.dart` — runtime rendering code; treated as the geometric source of truth.

### 2. "Find by my scope" mapping for HVRT-licensed reticles

Some scopes in our catalog ship with Horus / HVRT-licensed reticles:
- Bushnell Elite Tactical DMR3 (ships with G3 MIL / EQL — verify licensing status)
- Leupold Mark 5HD variants with Tremor3 / TMOA-HD
- Certain Sig Tango scopes

Our mapping table (`scope_reticle_options.json`) maps each of these scopes to a **LoadOut archetype** — never to a Horus reticle name. The user sees: "Your Bushnell DMR3 — try LoadOut Christmas Tree Mil-Flare. Same hold-off math."

**Specific attorney ask:** confirm nominative fair use covers our current mapping. With foundational patents expired, this exposure is significantly reduced from where it was five years ago — but framing review is still worth doing.

### 3. Hornady 4DOF drag-curve data redistribution (Pro feature)

We ship 300+ Doppler-radar measured Cd-vs-Mach curves from Hornady's 4DOF publication (`assets/seed_data/drag_curves/curves.json`). This is a Pro feature.

**Specific attorney ask:** review Hornady's published data-use terms and confirm our redistribution is permitted; flag any attribution or licensing requirements we're not meeting.

### 4. Marketing copy IP review

Files to review:
- `/Users/general/Development/Applications/LoadOut/marketing/CLAUDE.md` (§9 Reticles & scopes, §23 stats, §20 Disclosures + IP posture)
- App Store Connect listing (when drafted)
- Play Store Console listing (when drafted)
- Any landing pages on `https://loadout-precision-reloading.web.app`

**Specific attorney ask:** verify no language could be characterized as (a) reproducing trademarked names, (b) claiming endorsement / affiliation, or (c) inducement to infringe through substitution positioning.

---

## Source-file references (drill-down paths)

| Path | What it is |
|---|---|
| `assets/seed_data/reticles.json` | All 52 reticles with `subtension_origin` and (where applicable) `calibration_provenance` |
| `assets/seed_data/scope_reticle_options.json` | "Find by my scope" mapping (194 rows; one default reticle per scope_id) |
| `assets/seed_data/scopes.json` | 194 scope rows across 30 manufacturers |
| `docs/RETICLE_AUTHORING_GUIDE.md` | Design rationale and authoring methodology for every LoadOut-original reticle |
| `docs/DECISIONS.md` | Decision history including IP-relevant choices |
| `docs/RETICLE_LICENSING.md` | Existing IP-licensing policy document — referenced from marketing CLAUDE.md §9 |
| `docs/v2.3_BRIEF_ERRATA.md` | Errata published as part of the v2.3 rewrite; Section C documents the Phase 5 Appendix G updates that touched the catalog naming |
| `CLAUDE.md` (root engineering) | Engineering project guide; §30 covers the dual-track reticle IP posture |
| `marketing/CLAUDE.md` | Marketing voice guide; §9 covers the public-facing reticle posture |
| `lib/widgets/reticle_renderer.dart` | Runtime rendering code (geometry source of truth) and the `ReticleInteroperabilityLabel` disclaimer widget |
| `LAUNCH_CHECKLIST.md` | Pre-launch task list; includes the "Intellectual property & legal review" section that drives this engagement |

---

## How to act on this document

1. Read the TL;DR.
2. Run the catalog-composition queries (`grep`, `jq`) cited above to confirm the counts match what you see in the JSON files.
3. Review the four "Known risk areas" sections — those are the asks LoadOut wants an opinion on.
4. Drill into the source-file references as needed.
5. Issue the FTO opinion. Save the written opinion; it's part of the good-faith defense if a cease-and-desist arrives later.

Estimated engagement scope: $5k–$10k for a focused FTO opinion that covers the four risk areas above, given the foundational Christmas-Tree patents are believed expired. A from-scratch IP review covering all 194 scopes + 52 reticles would be much larger.
