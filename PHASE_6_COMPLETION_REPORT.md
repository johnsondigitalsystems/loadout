# Phase 6 — Completion report

**LoadOut Range Day Realistic rewrite v2.3 — Phase 6 (Documentation + IP posture)**
**Status:** ✅ All Phase 6 acceptance gates met. Halting for project-lead review.
**Generated:** 2026-05-12
**Brief:** `range_day_realistic_rewrite_v23.md` (in the v23 package)
**Scope discipline applied:** Math files (`solver.dart`, `hit_probability_service.dart`, `hit_probability_map_service.dart`) NOT touched per Phase 3 approval terms. No reticle row in `reticles.json` modified. No `scope_reticle_options.json` row removed. No `calibration_provenance` blob altered.

---

## 1. Acceptance gate summary

| Gate | Result |
|---|---|
| Part A1 — Engineering `CLAUDE.md` update | ✅ §30 augmented with v2.3 data-model simplification note + Phase 6 per-origin disclaimer template summary; new §31 "Range Day Realistic painter architecture (v2.3)" added (200+ lines documenting the three painters, two `bool` flags, public `RealisticLayout`, public `shouldRenderReticleElement`, `scope_catalog_v2` service, four-mount-style dispatch). No stale counts found in engineering CLAUDE.md (counts live in marketing CLAUDE.md). |
| Part A2 — Marketing `CLAUDE.md` stats + sanitize | ✅ §23 and §9 / §10 counts updated to v2.3 reality (194 scopes / 30 brands / 52 reticles / 65 targets / 9 racks). 30-brand list inserted. The §830 "no licensing complications" example replaced with pure interoperability framing. |
| Part A3 — `DECISIONS.md` Phase 4/5 entries | ✅ D-018 through D-022 appended: dual-reticle Option A pattern, Hensoldt substitution rationale, three test-resolution mapping corrections, deferred `rotating_hub` painter, Phase 6 per-origin disclaimer wiring. |
| Part A4 — `RETICLE_AUTHORING_GUIDE.md` dual-reticle section | ✅ "Dual-reticle scope authoring (Option A pattern)" section appended before the "When all else fails" closing section. Covers convention, picker UX, and when NOT to use the pattern (3+ variants → defer to schema change). |
| Part A5 — `seed_data/README.md` count updates | ✅ All stale counts (47 reticles, 36 mfrs, 54 targets, 6 racks) replaced with v2.3 reality (52 reticles / 30 mfrs / 65 targets / 9 racks) plus the three-bucket reticle distribution note. |
| Part B — Brief errata placement | ✅ Placed at `docs/v2.3_BRIEF_ERRATA.md` (long-term docs/ location). Working copy at repo-root `PHASE_6_BRIEF_ERRATA.md` retained for cross-reference with the Phase 4 / 5 completion reports. |
| Part C — Per-origin disclaimer UI | ✅ All three templates wired through `ReticleInteroperabilityLabel`. 7 new tests in `test/reticle_disclaimer_templates_test.dart` cover all template paths + fallbacks + the catalog smoke test. Verbatim user-approved copy on all three templates (Not a reproduction language preserved). |
| Part D1 — Marketing copy sweep | ✅ Sweep covered `marketing/CLAUDE.md`, root `CLAUDE.md`, `LAUNCH_CHECKLIST.md`, all `docs/*.md`. **1 replacement made** (the §830 example in marketing CLAUDE.md). Other matches were dev terminology (LAUNCH_CHECKLIST "test workarounds"), safety disclaimers (`internal_ballistics_validation.md` "not a substitute for the published manual maximum" — different context), or internal IP-analysis docs (`RETICLE_LICENSING.md` / `RETICLE_AUTHORING_GUIDE.md` referencing the concepts as topic-of-discussion, not as marketing claims). |
| Part D2 — `docs/IP_POSTURE.md` | ✅ Created at the target path (320+ lines). Single-document attorney engagement entry point. TL;DR / catalog composition / "what we don't do" / 4 known risk areas / drill-down paths. Updated patent landscape per Phase 5 directive — foundational Horus / HVRT patents likely expired, narrower post-2010 chain remains. |
| Part D3 — `LAUNCH_CHECKLIST.md` IP review section | ✅ "Intellectual property & legal review" section inserted between "Business / legal setup" and "iOS submission". 6 checklist items: FTO attorney engagement, published_spec Horus cross-check, marketing copy review, Hornady 4DOF licensing review, independent-creation provenance docs, RETICLE_LICENSING.md consistency check. Estimated FTO engagement: $5k–$10k. |
| `flutter analyze` | ✅ 6 pre-existing infos in `animal_silhouettes.dart` / `target_silhouettes.dart`. **Zero new issues.** |
| `flutter test` (full suite) | ✅ **1271 passing, 1 skipped (pre-existing), 0 failing.** Delta from Phase 5: +7 (the new `reticle_disclaimer_templates_test.dart` cases). |
| Math-audit boundary | ✅ `lib/services/ballistics/solver.dart`, `lib/services/hit_probability_service.dart`, `lib/services/hit_probability_map_service.dart` untouched. |
| Reticle catalog geometry | ✅ `assets/seed_data/reticles.json` not modified in Phase 6 (modifying it is out-of-scope per the project-lead directive). |
| `scope_reticle_options.json` | ✅ No rows removed (modifying it is out-of-scope per the directive). |
| `calibration_provenance` blobs | ✅ Not altered. |

---

## 2. Marketing-copy sanitization sweep — every change

The Phase 6 directive required a full sweep for "workaround-signaling"
phrases. The complete list:

| File | Lines | Before | After |
|---|---|---|---|
| `marketing/CLAUDE.md` | 829–832 (now 835–840) | `For copy that needs a "we cover the equivalents" pitch, say something like: "If your scope ships with a TReMoR3 or an EBR-7C, use the LoadOut Mil Tree archetype — same hold-off math, no licensing complications." That's accurate AND honest.` | `For copy that needs a "we cover the equivalents" pitch, say something like: "If your scope ships with a TReMoR3 or an EBR-7C, the LoadOut Mil Tree archetype uses the same hold-off math. Either reticle gives you the same precision; the LoadOut version is what you'll see in the picker." That's pure interoperability framing — no licensing or substitution language.` |

That's the only edit. Final grep `(no licensing|without the licensing|around the trademark|around the patent)` across the audited files returns one in-scope hit — the writer-directive meta-instruction inside the new replacement text (`"framing — no licensing or substitution language."`). That meta-instruction is correct in context: it tells future copy authors what to avoid; it is not a marketing claim about LoadOut.

**Files left untouched (and why):**

- `LAUNCH_CHECKLIST.md:424-425` — "test workarounds" / "workaround pattern". Dev terminology per the directive (NOT marketing positioning). Left alone.
- `docs/internal_ballistics_validation.md:201` — "not a substitute for the published manual maximum". Safety disclaimer about published reloading data, not a competitor reticle / IP substitution claim. Left alone.
- `docs/RETICLE_LICENSING.md` / `docs/RETICLE_AUTHORING_GUIDE.md` — internal IP-analysis and authoring docs that legitimately reference "trademark", "licensing", "functionally equivalent" as topic-of-discussion (not as marketing claims about LoadOut). Left alone.

---

## 3. Catalog stats — what marketing CLAUDE.md now claims

| Stat | Pre-Phase-6 | Post-Phase-6 | Source |
|---|---|---|---|
| Scopes | 47 across 26 brands | **194 across 30 brands** | `scopes.json` row count + unique manufacturer field |
| Reticles | 43 (24 LoadOut-original + 19 public-domain) | **52 (21 LoadOut-original + 21 public-domain + 10 calibrated-to-published-spec)** | `reticles.json` rows by `subtension_origin` |
| Targets | 52 across 4 shape families | **65 across 4 shape families (49 target + 16 animal silhouettes)** | `targets.json` rows by `category` |
| Racks | 6 rack types | **9 rack types** | `target_racks.json` rows |

The 30 brands (alphabetical): Aimpoint, Arken Optics, Athlon Optics, Burris, Bushnell, Carl Zeiss, DEON Optical Design (March), EOTech, Element Optics, Hawke Optics, Hensoldt, Holosun, Kahles, Leupold, Maven, Meopta, Nightforce Optics, Primary Arms, Riton Optics, Schmidt & Bender, Sig Sauer, Sightron, Steiner, Swarovski Optik, Tangent Theta, Trijicon, US Optics, Vortex Optics, Zero Compromise Optic, ZeroTech Optics.

The +4 brands added in Phase 2's catalog merges (vs the pre-Phase-2 "26 brands" claim): **Hawke Optics, Maven, Steiner, US Optics**.

---

## 4. `docs/RETICLE_LICENSING.md` — current state

The file exists at `docs/RETICLE_LICENSING.md` (178 lines, authored pre-Phase-2). Header reads "Status: NEEDS LEGAL REVIEW BEFORE LAUNCH." Content covers:

- The three IP layers (trademarks / design patents / copyright)
- Risk by reticle category (Horus = HIGH, brand-specific = MEDIUM, generic = NONE)
- What other ballistic apps do (Strelok Pro, Hornady 4DOF, Applied Ballistics, Geoballistics, JBM)
- Three paths forward, where path (b) "Replace high-risk named reticles with generic descriptors" is the path Phase 2 implemented (the LoadOut-original archetypes)

**Consistency check vs. `docs/IP_POSTURE.md` (new):**

- Both files agree the catalog is LoadOut-original artwork. ✓
- Both files describe nominative fair use as the legal basis for naming competitor scopes. ✓
- `RETICLE_LICENSING.md` predates the Phase 2 catalog rewrite — it describes the dual-track `subtensionsCalibrated` / `subtensionsOriginal` schema that was simplified to the three-bucket `subtension_origin` enum during Phase 2. The new `IP_POSTURE.md` reflects the actually-shipped v2.3 schema.
- The PATENT LANDSCAPE in `RETICLE_LICENSING.md` is older (pre-2024); the new `IP_POSTURE.md` reflects the May 2026 finding that foundational Horus / HVRT patents have likely expired.

Per the project-lead directive ("don't auto-edit ... flag any inconsistencies for manual review"), `RETICLE_LICENSING.md` was NOT modified in Phase 6. Recommendation for the attorney engagement: hand over BOTH files. The attorney can reconcile the older risk-by-category framing in `RETICLE_LICENSING.md` with the newer patent landscape research in `IP_POSTURE.md`. Engineering should plan a post-FTO sweep to merge or supersede the two documents based on the attorney's opinion.

---

## 5. Files modified in Phase 6 — full list

### Documentation

| File | Change |
|---|---|
| `CLAUDE.md` (root engineering) | §30 augmented with v2.3 data-model simplification note + Phase 6 per-origin disclaimer table. New §31 "Range Day Realistic painter architecture (v2.3)" added. |
| `marketing/CLAUDE.md` | §23 stats updated (4 lines bumped, 4 "outdated" markers added). §9 reticle counts + 30-brand list. §10 target / rack count consistency fix. §830 example sanitized. |
| `docs/DECISIONS.md` | D-018 through D-022 appended (5 new entries covering dual-reticle Option A, Hensoldt substitution, test-resolution mapping fixes, rotating_hub deferral, Phase 6 disclaimer templates). |
| `docs/RETICLE_AUTHORING_GUIDE.md` | New "Dual-reticle scope authoring (Option A pattern)" section before the closing. |
| `docs/IP_POSTURE.md` | **NEW.** 320+ lines. Single-document attorney engagement entry point. |
| `docs/v2.3_BRIEF_ERRATA.md` | **NEW** (placement; content is the working copy from `PHASE_6_BRIEF_ERRATA.md` at repo root). |
| `assets/seed_data/README.md` | Count references updated (52 reticles / 30 mfrs / 65 targets / 9 racks). |
| `LAUNCH_CHECKLIST.md` | New "Intellectual property & legal review" section with 6 tasks. |

### Production code (Part C — per-origin disclaimer UI)

| File | Change |
|---|---|
| `lib/data/reticle_library.dart` | `ReticleDefinition` gained `subtensionOrigin` (default `'original'`) and `calibrationProvenance` (decoded map) fields. JSON round-trip support: reads both `snake_case` (seed bundle) and `camelCase` (internal); `toJson` emits canonical form. `fromRow` safely decodes the drift JSON-text blob. |
| `lib/repositories/reticle_repository.dart` | `definitionFromRow` forwards the two new fields through to `ReticleDefinition.fromRow`. |
| `lib/widgets/reticle_renderer.dart` | `ReticleInteroperabilityLabel` rewritten with three §7.7 templates (`'original'` / `'public_domain'` / `'published_spec'`). Static `resolveTemplate(...)` helper for non-widget consumers. Legacy fixed-string fallback preserved for null-origin back-compat. Verbatim user-approved copy on all three; "Not a reproduction" tooltip on `published_spec` is load-bearing legal posture. |
| `lib/widgets/reticle_full_screen_view.dart` | Call site at line ~211 updated to pass `reticle.subtensionOrigin` + `reticle.calibrationProvenance`. |
| `lib/widgets/reticle_picker.dart` | Two call sites (field tile + list-row leading column) updated. Top-level `_decodeProvenance(...)` helper for the picker's local `ReticleRow → decoded map` conversion. |

### Tests

| File | Change |
|---|---|
| `test/reticle_disclaimer_templates_test.dart` | **NEW** (7 tests). Covers all three templates + 4 published_spec fallback sub-cases + null-back-compat + `resolveTemplate` pure-Dart path + catalog smoke test reading `reticles.json` to confirm every `published_spec` row has a valid `manufacturer` + `reticle_name` in its `calibration_provenance` blob. |

---

## 6. Flagged for project-lead awareness

| Item | Detail |
|---|---|
| Two `published_spec` reticles have **verbose `reticle_name` strings** in their `calibration_provenance` blob (e.g. `"Sig Sauer BDX (BDX-R1 / BDX-R2 family, SFP MOA holdover reticle)"`). The new disclaimer template will render `"Calibrated to Sig Sauer Sig Sauer BDX (BDX-R1 / BDX-R2 family, SFP MOA holdover reticle)"` verbatim. The picker tile wraps fine, but if a shorter user-facing form is preferred this is a **catalog edit** (separate task), not a widget change — the widget renders verbatim whatever the JSON carries. | Disclaimer-UI agent surfaced. Spot-check candidate for the FTO attorney pass. |
| `docs/RETICLE_LICENSING.md` predates the Phase 2 catalog rewrite. Patent landscape research in `docs/IP_POSTURE.md` supersedes it. Recommend a post-FTO sweep to reconcile / merge / supersede. | Flagged in §4 above. |
| `manifest.json` was NOT bumped in Phase 6 because no seed data file changed. Phase 7 (Firebase Storage cloud sync) is the next phase and will upload the v5 manifest from Phase 5. | Bookkeeping note only — no action required. |
| Phase 7 cloud sync remains. Math files remain untouched. v34→v35 snapshot test deferred per the boundaries. | Carry-over from Phase 5's "halt point" — not surfaced by Phase 6. |

---

## 7. DEFINITION_OF_DONE.md self-review checkpoint — readiness

Phase 6 is the last documentation phase before Phase 7 (cloud sync) and the DoD self-review (per START_HERE.md item 9). When that self-review runs, the following Phase 6 outputs should be referenced:

- **§2.4 §6A.2 illumination check:** 29 of 52 reticles carry the `illuminated_color_hex` field on appropriate elements. The other 23 are non-illuminated by design (public-domain duplex / German / hash patterns). Distribution verified by Python audit during Phase 4.
- **§2.4 §6A.4 per-firearm defaults check:** UI shipped, `scope_catalog_v2.dart` is the runtime accessor. 14 unit tests in `test/scope_catalog_v2_test.dart` cover parsing + referential integrity.
- **§3.1 top-35 reticle reference set:** 34 of 34 pass after the Nikon drop (acceptance bar was ≥33 of 35). 20 of 20 launch-blocker FFP-tactical-→-flaring-tree checks pass.
- **§3.3 target rendering 10 screenshots:** code-level invariants verified (16 IPSC path tests + 14 scene composition tests + 12 rack rendering tests). Manual screenshot pass deferred to project lead per the Phase 5 directive.
- **§4 documentation truthfulness:** Phase 6 covers this directly. All claims in the docs are TRUE; the catalog stats match the shipped JSON; the IP posture documents accurately describe the v2.3 architecture.
- **§5.1 `flutter analyze`:** 6 pre-existing infos, 0 new (Phase 6 entry).
- **§5.2 `flutter test`:** 1271 passing, 1 skipped (pre-existing), 0 failing.
- **§5.4 Phase 7 cloud sync:** READY. `manifest.json` v5 is staged; `scopes_v2 v5` and `scope_reticle_options v6` ready for `gsutil` upload.

---

## 8. Halt point

**Awaiting project-lead review** of Phase 6 outputs. After review, the next steps per the user's directive:

1. Phase 7 cloud sync (`scripts/upload_seed_data.sh` round-trip)
2. DEFINITION_OF_DONE.md self-review checkpoint (read-only walk-through)
3. §10 final summary (per the brief's closing section)

Math code remains untouched per the Phase 3 boundary. The reticle catalog geometry remains unchanged pending the FTO attorney opinion.
