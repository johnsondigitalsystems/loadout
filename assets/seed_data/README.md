# LoadOut seed data — maintenance handbook

This directory holds every reference catalog the app ships with: scopes, reticles, cartridges, powders, bullets, primers, brass, firearms, targets, the scope-to-reticle mapping, and every other read-only piece of data the user interacts with. **The whole directory is the source of truth.** The app seeds an on-device SQLite database from these files at first launch, and re-syncs on cold start when Firebase Storage has newer copies (see `Cloud sync` section below).

This handbook is for whoever has to add a scope, add a reticle, fix a target, or update a mapping. Read it before editing anything in this directory.

---

## File map

```
seed_data/
├── README.md                    ← this file
├── manifest.json                Version vector for every other JSON below
├── scopes.json                  194 scope models across 30 manufacturers
├── reticles.json                52 reticles (21 LoadOut original + 21 public-domain + 10 calibrated-to-published-spec)
├── scope_reticle_options.json   Maps every scope to its default LoadOut reticle (1:1 per scope_id)
├── targets.json                 65 targets (49 conventional + 16 animal silhouettes)
├── target_racks.json            9 rack configurations (KYL × 2, Equal × 2, Decreasing × 2, Pepper Popper, IDPA, Texas Star)
├── cartridges.json              203 cartridges with full SAAMI specs
├── manufactured_ammo.json       19 curated factory loads (Range Day "Common Loads" picker)
├── factory_loads.json           4,143 factory ammo SKUs (reference lookup)
├── powders.json                 Powder reference catalog
├── bullets.json                 Bullet reference catalog (projectiles only)
├── primers.json                 Primer reference catalog
├── brass.json                   Brass reference catalog
├── firearms.json                Firearm reference catalog (40 brands)
├── firearm_parts.json           Firearm parts catalog (50+ brands)
└── drag_curves/
    └── curves.json              300+ Hornady 4DOF measured Cd-vs-Mach curves
```

**Architectural rules:**
1. One file per concept. No splitting one entity across files.
2. One row per entity. Entity uniqueness enforced by `id` (where present) or `(manufacturer, model)` tuple.
3. One source of truth per field. No duplicated fields across files. If two files reference the same entity, one is canonical and the other is a foreign-key reference.
4. Neutral technical language only — no "safe" / "fallback" / "liability" / "IP risk" / "legal" terminology anywhere in field names, file names, comments, or commit messages. Use "base catalog," "extended catalog," "subtension calibration sourcing," "functional equivalence," "neutral defaults."
5. JSON, not YAML. Strict double-quoted strings, no trailing commas, no comments in the canonical files (comments live in source `.dart` and `.py` files that consume them).

---

## scopes.json — the scope catalog

**194 unique scopes across 30 manufacturers.** This is the catalog the user picks from in the scope picker. The count returned to 194 after Phase 5 added 11 new rows (5 Class A→B promotions verified as current SKUs, 3 Class B confirmed catalog gaps including the Hensoldt ZF 3.5-26x56 substitute for the non-existent ZF 5-25x56, and 3 Class C dual-reticle splits for ATACR MOAR-T / Mark 5HD TMOA / VX-Freedom Boone & Crockett).

### Schema

```jsonc
{
  "manufacturer": "Vortex Optics",
  "model_name": "Razor HD Gen III 6-36x56 FFP",
  "focal_plane": "first",                  // "first" | "second" | "fixed"
  "magnification_min": 6,                  // numeric, required
  "magnification_max": 36,                 // numeric, required (equals min for fixed-power)
  "objective_diameter_mm": 56,             // optional
  "tube_diameter_mm": 34,                  // optional
  "weight_oz": 45.5,                       // optional
  "parallax_min_yd": 25,                   // optional
  "adjustment_unit": "mrad",               // "mrad" | "moa" | null
  "click_value_mil": 0.1,                  // optional, populated for ballistic-grade scopes
  "click_value_moa": null,
  "max_elevation_mil": 36.1,
  "max_windage_mil": 17.4,
  "eye_relief_in": 3.7,
  "fov_at_100yd_ft": 17.8,                 // REQUIRED — see FOV backfill below
  "fov_source": "manufacturer",            // "manufacturer" | "class_estimate" | "unlimited"
  "reticle_class": "switchable",           // "switchable" | "fixed" | null
  "stock_reticle": "EBR-7D MOA/MRAD",      // internal metadata, NOT surfaced to user
  "source_url": "https://vortexoptics.com/...",
  "verified_at": "2026-05-11",
  "notes": null
}
```

**Required fields (no nulls):** `manufacturer`, `model_name`, `focal_plane`, `magnification_min`, `magnification_max`, `fov_at_100yd_ft` (or `null` only with `fov_source: "unlimited"`).

**Field semantics that matter:**
- `focal_plane: "fixed"` is used for red dots, holographic sights, reflex sights, iron sights — anything without a magnified eyepiece.
- `reticle_class: "switchable"` means the scope ships in multiple reticle variants (e.g. mil and MOA versions of the same scope body). The actual reticle options live in `scope_reticle_options.json`.
- `stock_reticle` is **internal metadata only**. It exists so Claude Code can classify the scope's typical reticle and choose the right LoadOut mapping. It is never surfaced to the user. Trademarked reticle names (EBR-7D, H-59, Mil-XT) appear here but nowhere else.
- `fov_source: "unlimited"` is for red dots / holographic — the eyepiece doesn't constrain FOV the way a magnified scope does. `fov_at_100yd_ft` is `null` in this case.

### Adding a new scope

1. Open `scopes.json`. Add a new entry following the schema above. Keep the file sorted alphabetically by `manufacturer`, then by `model_name`.
2. Research and fill every field. For `fov_at_100yd_ft`, use the manufacturer's published spec — set `fov_source: "manufacturer"`, `source_url` to the spec sheet, and `verified_at` to today's date in ISO format.
3. If the manufacturer doesn't publish FOV, use the class-fallback table below. Set `fov_source: "class_estimate"`.
4. Write a `scope_reticle_options.json` entry for this scope (see that section below).
5. Run `flutter analyze`.
6. Commit. Push.
7. **Cloud sync step:** run the Firebase deployment commands documented in `Cloud sync` at the bottom of this README. New scopes don't reach existing installs until the manifest is bumped and the bucket is updated.

### FOV class-fallback table

When a manufacturer doesn't publish FOV, use these typical values by magnification range:

| Magnification | FOV @ 100yd, low end (ft) | FOV @ 100yd, high end (ft) |
|---|---|---|
| 1-4x / 1-6x (LPVO low-end) | 110 | 18 |
| 1-8x / 1-10x (LPVO high-end) | 105 | 13 |
| 2.5-15x / 3-15x | 41 | 7.2 |
| 3-18x / 4-20x | 35 | 6.5 |
| 5-25x | 23 | 4.5 |
| 6-36x / 7-35x | 19 | 3.8 |
| Fixed 6x | — | 17.6 |
| Fixed 10x | — | 10.5 |
| Red dots / holographic | — | null (set `fov_source: "unlimited"`) |

Target distribution: ≥85% `manufacturer`, ≤15% `class_estimate`. Audit quarterly.

---

## reticles.json — the reticle catalog

**52 reticles total.** Every reticle the app can render lives here. The catalog is **LoadOut-original artwork and public-domain designs**, with a third bucket of reticles whose subtensions are **calibrated to a manufacturer's published spec** (the `published_spec` `subtension_origin`) but whose artwork remains LoadOut-original. We do not reproduce any manufacturer's reticle pixel-for-pixel.

Distribution by `subtension_origin`:

- **21 `original`** — LoadOut-authored archetypes (mil tree, MOA tree, MOA hash, hunting BDC, combat BDC, holographic ring, red-dot variants).
- **21 `public_domain`** — traditional patterns predating modern reticle patents (duplex, German #1/4/4A/8, plex, crosshair variants, post-and-crosshair, mil-dot, etc.).
- **10 `published_spec`** — LoadOut-original artwork whose subtensions are calibrated against a manufacturer's published specification. Each row carries a `calibration_provenance` JSON blob with `manufacturer`, `reticle_name`, and source URL fields. UI renders the "Calibrated to [Manufacturer] [Reticle Name]" disclaimer on these (see `lib/widgets/reticle_renderer.dart` `ReticleInteroperabilityLabel`).

### Schema

```jsonc
{
  "id": "loadout_mil_tree_flare",
  "model": "Christmas Tree Flare (Mil)",
  "family": "loadout_originals",           // "loadout_originals" | "public_domain"
  "nativeUnit": "mil",                      // "mil" | "moa"
  "maxExtentUnits": 5.0,                    // max distance from center for hashes
  "manufacturer": "LoadOut",
  "subtension_origin": "original",          // "original" | "published_spec" | "public_domain"
  "subtensions": {
    "centerDotSizeUnits": 0.06,
    "majorHashIntervalUnits": 1.0,
    "minorHashIntervalUnits": 0.5,
    "subHashIntervalUnits": 0.2,
    "treeRowSpacingUnits": 1.0,
    "treeRowCount": 10,
    "treeRowWidthsUnits": [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.0, 4.0],
    "treeDepthUnits": 10.0
  },
  "calibration_provenance": null,           // populated only when subtension_origin == "published_spec"
  "notes": "FFP mil Christmas tree with flaring branch widths (0.5 to 4.0 mil) and sub-tier hashes (0.2 / 0.5 / 1.0 mil)...",
  "elements": [ /* 179 line/hash/dot/number elements */ ]
}
```

### The three values of `subtension_origin`

This field tells the disclaimer system which variant to render beneath the reticle name.

**`"original"`** — LoadOut-authored design with subtensions per LoadOut's own authoring convention. We made up both the artwork AND the subtensions. Most LoadOut reticles fall here.
- Disclaimer rendered: *"Original LoadOut design. Subtensions per LoadOut authoring convention."*
- `calibration_provenance` field is `null`.

**`"published_spec"`** — LoadOut-authored artwork, with subtensions calibrated to match a manufacturer's publicly-published reticle specification. We made up the artwork; the subtension values come from the manufacturer's spec sheet.
- Disclaimer rendered: *"Original LoadOut artwork. Subtensions calibrated to match {manufacturer}'s published specifications. Not affiliated with or endorsed by {manufacturer}."*
- `calibration_provenance` is populated:
  ```jsonc
  {
    "manufacturer": "Sig Sauer",
    "reticle_name": "BDX-R1",
    "published_url": "https://sigsauer.com/...",
    "verified_at": "2026-05-08"
  }
  ```
- The `manufacturer` field in the calibration block is what fills the `{manufacturer}` placeholder in the disclaimer.

**`"public_domain"`** — A reticle design that's been industry-standard since the 1960s with no manufacturer IP attached. Examples: Mil-Dot (USMC), Plex (under many names: Leupold Duplex, Bushnell Multi-X, Vortex V-Plex, etc.), German #4, Crosshair.
- Disclaimer rendered: *"Public-domain reticle design ({designName}). Subtensions per standard specification."*
- The `{designName}` placeholder is filled from the `model` field.
- `calibration_provenance` is `null`.

### `subtensions` field — what each key means

These values are what the Range Day Realistic painter and ballistic math read. **Each value is authored, not computed.** The `scripts/derive_subtensions.py` helper proposes values from the elements array, but a human reviews and edits before committing.

| Key | Meaning | Units |
|---|---|---|
| `centerDotSizeUnits` | Diameter of the center aiming point (dot or crosshair gap) | mil or MOA per `nativeUnit` |
| `majorHashIntervalUnits` | Distance between numbered/major reference hashes | same |
| `minorHashIntervalUnits` | Distance between secondary tier hashes (typically half the major) | same |
| `subHashIntervalUnits` | Distance between fine sub-hashes within the inner working area | same; `null` if reticle doesn't have a sub-hash tier |
| `treeRowSpacingUnits` | Vertical distance between successive Christmas-tree rows | same; `null` if reticle has no tree |
| `treeRowCount` | Number of tree rows below center | integer; `0` if no tree |
| `treeRowWidthsUnits` | Half-width of each row (array, one per row); flaring tree if values increase | array of numbers; `[]` if no tree |
| `treeDepthUnits` | Total tree depth (deepest row below center) | same; `null` if no tree |

### `elements` array — what gets rendered

Every reticle has an `elements` array describing every line, hash, dot, number, chevron, and rectangle that draws the reticle. The renderer iterates over this array and draws each element in the reticle color (default black on the daytime backdrop).

Element types:

```jsonc
// LINE — straight segment from (x1, y1) to (x2, y2)
{"type": "line", "x1": -5.0, "y1": 0, "x2": -0.06, "y2": 0, "thickness": 1.0}

// CROSSHAIR — same as line, semantically distinct (for clarity)
{"type": "crosshair", "x1": 0, "y1": -5.0, "x2": 0, "y2": -0.06, "thickness": 1.0}

// DOT — filled (open: false) or hollow (open: true) circle at (x, y) with radius
{"type": "dot", "x": 0, "y": 0, "radius": 0.03, "open": false}

// HASH — perpendicular tick at (x, y) with given length and thickness
// If y == 0, hash is vertical (on horizontal stadia). If x == 0, hash is horizontal.
{"type": "hash", "x": 1, "y": 0, "length": 0.4, "thickness": 1.5}

// NUMBER — text label at (x, y)
{"type": "number", "x": 1, "y": 0.7, "text": "1", "fontSize": 0.4}

// CHEVRON — triangular pointer; (x, y) is the apex
{"type": "chevron", "x": 0, "y": 3.5, "width": 0.5, "height": 0.3}

// RECTANGLE — filled or stroked rect from (x1, y1) to (x2, y2)
{"type": "rectangle", "x1": -0.5, "y1": 2.0, "x2": 0.5, "y2": 2.5, "filled": false, "thickness": 1.0}
```

**Coordinate convention:** origin (0, 0) is the reticle center. **+x is right, +y is DOWN.** Tree elements below center have positive y. Stadia elements above center have negative y. Units are mil or MOA per the reticle's `nativeUnit`.

### Adding a new reticle

There are three patterns:

#### Pattern A — clone an existing public-domain reticle

Used for: adding another duplex variant, another mil-dot variant, etc.

1. Open `reticles.json`. Find the reticle you want to clone.
2. Copy the entire entry. Change `id` and `model` to match the new reticle.
3. Edit the `elements` array if visual differences are needed.
4. Set `subtension_origin: "public_domain"`.
5. Update `subtensions` if the visual changed the math.
6. Save. Run `flutter analyze`.

#### Pattern B — author a new LoadOut original

Used for: filling a gap (e.g., a flaring Christmas tree that no existing reticle covers).

1. **Plan the geometry first.** Sketch it on paper or in SVG. Decide:
   - `centerDotSizeUnits` — typically 0.05-0.1 mil or 0.2-0.5 MOA
   - `majorHashIntervalUnits` — typically 1.0 mil or 5.0 MOA
   - `minorHashIntervalUnits` — typically half the major
   - `subHashIntervalUnits` — for sub-tier hashes within the inner working area
   - `treeRowCount` and `treeRowSpacingUnits` — Christmas tree shape (or none)
   - `treeRowWidthsUnits` — uniform or flaring

2. **Write a Python generator** in `scripts/gen_<reticle_id>.py`. Use `scripts/gen_mil_tree_flare.py` as a template. Each generator produces the `elements` array as JSON.

3. **Run the generator** and paste the output into a new reticle entry in `reticles.json`. Set `subtension_origin: "original"`. Populate `subtensions` with the same values you targeted in step 1.

4. **Run the derivation helper** to verify the algorithm agrees with your authored values:
   ```sh
   python scripts/derive_subtensions.py <draft.json>
   ```
   If the derived values disagree with your authored values, either fix the elements (mis-authored geometry) or fix the authored subtensions (mis-stated targets). The derived values should match the authored values within 5%.

5. **Update `scope_reticle_options.json`** to map relevant scopes to the new reticle.

6. **Add a verification screenshot** to `docs/reticle_previews/`. The screenshot is just the rendered reticle on a white background; it goes in the maintenance docs, not the app.

#### Pattern C — calibrate a LoadOut original to a published manufacturer spec

Used for: when a LoadOut original's subtensions should match a specific manufacturer reticle (functional equivalence claim).

1. Author the LoadOut original first (Pattern B).
2. Research the manufacturer's published subtensions. Get a screenshot of the spec sheet, save the URL.
3. Add a `calibration_provenance` block to the reticle entry:
   ```jsonc
   {
     "manufacturer": "Sig Sauer",
     "reticle_name": "BDX-R1",
     "published_url": "https://sigsauer.com/.../BDX-R1-spec-sheet.pdf",
     "verified_at": "2026-05-08"
   }
   ```
4. Change `subtension_origin` from `"original"` to `"published_spec"`.
5. The disclaimer will now read *"Subtensions calibrated to match Sig Sauer's published specifications. Not affiliated with or endorsed by Sig Sauer."*

**Important:** the `calibration_provenance` data is legally defensive. Keep it accurate. The `published_url` should be a real URL pointing at the manufacturer's own documentation. The `verified_at` date should be when you actually checked the URL.

### Removing a reticle

Don't, unless absolutely necessary. Reticle IDs are persistent — user data references them by ID. Removing a reticle breaks every user's saved sessions that used it.

If you must remove one:
1. Find every `scope_reticle_options.json` mapping using the reticle ID.
2. Re-map those scopes to a replacement reticle.
3. Add a migration step that updates user data to use the replacement (in `lib/database/database.dart`'s `MigrationStrategy`).
4. Bump `schemaVersion` and ship the migration before removing the reticle.

---

## scope_reticle_options.json — the mapping layer

This file maps every scope in `scopes.json` to one or more LoadOut reticles. When a user picks a scope, the reticle picker shows the options listed here.

### Schema

```jsonc
{
  "scope_manufacturer": "Vortex Optics",
  "scope_model": "Razor HD Gen III 6-36x56 FFP",
  "reticle_id": "loadout_mil_tree_flare",
  "manufacturer_sku": null,                              // optional, for distinguishing variants
  "is_default": true,                                    // true: this is the picker's default selection
  "notes": "LoadOut archetype mapping for the Razor HD Gen III's typical FFP mil Christmas tree reticle. Original scope-brand reticle name is not surfaced.",
  "recommended_loadout_reticle_id": "loadout_mil_tree_flare"
}
```

**One entry per (scope, reticle) pair.** A scope that ships in both mil and MOA variants has two entries — one with `reticle_id: loadout_mil_tree_flare, is_default: true` and another with `reticle_id: loadout_moa_tree_flare, is_default: false`.

### How the picker uses this file

1. User picks scope `(manufacturer, model)`.
2. The picker queries all entries in this file matching that scope.
3. The default-marked entry's reticle pre-selects.
4. The alternate entries show below as "other options."
5. User can tap any option to switch.

### Adding a mapping

1. Identify which LoadOut reticle is the best functional match for the scope's stock reticle. Reference table:

| Stock reticle pattern | Map to LoadOut reticle |
|---|---|
| Vortex EBR-7D, EBR-7C MRAD; Nightforce Mil-XT, Mil-C; S&B H-59, P4F, GR2ID; Hensoldt SKMR3; modern FFP mil Christmas tree | `loadout_mil_tree_flare` |
| Vortex EBR-2C MRAD; older simpler FFP mil tree | `loadout_mil_tree_christmas` |
| Generic mil-hash FFP without tree (Mil-R, TMR, PR1-MIL) | `loadout_mil_hash` |
| Nightforce MOAR-T; Leupold TMOA-HD; modern FFP MOA Christmas tree | `loadout_moa_tree_flare` |
| Generic MOA-hash FFP (PR1-MOA, MOA Long Range) | `loadout_moa_hash` |
| Sig BDX-R1, BDX-R3 (SFP digital BDC) | `loadout_sfp_moa_drop` |
| Burris Ballistic Plex 5.56; AR-BDC carbine BDC | `loadout_combat_bdc` |
| Bushnell DMR Mil-Dot; SFP mil-dot DMR style | `loadout_dmr_bdc` |
| Leupold CDS-ZL Boone & Crockett; SFP hunting BDC | `loadout_hunting_bdc` |
| Leupold Duplex; Vortex V-Plex; Bushnell Multi-X; any Plex variant | `pd_plex` |
| Mil-Dot (USMC), generic mil dot | `pd_mil_dot_usmc` |
| German #4; bold European hunting reticle | `pd_german_4` |
| Trijicon BAC Triangle; LPVO chevron with BDC ladder | `loadout_sfp_lpvo_chevron` |
| Aimpoint / Trijicon / Sig / Holosun 2 MOA red dot | `loadout_red_dot_2moa` |
| 4 MOA red dot | `loadout_red_dot_4moa` |
| 6 MOA red dot | `loadout_red_dot_6moa` |
| 65 MOA / 68 MOA ring + dot (holographic) | `loadout_holographic_ring` |

2. Add the entry to `scope_reticle_options.json`. Match the existing file's formatting and order (sorted by scope manufacturer then model).
3. If the scope ships in mil + MOA variants, add a second entry for the alternate.
4. Run `flutter analyze`.
5. Commit and run the Firebase sync per the bottom of this README.

### Verifying a mapping after adding it

The mapping is correct if a user picking that scope sees a rendered reticle that visually resembles what they'd see through their actual glass. Sanity-check at three magnifications (low, mid, high) on a representative target.

For high-profile mappings (top-35 verification set, see Appendix G of the engineering brief), do a side-by-side comparison against the manufacturer's published reticle diagram. The LoadOut rendering should match within these tolerances:

- Center dot: ±0.02 mil
- Major hash interval: ±5%
- Minor hash interval: ±10%
- Tree row spacing: ±10%
- Tree row count: ±1 row
- Tree depth: ±1 mil
- Tree shape: must match (flaring vs uniform vs none)

---

## targets.json — the target catalog

**65 targets.** Every target the user can pick for Range Day.

### Schema

```jsonc
{
  "id": "ipsc_full",
  "name": "IPSC Silhouette (Full)",
  "category": "target",                    // "target" | "animal"
  "shape": "silhouette",                   // "rectangle" | "square" | "circle" | "silhouette"
  "shape_id": "ipsc_uspsa_metric",         // for silhouettes: which path to render (see lib/widgets/animal_silhouettes.dart and similar)
  "width_in": 18,                          // physical width in inches
  "height_in": 30,                         // physical height in inches
  "color_hex": "#FFFFFF",                  // primary target color
  "rim_color_hex": "#000000",              // optional outline color
  "default_distance_yd": 100,              // optional, used as setup default
  "category_tags": ["paper", "competition"]
}
```

### The `category` field distinguishes targets from animals

- `category: "target"` — paper, steel, or reactive targets. 49 entries.
- `category: "animal"` — naturalistic animal silhouettes (deer, mule deer, elk, moose, pronghorn, black bear, wild boar, mountain lion, coyote, red fox, rabbit, groundhog, prairie dog standing, wild turkey, pheasant, bigfoot). 16 entries; each is paired with a hand-authored SVG at `assets/silhouettes/animals/<name>.svg`.

The target picker UI shows two sections: "Targets" and "Animals." Renderer uses the row's `width_in` / `height_in` as-is — no runtime override.

### Animal silhouette dimensions and assets

LoadOut ships **16 hand-authored SVG silhouettes** for animal targets. Each lives at `assets/silhouettes/animals/<name>.svg`. The renderer uses the `path_drawing` package to parse all `<path d="...">` attributes in the SVG, combine them into a single Flutter Path, and uniformly scale to fit the target's bounding rect. Multi-path SVGs are supported (e.g. `prairie_dog_standing.svg` has 4 paths). See `docs/RETICLE_AUTHORING_GUIDE.md` for the full Path-from-SVG pipeline.

**Big game (North America):**

| shape_id | Asset file | width_in | height_in | Notes |
|---|---|---|---|---|
| `deer_profile` | `deer.svg` | 60 | 32 | Whitetail buck broadside, antlers visible |
| `mule_deer_profile` | `mule_deer.svg` | 60 | 32 | Mule deer; larger ears, forked tines |
| `elk_profile` | `elk.svg` | 100 | 53 | Bull elk with full antler rack |
| `moose_profile` | `moose.svg` | 120 | 64 | Bull moose, paddle antlers + nose hump |
| `pronghorn_profile` | `pronghorn.svg` | 60 | 32 | Pronghorn antelope, prong horns visible |
| `bear_profile` | `bear.svg` | 60 | 32 | Black bear walking, rounded back |
| `boar_profile` | `boar.svg` | 60 | 33 | Wild boar with prominent shoulder hump |

**Predators:**

| shape_id | Asset file | width_in | height_in | Notes |
|---|---|---|---|---|
| `mountain_lion_profile` | `mountain_lion.svg` | 84 | 45 | Mountain lion, long body and tail |
| `coyote_profile` | `coyote.svg` | 48 | 26 | Coyote standing alert, tail low |
| `fox_profile` | `fox.svg` | 36 | 19 | Red fox standing, full bushy tail |

**Small game and varmint:**

| shape_id | Asset file | width_in | height_in | Notes |
|---|---|---|---|---|
| `rabbit_profile` | `rabbit.svg` | 18 | 10 | Cottontail rabbit, ears up |
| `groundhog_profile` | `groundhog.svg` | 24 | 13 | Groundhog, upright posture |
| `prairie_dog_profile` | `prairie_dog_standing.svg` | 12 | 6 | Prairie dog (standing); multi-path SVG |

**Upland birds:**

| shape_id | Asset file | width_in | height_in | Notes |
|---|---|---|---|---|
| `wild_turkey_profile` | `wild_turkey.svg` | 36 | 19 | Tom turkey, fan tail visible |
| `pheasant_profile` | `pheasant.svg` | 36 | 19 | Ring-necked pheasant, long tail |

**Novelty:**

| shape_id | Asset file | width_in | height_in | Notes |
|---|---|---|---|---|
| `bigfoot_profile` | `bigfoot.svg` | 84 | 46 | Cryptid silhouette for fun |

**Dimensions are realistic broadside body sizes** that approximately match each SVG's natural aspect ratio (typically ~1.85:1 horizontal). These values drive the ballistic-math angular subtension at distance.

### Editing or replacing an animal silhouette

To refine an existing silhouette: open the SVG file in a vector editor (Inkscape, Illustrator, Affinity Designer, or any SVG-aware tool). The constraints are:
- One single `<path>` element with a solid fill (no separate eyes, no inner detail strokes — silhouettes only)
- Path uses standard SVG path commands (M, L, C, Q, A, Z)
- viewBox is preserved
- No external references (no patterns, gradients, filters, or images)

To add a new animal silhouette:
1. Drop the SVG file at `assets/silhouettes/animals/<name>.svg`.
2. Register the shape_id in `AnimalSilhouettes._shapeIdToAsset` (in `lib/widgets/animal_silhouettes.dart`).
3. Add a `targets.json` row with `category: "animal"`, `shape: "silhouette"`, and the new `shape_id`.
4. Add to the preload list in `lib/main.dart` so the silhouette is parsed at startup.
5. Bump `manifest.json` targets version.
6. Sync to Firebase Storage per the Cloud sync section below.

### SVG asset requirements

For consistent rendering, every animal silhouette SVG must:
- Be a single `<path>` element (the parser reads the first path's `d=` attribute and stops)
- Be fully closed (`Z` command at the end of each subpath)
- Use solid fill (the renderer applies the `color_hex` from `targets.json` — the SVG's own fill is ignored)
- Have a sensible viewBox (typically ~1.85:1 landscape; the path's bounds determine the rendered aspect ratio)
- Be under 100 KB on disk (larger files slow first-use parsing)

If an SVG has multiple subpaths (e.g. animal body + separate antler shape), the parser treats them as one logical path with multiple subpaths — Flutter's `Path` handles this correctly. The fill rule defaults to non-zero winding, which works for nested holes (e.g. negative space between legs).

### Why SVG instead of programmatic profiles

Earlier drafts of LoadOut used programmatic point lists (~50 points per animal, normalized to a unit square). The output flattened important geometric features: antlers became zig-zag lines, ears lost their characteristic shapes, fur edges read as polygonal. Hand-authored SVGs preserve the artist's intent at any rendering scale, are easier to refine (replace the file rather than edit coordinates), and have no licensing complications when the artwork is project-lead-owned. See `docs/DECISIONS.md` D-008 for the full rationale.

### IPSC silhouette — the path-fix story

The IPSC USPSA "metric" target had a long-running rendering bug: the head poked above the bounding rect, getting clipped by the scope view.

The fix is in `buildIpscPath(Rect bounds)` in `lib/widgets/scope_daytime_backdrop.dart`. The path is generated from real IPSC dimensions:

- Head: 4" × 6" rectangle
- Neck: 2" × 2" connector
- Shoulders: bevel from neck (2" wide) down to body (12" wide) over 4" of height
- Body: 12" × 12" rectangle
- Foot: bevel from body (12" wide) down to 4" wide over 4" of height
- Total dimensions: 12" wide × 28" tall (aspect 0.4286)

The function scales these to fit the input `bounds` Rect exactly, guaranteeing no overflow.

### Rectangle target labels

Rectangle and square targets show **both dimensions** in the picker and on the Range Day setup card:

```dart
String formatRectangleLabel(Target t) {
  if (t.shape == 'rectangle' || t.shape == 'square') {
    return '${_fmtDim(t.width_in)} × ${_fmtDim(t.height_in)} in';
  }
  if (t.shape == 'circle') {
    return '${_fmtDim(t.width_in)} in';   // circles: diameter only
  }
  return t.name;                            // silhouettes use the name
}
```

### Adding a new target

1. Open `targets.json`. Add a new entry following the schema.
2. Pick `category: "target"` or `category: "animal"`.
3. For silhouettes, you also need to add the path to `lib/widgets/animal_silhouettes.dart` (or, for non-animal silhouettes, to `lib/widgets/target_silhouettes.dart`).
4. Run `flutter analyze`.
5. Add a screenshot of the rendered target to `docs/target_previews/`.
6. Commit and sync to Firebase.

---

## Scene composition rules (Range Day Realistic)

Every target renders in a consistent scene: sky / grass / dirt mound / wooden post / target / reticle overlay. The composition is defined in `lib/widgets/scope_daytime_backdrop.dart` and follows the visual references in `scope_best.png` / `scope_best_comic.png`.

Layout coefficients (relative to view dimensions `W` × `H`):

| Element | Top y | Bottom y | Width | Notes |
|---|---|---|---|---|
| Sky region | 0 | 0.78H | full W | LinearGradient: `#87CEEB` to `#B0DFEC` |
| Grass region | 0.78H | H | full W | Solid `#6B8E23` with 3-4 lighter streaks |
| Dirt mound | 0.82H | 0.92H | 0.18W centered on post | Ellipse, color `#8B6F47` with 30%-rim highlight `#A0855B` |
| Wooden post | bottom-of-target | 0.85H | 0.025W centered | Color `#6B4423`, with 3 darker vertical streaks |
| Target | 0.12H | varies (max 0.55H) | varies | Computed by `computeTargetBounds` — preserves aspect ratio, ≤60% width, ≤50% height usage |

**Top-of-target headroom is required.** Targets MUST be positioned so their top edge is at or below `y = 0.12 * H`. This is the per-design-brief requirement. If a target's natural aspect ratio would push its top above 0.12H when sized to fit, the renderer scales it down until it fits.

**Post seating:** the post visually extends ~40% into the mound for proper seating. The post is drawn AFTER the mound so it appears in front; the mound highlight then occludes the bottom of the post for a layered look.

---

## manifest.json — the version vector

```jsonc
{
  "scopes": { "version": 12, "updated_at": "2026-05-11" },
  "reticles": { "version": 8, "updated_at": "2026-05-11" },
  "scope_reticle_options": { "version": 6, "updated_at": "2026-05-11" },
  "targets": { "version": 4, "updated_at": "2026-05-11" },
  "target_racks": { "version": 1, "updated_at": "2026-01-15" },
  "cartridges": { "version": 3, "updated_at": "2026-04-10" },
  "manufactured_ammo": { "version": 2, "updated_at": "2026-03-22" },
  "factory_loads": { "version": 1, "updated_at": "2026-01-15" },
  "powders": { "version": 2, "updated_at": "2026-04-10" },
  "bullets": { "version": 2, "updated_at": "2026-04-10" },
  "primers": { "version": 1, "updated_at": "2026-01-15" },
  "brass": { "version": 1, "updated_at": "2026-01-15" },
  "firearms": { "version": 1, "updated_at": "2026-01-15" },
  "firearm_parts": { "version": 1, "updated_at": "2026-01-15" }
}
```

This file is the version vector the app's `SeedUpdater` reads on cold start. It compares each file's `version` against the version it last seeded; if the bucket has a higher version, the app downloads the updated file and re-seeds that catalog.

**Bump the version of any file you change.** Failure to bump means users don't get the update.

---

## Cloud sync — Firebase Storage deployment

When you change any file in this directory, the changes don't reach existing users until you:

1. Bump the relevant `version` in `manifest.json`.
2. Update `updated_at` to today.
3. Upload to Firebase Storage:

```sh
# Bulk upload everything (safe — Storage rules block writes unless authenticated)
gsutil -m cp -r assets/seed_data/*.json \
  gs://loadout-precision-reloading.firebasestorage.app/seed_data/

# Also upload the drag curves
gsutil -m cp -r assets/seed_data/drag_curves/ \
  gs://loadout-precision-reloading.firebasestorage.app/seed_data/

# Verify the manifest is present and current
gsutil cat gs://loadout-precision-reloading.firebasestorage.app/seed_data/manifest.json
```

Alternative: Firebase Console → Storage → upload the changed files manually. Slower but works without a CLI.

### Sync verification round-trip

After deploying, verify on a fresh install:
1. Install the app on a clean simulator with networking enabled.
2. Open and let it complete the first-launch seed.
3. Force-quit.
4. Edit a value in your local catalog (e.g. change the name of a cartridge).
5. Bump that catalog's `version` in the local manifest.
6. Re-upload the manifest only.
7. Relaunch the app twice (first launch downloads + flags; second launch re-seeds from the updated file).
8. Confirm the edited value now shows in the app.

If the round-trip doesn't work, check:
- Storage rules in `storage.rules` grant `read: if true` for `seed_data/*`.
- The manifest's structure exactly matches what `SeedUpdater` expects (test parse).
- The version in the uploaded manifest is greater than the value in the device's `SharedPreferences` (key: `seed_<category>_version`).

### Initial bucket population

For a fresh Firebase Storage bucket:

```sh
firebase deploy --only storage   # deploys storage.rules
gsutil -m cp assets/seed_data/*.json gs://loadout-precision-reloading.firebasestorage.app/seed_data/
gsutil -m cp -r assets/seed_data/drag_curves gs://loadout-precision-reloading.firebasestorage.app/seed_data/
```

After initial population, the bucket and `assets/seed_data/` should mirror exactly. Any future drift is a deployment bug.

---

## When something goes wrong

**"I added a new scope but it doesn't show in the picker."** → You probably forgot to add a `scope_reticle_options.json` entry. The picker only shows scopes that have at least one mapping.

**"I authored a new reticle but the math is wrong."** → Your `subtensions` field doesn't match your `elements` array. Run `python scripts/derive_subtensions.py path/to/reticle.json` to see what the algorithm derives; compare to your authored values; fix one or the other.

**"The IPSC head is clipping again."** → Someone modified `buildIpscPath` and broke the bounds-fit guarantee. The path MUST return geometry strictly inside the input rect. Re-run the IPSC visual regression test.

**"Users on old app versions aren't getting my catalog update."** → Did you bump `manifest.json`'s version? Did you upload the manifest AND the changed file to Storage? Did the user's device actually get the new manifest (check `SharedPreferences` value)?

**"A scope picked the wrong default reticle."** → Open `scope_reticle_options.json`. Find the scope's entries. Check which one has `is_default: true`. Update to point to the right LoadOut reticle.

**"A trademarked reticle name (EBR-7D etc.) appeared in user-facing UI."** → That's a regression. Trademarked names live only in two places: the `stock_reticle` field of `scopes.json` (internal metadata) and the `calibration_provenance.reticle_name` field of `reticles.json` (when `subtension_origin == "published_spec"`). Neither field should ever reach the user-facing rendering. Audit the rendering path.

---

## Editing this README

When you change the data model or add new patterns, update this README in the same commit. The README is the source of truth for "how the catalogs work" — if it's out of date, the next person hits the same bugs.

Sections that need updating when you...
- Add a new file → File map; new top-level section
- Change a schema → That file's section; the affected pattern
- Add a new reticle pattern → "Adding a new reticle" subsection
- Add a new target shape → targets.json section; scene composition rules
- Change deployment → Cloud sync section
