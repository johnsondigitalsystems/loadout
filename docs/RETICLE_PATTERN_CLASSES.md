# Reticle Pattern Classes — Derived Taxonomy

**Created by:** VFP Phase 1 Group D (per the operator-approved D-6
adaptation: `reticles.json` has **no** `pattern_class` field, so the
geometric class is *derived* from `family` + `elements[].type` +
`nativeUnit` + `model` and documented here as the reference taxonomy).
**Catalog:** `assets/seed_data/reticles.json`, 52 rows (verified
`jq length` = 52). **Focal-plane field is `type`** (`ffp` | `sfp` |
`fixed`), not `focal_plane`.

This taxonomy is the reference for the "pattern-class verification"
audit step: each row's `elements` must structurally contain the
required element types for the class it belongs to. All 52 rows were
checked and are structurally coherent with exactly one class below
(see `RETICLE_DATA_AUDIT.md` for per-row dispositions).

## Element-type vocabulary

`crosshair` (line/post — thickness encodes duplex/German posts),
`dot` (center or ring/circle glyph), `hash` (graduated tick),
`holdover` (BDC drop mark), `number` (floating label), `line`
(tree spine, flare variant).

## The 11 classes

| Class | Definition | Required element types | Typical `type` / `nativeUnit` | Members (ids) |
|---|---|---|---|---|
| `mil_tree` / `moa_tree` | Christmas-tree precision grid: crosshair + center dot + graduated hash ladder + windage holdover tree + floating numbers | crosshair(or line)+dot+hash+holdover+number | ffp / mil or moa | loadout_default_mil_tree, loadout_mil_tree_compact/medium/dense/christmas, loadout_default_moa_tree, loadout_moa_tree_compact/medium/dense/christmas, loadout_mil_tree_flare, loadout_moa_tree_flare |
| `mil_hash` / `moa_hash` | Hash crosshair, **no** holdover tree | crosshair+dot+hash(+number) | ffp / mil or moa | loadout_mil_hash, loadout_moa_hash, pd_mil_hash_generic |
| `mil_dot` | Classic dotted crosshair at 1-mil spacing | crosshair+dot | sfp/ffp / mil | pd_mil_dot_usmc, pd_dotted_crosshair |
| `duplex_plex` | Thick outer posts tapering to a thin center crosshair (± center dot) | crosshair(+dot) | sfp / moa | pd_plex, loadout_sfp_hunter_duplex |
| `fine_crosshair` | Plain crosshair, line-weight variants, no posts/dots | crosshair | sfp / moa | pd_crosshair_fine, pd_crosshair_medium, pd_crosshair_heavy |
| `german` | German #1/#4/#4A/#8 — heavy posts (1–3) + fine top axis (± center dot) | crosshair(+dot) | sfp / moa | pd_german_1, pd_german_4, pd_german_4a, pd_german_8, loadout_sfp_german_4 |
| `post` | Single / picket / post+crosshair / post+dot aiming post | crosshair(+dot) | sfp / moa | pd_post_crosshair, pd_picket_post, pd_post_dot |
| `ring_dot` | Aiming circle/ring + center dot or cross (incl. holographic & iron-sight ring) | dot(+crosshair) | fixed / moa | pd_circle_dot, pd_circle_cross, pd_iron_sight_ring, loadout_red_dot_circle, loadout_holographic_ring |
| `dot` | Single illuminated aiming dot only | dot | fixed / moa | loadout_red_dot_2moa, loadout_red_dot_4moa, loadout_red_dot_6moa |
| `chevron` | Chevron / diamond aiming point (± BDC posts + numbers) | crosshair(chevron glyph)(+holdover+number) | sfp/fixed / moa, mil, bdc | pd_chevron, pd_diamond_center, loadout_bdc_chevron_556_nato, loadout_bdc_chevron_762_nato, loadout_bdc_chevron_300_blk, loadout_sfp_lpvo_chevron |
| `bdc_holdover` | Center aim + bullet-drop holdover dots/posts/numbers (no full tree) | (crosshair or dot)+holdover+number | sfp/ffp/fixed / mil, moa, bdc | loadout_sfp_mil_drop, loadout_sfp_moa_drop, loadout_bdc, loadout_combat, loadout_combat_bdc, loadout_dmr_bdc, loadout_hunting_bdc, loadout_sfp_bdc_300yd |

## Notes

- `mil_tree`/`moa_tree` flare variants (`loadout_mil_tree_flare`,
  `loadout_moa_tree_flare`) substitute a `line` spine for the
  `crosshair` — a stylistic variant within the class, not a
  mismatch.
- German-pattern posts and chevrons are modeled as thick `crosshair`
  elements (thickness/length encode the post weight / chevron legs);
  this is the catalog's representation convention, structurally
  coherent for the class.
- `type` (focal plane) is a per-row design attribute for `original` /
  `public_domain` rows (no external "true" focal plane for a generic
  pattern). For `published_spec` rows it must match the cited source
  reticle's focal plane — verified per row in the audit dossier (one
  focal-plane concern surfaced: D-9e).
- Adding a new reticle: assign it to exactly one class above and
  ensure its `elements` carry that class's required element types;
  extend this taxonomy if a genuinely new geometric class is added.
