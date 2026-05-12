# Reticle authoring guide

Companion to `assets/seed_data/README.md`. This document is for the deep work: authoring a new LoadOut reticle from scratch, understanding the element-array format, calibrating to a manufacturer spec, and verifying the result.

If you just need to add a scope mapping or fix a small issue, you don't need this guide — `seed_data/README.md` covers the basics.

---

## When you need a new reticle

Three triggers:

**Trigger 1 — a popular scope's reticle has no acceptable LoadOut match.** Run the audit:

```sh
python scripts/audit_reticle_coverage.py
```

Output lists every scope in `scopes.json`, the LoadOut reticle currently mapped to it, and a confidence score. Anything with confidence < 0.6 needs work — either re-map to a better existing reticle, or author a new one.

**Trigger 2 — a user reports their scope's reticle isn't represented.** Look up the scope. Look up the mapping. Decide: is the mapped LoadOut reticle a defensible approximation, or genuinely the wrong shape?

**Trigger 3 — a new manufacturer reticle is released that doesn't fit existing LoadOut archetypes.** Watch for: new tactical reticles with unusual sub-tier structures, new LPVO chevron designs, new BDC ladders for emerging cartridges.

---

## Three patterns for a new reticle

### Pattern A — clone a public-domain design

Used when adding another variant of an existing public-domain pattern (a slightly different duplex, a heavier crosshair).

```sh
# 1. Pick the closest existing reticle to clone
jq '.[] | select(.id == "pd_plex")' assets/seed_data/reticles.json > /tmp/new_reticle.json

# 2. Edit /tmp/new_reticle.json: change id, model, tweak elements
$EDITOR /tmp/new_reticle.json

# 3. Verify the elements render correctly
python scripts/preview_reticle.py /tmp/new_reticle.json --output /tmp/preview.svg
open /tmp/preview.svg

# 4. Run the subtension verifier
python scripts/derive_subtensions.py /tmp/new_reticle.json
# Compare derived values to what you authored. They should match within 5%.

# 5. Insert into reticles.json
jq --argjson new "$(cat /tmp/new_reticle.json)" '. + [$new]' assets/seed_data/reticles.json > /tmp/updated.json
mv /tmp/updated.json assets/seed_data/reticles.json

# 6. Bump manifest.reticles.version
$EDITOR assets/seed_data/manifest.json
```

### Pattern B — author a LoadOut original

Used for filling a genuine gap (no existing LoadOut reticle is a good match, and the design isn't public-domain enough to clone).

**Step 1 — design intent first, geometry second.**

Before opening any files, write down on paper:

- What manufacturer reticles does this LoadOut original need to functionally equivalent? (e.g., "Vortex EBR-7D, Nightforce Mil-XT, S&B H-59")
- What's the focal plane? (FFP or SFP)
- What's the native unit? (mil or MOA)
- What's the center indicator? (floating dot, crosshair gap, chevron apex, fine cross)
- What's the major hash interval? (1 mil is standard for mil; 5 MOA for MOA)
- Is there a minor hash tier? Sub-hash tier?
- Is there a Christmas tree? How many rows? What spacing? Uniform width or flaring?
- What's the maximum working extent? (5 mil typical for FFP mil; 20 MOA for FFP MOA)

Write these down as the **target subtensions**:

```jsonc
{
  "centerDotSizeUnits": 0.06,
  "majorHashIntervalUnits": 1.0,
  "minorHashIntervalUnits": 0.5,
  "subHashIntervalUnits": 0.2,
  "treeRowSpacingUnits": 1.0,
  "treeRowCount": 10,
  "treeRowWidthsUnits": [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.0, 4.0],
  "treeDepthUnits": 10.0
}
```

This is what you're building toward. Every element you author must reify these numbers.

**Step 2 — write a generator script.**

Don't hand-write 100+ JSON elements. Write a Python generator in `scripts/gen_<reticle_id>.py`. Use `scripts/gen_mil_tree_flare.py` as a template:

```python
# scripts/gen_<new_reticle>.py
import json

elements = []

# Center crosshair with gap
GAP = 0.06   # matches centerDotSizeUnits target
EXTENT = 5.0 # matches maxExtentUnits target
elements.append({"type": "line", "x1": -EXTENT, "y1": 0, "x2": -GAP, "y2": 0, "thickness": 1.0})
# ... etc

# Major hashes
MAJOR = 1.0  # matches majorHashIntervalUnits
for i in range(1, int(EXTENT) + 1):
    elements.append({"type": "hash", "x": i,  "y": 0, "length": 0.4, "thickness": 1.5})
    elements.append({"type": "hash", "x": -i, "y": 0, "length": 0.4, "thickness": 1.5})

# Minor hashes
MINOR = 0.5
for half in [0.5, 1.5, 2.5, 3.5, 4.5]:
    elements.append({"type": "hash", "x": half,  "y": 0, "length": 0.2, "thickness": 1.0})
    elements.append({"type": "hash", "x": -half, "y": 0, "length": 0.2, "thickness": 1.0})

# ... continue for sub-hashes, vertical stadia, tree, numbers

print(json.dumps(elements, indent=2))
```

Run the generator, redirect to a draft file:

```sh
python scripts/gen_new_reticle.py > /tmp/elements.json
```

**Step 3 — preview before committing.**

```sh
python scripts/preview_reticle.py /tmp/draft.json --output /tmp/preview.svg
open /tmp/preview.svg
```

Look at it. Does it match your design intent? Does the tree flare correctly? Is the center indicator visible? Are the numbers placed where they should be?

Iterate. Edit the generator, regenerate elements, re-preview. Don't move to step 4 until the SVG matches what you sketched in step 1.

**Step 4 — write the catalog entry.**

```jsonc
{
  "id": "loadout_<your_id>",
  "model": "<Human-readable name>",
  "family": "loadout_originals",
  "nativeUnit": "mil",
  "maxExtentUnits": 5.0,
  "manufacturer": "LoadOut",
  "subtension_origin": "original",
  "subtensions": { /* the values you targeted in step 1 */ },
  "calibration_provenance": null,
  "notes": "Short description. What this reticle is functionally equivalent to.",
  "elements": [ /* paste from generator output */ ]
}
```

**Step 5 — verify the algorithm agrees with your authored subtensions.**

```sh
python scripts/derive_subtensions.py /tmp/draft.json
```

Output is what the algorithm thinks your reticle's subtensions are. Compare to what you authored:

| Field | Authored | Derived | Match? |
|---|---|---|---|
| centerDotSizeUnits | 0.06 | 0.06 | ✓ |
| majorHashIntervalUnits | 1.0 | 1.0 | ✓ |
| minorHashIntervalUnits | 0.5 | 0.5 | ✓ |
| subHashIntervalUnits | 0.2 | 0.2 | ✓ |
| treeRowSpacingUnits | 1.0 | 1.0 | ✓ |
| treeRowCount | 10 | 10 | ✓ |
| treeRowWidthsUnits | [0.5, 1.0, ..., 4.0] | [0.5, 1.0, ..., 4.0] | ✓ |
| treeDepthUnits | 10.0 | 10.0 | ✓ |

If any field disagrees, one of two things is wrong:
- **The elements don't reify the subtensions.** Look at your generator — does it actually place hashes where the authored major/minor/sub intervals say? Fix the generator.
- **The authored subtensions are wrong.** You may have misjudged what your reticle actually represents. Fix the JSON.

Don't ship a reticle where authored and derived values disagree. The disagreement IS the bug.

**Step 6 — insert into reticles.json and update mappings.**

```sh
# Insert
jq --argjson new "$(cat /tmp/draft.json)" '. + [$new]' assets/seed_data/reticles.json > /tmp/updated.json
mv /tmp/updated.json assets/seed_data/reticles.json

# Update scope_reticle_options.json for every scope that should map to this
$EDITOR assets/seed_data/scope_reticle_options.json
```

**Step 7 — bump manifests, commit, deploy.**

```sh
# Bump reticles.version in manifest.json
$EDITOR assets/seed_data/manifest.json

# Run analyzer
flutter analyze

# Commit
git add assets/seed_data/
git commit -m "Add loadout_<new_id> reticle for <scope class>"

# Deploy to Firebase Storage
gsutil -m cp assets/seed_data/*.json gs://loadout-precision-reloading.firebasestorage.app/seed_data/
```

### Pattern C — calibrate a LoadOut original to a manufacturer spec

Used when you want the LoadOut reticle to claim functional equivalence to a specific manufacturer reticle. This is the strongest form of "find a reticle like yours" — the LoadOut reticle's subtensions exactly match the manufacturer's published values.

Pattern C builds on Pattern B. After steps 1-6 of Pattern B:

**Step 7a — research the manufacturer spec.**

Find the manufacturer's official published subtensions for the target reticle. Sources:
- Manufacturer spec sheets (PDF on their website)
- Reticle spec pages
- Product brochures

Save the URL. Take a screenshot. Confirm:
- Center indicator dimension
- Major hash interval
- Minor hash interval (if any)
- Sub-hash interval (if any)
- Tree row spacing (if any)
- Tree row widths (if any)
- Tree depth (if any)

**Step 7b — verify your LoadOut original matches.**

Compare your authored `subtensions` to the manufacturer spec. If they don't match exactly, decide:
- Edit the LoadOut reticle's elements to match. (Most common.)
- Accept a small discrepancy and document it in the notes. (Rare; only for cases where the manufacturer's value is impractical to render — e.g. they have 0.18 mil hashes; you author at 0.2.)

**Step 7c — add `calibration_provenance` to the entry.**

```jsonc
{
  "id": "loadout_<your_id>",
  /* ... existing fields ... */
  "subtension_origin": "published_spec",     /* CHANGED from "original" */
  "calibration_provenance": {
    "manufacturer": "Sig Sauer",
    "reticle_name": "BDX-R1",
    "published_url": "https://sigsauer.com/.../BDX-R1-spec-sheet.pdf",
    "verified_at": "2026-05-08"
  },
  "notes": "..."
}
```

**Step 7d — update the disclaimer rendering test.**

In `test/widget/reticle_disclaimer_test.dart`, add a case asserting that the new reticle renders the correct disclaimer variant (the "published_spec" variant with the manufacturer name in the placeholder).

**Why Pattern C is more work than Pattern B:** the disclaimer to the user now makes a specific claim ("calibrated to match Sig Sauer's published specifications"). That claim must be defensible. The `calibration_provenance` URL is the legal anchor — keep it valid. If Sig changes their published spec or takes down the URL, you have a maintenance burden.

---

## The element-array format in depth

The renderer iterates over the `elements` array, switches on `type`, and draws each. Element types and their semantics:

### `line`

```jsonc
{"type": "line", "x1": -5.0, "y1": 0, "x2": -0.06, "y2": 0, "thickness": 1.0}
```

A straight segment from `(x1, y1)` to `(x2, y2)`. Coordinates in reticle units (mil or MOA per `nativeUnit`). Thickness in pixels at the rendering resolution.

Used for: crosshair stadia, post lines, tree row separators.

### `crosshair`

```jsonc
{"type": "crosshair", "x1": 0, "y1": -5.0, "x2": 0, "y2": -0.06, "thickness": 1.0}
```

Semantically identical to `line`. Use this type for the main crosshair so the renderer can distinguish it from incidental lines (e.g. for special rendering when the user toggles "highlight crosshair").

### `dot`

```jsonc
{"type": "dot", "x": 0, "y": 0, "radius": 0.03, "open": false}
```

Circle at `(x, y)` with given radius. If `open: true`, draws as a hollow ring (used for moon-ring style indicators). If `open: false` (default), filled.

Used for: center floating dot, tree wind-hold dots, mil-dot reticle dots.

### `hash`

```jsonc
{"type": "hash", "x": 1, "y": 0, "length": 0.4, "thickness": 1.5}
```

Perpendicular tick mark at `(x, y)`. Length is the total tick length (centered on the point). Orientation derived from position:
- `y == 0`: hash is on horizontal stadia → drawn vertically
- `x == 0`: hash is on vertical stadia → drawn horizontally
- Otherwise: hash is in the tree → drawn vertically (parallel to the post)

Used for: major hashes (long, ~0.4 mil), minor hashes (medium, ~0.2 mil), sub-hashes (short, ~0.1 mil), tree row indicators.

### `number`

```jsonc
{"type": "number", "x": 1, "y": 0.7, "text": "1", "fontSize": 0.4}
```

Text label at `(x, y)`. fontSize is in reticle units (typically 0.4 mil = small reference label).

Used for: numbered hash labels (1, 2, 3 ... on stadia), tree row drop labels.

### `chevron`

```jsonc
{"type": "chevron", "x": 0, "y": 3.5, "width": 0.5, "height": 0.3}
```

Triangular pointer. `(x, y)` is the apex (point). `width` is the base width, `height` is the apex-to-base distance.

Used for: BDC chevrons (LPVO holdover indicators), ACSS-style chevron aiming systems (LoadOut original equivalents).

### `rectangle`

```jsonc
{"type": "rectangle", "x1": -0.5, "y1": 2.0, "x2": 0.5, "y2": 2.5, "filled": false, "thickness": 1.0}
```

Rect from `(x1, y1)` to `(x2, y2)`. `filled: true` for solid; `filled: false` (default) for stroked.

Used for: hold-off boxes, target-size silhouettes within the reticle (rare).

### Coordinate convention

- Origin `(0, 0)` is reticle center
- **+x is right, +y is DOWN**
- Stadia above center: negative y (e.g. y = -3 for "3 mil above center")
- Christmas tree below center: positive y (e.g. y = +5 for "5 mil drop")
- Units are mil or MOA per the reticle's `nativeUnit`

### Authoring conventions for element thickness and hash length

These are LoadOut conventions, not hard rules, but consistency matters:

| Element | Thickness | Length (if hash) | Notes |
|---|---|---|---|
| Crosshair stadia (main lines) | 1.0 | — | Stays visually thin at all magnifications |
| Major hash | 1.5 | 0.4 | Visible as the primary reference |
| Minor hash | 1.0 | 0.2 | Half the length, half the visual weight |
| Sub-hash | 0.7 | 0.1 | Quarter the length, lighter still |
| Tree wind dot radius | — | 0.04 | About 2/3 the size of major hashes' tick length |
| Center floating dot radius | — | 0.03 | Slightly smaller than wind dots |
| Number labels fontSize | — | 0.4 | Matches major hash length |

A new reticle authored outside these conventions will visually clash with the rest of the catalog.

---

## The 4 new reticles authored in v2

For reference, the four new reticles added in the v2 rewrite:

### `loadout_mil_tree_flare` — FFP mil Christmas tree

**179 elements.** Targets the modern tactical FFP mil reticle family: Vortex EBR-7D, Nightforce Mil-XT/Mil-C, Schmidt & Bender H-59/P4F/GR2ID, Hensoldt SKMR3, Athlon APRS6, Burris SCR2 Mil, Steiner MSR2.

Geometry:
- Crosshair stadia at ±5 mil
- Center crosshair gap 0.06 mil with a 0.06 mil floating dot
- Major hashes at every 1 mil (length 0.4, thickness 1.5)
- Minor hashes at every 0.5 mil (length 0.2, thickness 1.0)
- Sub-hashes at every 0.2 mil within ±2 mil only (length 0.1, thickness 0.7)
- Numbered labels 1-5 in all four directions
- Christmas tree below center: 10 rows at 1 mil spacing, widths flaring 0.5 → 4.0 mil
- Wind-hold dots every 0.5 mil along each tree row
- Numbered drops at 2/4/6/8/10 mil

Generator: `scripts/gen_mil_tree_flare.py`. Maps to ~31 scope entries via `scope_reticle_options.json`.

### `loadout_moa_tree_flare` — FFP MOA Christmas tree

**155 elements.** Targets the modern tactical FFP MOA reticle family: Nightforce MOAR-T, Leupold TMOA-HD, Vortex EBR-7D MOA, Burris SCR2 MOA.

Geometry:
- Crosshair stadia at ±20 MOA
- Center crosshair gap 0.25 MOA with a 0.25 MOA floating dot
- Major hashes at every 5 MOA (length 2.0, thickness 1.5)
- Minor hashes at every 2 MOA (length 1.0, thickness 1.0)
- Sub-hashes at every 1 MOA within ±10 MOA (length 0.5, thickness 0.7)
- Numbered labels 5/10/15/20 in all four directions
- Christmas tree below center: 8 rows at 5 MOA spacing (5/10/15/20/25/30/35/40), widths flaring 2 → 16 MOA
- Wind-hold dots every 2 MOA along each tree row
- Numbered drops at 10/20/30/40 MOA

Generator: `scripts/gen_moa_tree_flare.py`. Maps to ~8 scope entries.

### `loadout_sfp_lpvo_chevron` — SFP LPVO chevron with BDC ladder

Carried from `new_sfp_reticles.json` (pre-authored). Targets Trijicon BAC Triangle (ACOG family), Primary Arms ACSS-equivalent LPVO reticles. Calibrated at 4x magnification for the BDC ladder.

Geometry: SFP chevron at center, BDC drop dots at 200/300/400/500 yd holdovers, range estimation brackets on horizontal stadia.

### `loadout_sfp_hunter_duplex` — SFP hunting duplex with thick outer / thin inner posts

Carried from `new_sfp_reticles.json` (pre-authored). Public-domain duplex pattern, LoadOut artwork. Targets generic hunting scopes: Leupold Duplex, Vortex V-Plex, Bushnell Multi-X, Burris Plex. Note: `subtension_origin: "public_domain"` because the duplex design itself is public-domain.

---

## Algorithm bug fixes (history)

The derivation algorithm has accumulated four important bug fixes. They're all in `scripts/derive_subtensions.py`:

1. **Center dot ring filtering** — earlier versions conflated the center dot with surrounding rings (e.g. Red Dot + Ring reticles have two `dot` elements at origin: the center dot AND the ring). Fix: filter `not e.get('open', False)` AND take the smallest radius.

2. **Mode-tie convergence between Python and Dart** — when two hash intervals appear equally often, Python's original took the first found; Dart took the smaller. Fix: explicit `min(candidates)` sort in Python to match Dart.

3. **Float clustering for tier detection** — authoring noise (0.150 vs 0.150001) caused the algorithm to treat near-identical lengths as separate tiers. Fix: cluster lengths within `epsilon = 1e-3` before tier assignment.

4. **Epsilon-based zero check** — earlier versions used `e['x'] == 0` to test "at origin," which fails for floating-point-noisy authored values. Fix: `abs(e['x']) < 1e-9`.

5. **Tree-row vs vertical-stadia disambiguation** — earlier versions counted vertical-stadia hashes as tree rows because they were at `y > 0`. Fix: filter tree elements by `|x| > epsilon AND y > 0` (off-axis position required).

6. **Hash tier identification by length, not interval mode** — earlier versions tried to derive major/minor tiers from interval clustering, which fails when authoring uses uniform hashes. Fix: cluster by hash `length` attribute first, then derive interval per tier.

If you find a 7th bug, document it here and patch the algorithm. The algorithm is no longer in the production path (per the v2 architectural simplification), but it remains the authoritative cross-check during authoring.

---

## Visual regression — the verification suite

Every time you add or modify a reticle, run the visual regression suite:

```sh
python scripts/render_all_reticles.py --output docs/reticle_previews/
```

This regenerates SVG previews of every reticle in the catalog. Compare against the previous version in git. Any unintended visual changes indicate a regression.

For high-impact reticles in the top-35 verification set, also run the manufacturer-comparison check:

```sh
python scripts/compare_to_manufacturer.py loadout_mil_tree_flare --against EBR-7D-MRAD.pdf
```

This overlays the LoadOut reticle against the manufacturer's published reticle diagram and produces a side-by-side PNG for manual review. The check is qualitative (a human looks at it) but the tool helps.

---

## Common authoring mistakes

**Mistake 1 — placing hashes at non-grid coordinates.** Always use exact grid positions: 0.5, 1.0, 1.5, etc. Don't author "0.499" or "1.001" — even if the visual is fine, the algorithm flags it as authoring drift.

**Mistake 2 — forgetting the floor of the gap.** The center crosshair gap (`centerDotSizeUnits`) and the dot radius are independent. The gap is the distance between the inner ends of the four crosshair arms. The dot's radius is its size. They CAN match (gap 0.06 with dot diameter 0.06 = the dot exactly fills the gap), but they don't have to.

**Mistake 3 — tree row spacing inconsistent with row count.** If you say `treeRowSpacingUnits: 1.0` and `treeRowCount: 10`, the tree extends to row 10 (10 mil drop), and your `treeDepthUnits` should be 10.0. The algorithm checks this consistency.

**Mistake 4 — tree row widths array doesn't match row count.** If `treeRowCount: 10`, `treeRowWidthsUnits` must have exactly 10 entries. The algorithm flags off-by-one errors.

**Mistake 5 — thickness conventions mismatched.** A major hash with thickness 1.0 visually disappears against a minor hash with thickness 1.0. Use the convention table above. Major is always thicker than minor; minor is always thicker than sub.

**Mistake 6 — surfacing trademarked reticle names.** A LoadOut original named `loadout_ebr7d_clone` is a regression. Reticle IDs should describe the LoadOut artwork's character (`loadout_mil_tree_flare`), not name the manufacturer reticle being targeted. Trademarked names live ONLY in `calibration_provenance.reticle_name` (for `published_spec` reticles) and in `scopes.json`'s `stock_reticle` field (internal metadata).

**Mistake 7 — not bumping the manifest.** Catalog changes don't reach existing installs without a manifest bump. ALWAYS bump.

**Mistake 8 — generating elements directly in `reticles.json`** instead of via a generator script. Hand-edited element arrays are unmaintainable; the next person can't tell why hashes are where they are. Always commit the generator alongside the elements.

---

## Dual-reticle scope authoring (Option A pattern)

Some scopes ship in **multiple reticle variants on the same hardware
platform** — e.g., the Nightforce ATACR 5-25x56 F1 sells with either
a Mil-XT (mil) or a MOAR-T (MOA) reticle; the Leupold Mark 5HD
7-35x56 sells with Tremor3 (mil) or TMOA-HD (MOA); the Leupold
VX-Freedom 3-9x40 sells with a Duplex or a Boone & Crockett BDC.

The `scope_reticle_options.json` schema today is 1:1 — one
`scope_id`, one default `reticle_id`. Modelling the dual-variant
reality requires either a schema change (list-valued `reticle_ids`)
or a second scope row per variant. **v2.3 uses the second-scope-row
pattern (Option A).** Decision rationale lives at
`docs/DECISIONS.md` D-018.

### Authoring convention

When you add a dual-reticle scope:

1. **Author the base scope row** for the default variant (whichever
   reticle ships as the manufacturer's catalog default, typically
   the mil version on tactical scopes or the duplex on hunting
   scopes). Slug: `<manufacturer_slug>_<model_slug>` per the
   standard rule.

2. **Author a SECOND scope row** for the alternate variant, with the
   variant name appended to the `model_name` field:
   - Nightforce ATACR 5-25x56 F1 → "ATACR 5-25x56 F1 MOAR-T" for
     the MOA variant.
   - Leupold Mark 5HD 7-35x56 → "Mark 5HD 7-35x56 TMOA".
   - Leupold VX-Freedom 3-9x40 → "VX-Freedom 3-9x40 Boone &
     Crockett".

   Slug: `<base_slug>_<variant_suffix>` lowercased with the
   variant name's special characters collapsed to underscores.
   Examples: `nightforce_optics_atacr_5_25x56_f1_moar_t`,
   `leupold_mark_5hd_7_35x56_tmoa`,
   `leupold_vx_freedom_3_9x40_boone_crockett`.

3. **All other scope-row fields** (focal_plane, magnification,
   objective, tube, weight, length, eye relief, etc.) are usually
   identical between variants since the underlying hardware is the
   same. The only fields that should differ:
   - `id` (the variant slug)
   - `model_name` (with the variant suffix)
   - `reticle_class` (e.g., 'mil' for the mil variant, 'moa' for
     the MOA variant)
   - `click_value_mil` / `click_value_moa` (mil variants click in
     mil; MOA variants click in MOA — only one of these is non-null
     per row)
   - `stock_reticle` (e.g., "MOAR-T", "TMOA-HD", "Boone & Crockett")
   - `notes` (call out the dual-reticle pattern explicitly)

4. **Pair each scope row with its own `scope_reticle_options.json`
   entry** mapping the new variant scope_id to the appropriate
   LoadOut reticle. The base row keeps its existing mapping; the
   new variant gets the alternate reticle:
   - `_moar_t` row → `loadout_moa_tree_flare`
   - `_tmoa` row → `loadout_moa_tree_flare`
   - `_boone_crockett` row → `loadout_hunting_bdc`

5. **Add the variant to `test/reticle_mapping_top35_test.dart`'s
   `_top35` reference list** if it's an Appendix G entry. Use the
   `model_name` exactly as authored (with the variant suffix); the
   test's fuzzy-match normalisation handles whitespace / hyphens
   automatically.

### Picker UX

The user types "Mark 5HD 7-35x56" in the picker; the autocomplete
shows both rows (`Mark 5HD 7-35x56` and `Mark 5HD 7-35x56 TMOA`).
Precision shooters search for their specific reticle variant — this
is the expected interaction model. Don't try to collapse the rows
in the picker UI; the disambiguation is part of the feature, not a
bug.

### When NOT to use this pattern

If a manufacturer sells a scope in three or more reticle variants
(some Vortex Razor configurations ship in 4+ reticle options), the
second-scope-row pattern becomes noisy. v2.3 stays at the 2-variant
limit per scope; a 3+ variant scope is a candidate for the future
list-valued `reticle_ids` schema change (deferred per D-018's
trade-off analysis).

---

## When all else fails

Read `assets/seed_data/README.md` first — it covers the basics this guide assumes.

Read `lib/widgets/scope_daytime_backdrop.dart` for the actual rendering code. Tracing through the painter for a specific reticle is often the fastest way to understand why something looks wrong.

If a published manufacturer spec is contradictory or ambiguous (some manufacturers publish two different values for the same reticle's subtensions in different documents), default to the one in the most recent product brochure. Document the discrepancy in the reticle's `notes` field.

If you're stuck, the LoadOut maintainer prefers questions to silent guesses. The cost of asking is much lower than the cost of shipping a broken reticle to users.
