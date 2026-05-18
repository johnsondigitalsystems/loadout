# Ballistipedia Reference — Range Statistics and Extreme Spread

> **Purpose:** Reference data for BFP Phases 19 (group statistics), 20 (σ factor — closes audit C-2), 21 (single-aim hit probability), 22 (Hit Probability Map / WEZ).
>
> **What this file is:** Extracted numerical data (facts) plus original analytical commentary. Source pages are cited by URL; source spreadsheet is cited by name. This file does NOT redistribute Ballistipedia page text or the original Excel file.
>
> **License posture:** Ballistipedia's pages display no explicit content-license grant (the Disclaimers page is empty as of access date; About ShotStat unchecked). Default copyright assumption applies. Numerical values are facts and not copyrightable; original arrangements (page text, the Excel file's layout) are. This file extracts the former and cites the latter without reproducing it.

---

## Source record

| Source | URL | Access date | Last edited |
|---|---|---|---|
| Range Statistics article | `https://ballistipedia.com/index.php?title=Range_Statistics` | 2026-05-17 | 13 April 2024 |
| Extreme Spread article (marked "draft, needs review") | `https://ballistipedia.com/index.php?title=Extreme_Spread` | 2026-05-17 | 9 January 2024 |
| `Sigma1RangeStatistics.xls` spreadsheet | Linked from Range Statistics article as `Media:Sigma1RangeStatistics.xls` | 2026-05-17 | Last saved 30 November 2014 by author "David" (David Bookstaber per Ballistipedia maintainer record) |
| Figure of Merit page | `https://ballistipedia.com/index.php?title=Figure_of_Merit` | 2026-05-17 | Page does not exist on the wiki |
| ShotStat:General disclaimer | Footer link from any page | 2026-05-17 | Page is empty (no content) |

Wiki host: `ballistipedia.com`, MediaWiki software branded "ShotStat".

---

## 1. What "Extreme Spread" means

Per the Extreme Spread article on Ballistipedia (cited above):

**Extreme Spread (ES)** is the **2D Euclidean distance** between the two shots in a group that are farthest apart. Formally, for a set of n shots at coordinates `(h₁,v₁), (h₂,v₂), ..., (hₙ,vₙ)`:

```
ES = max over all pairs (i, j):  sqrt((x_i - x_j)² + (y_i - y_j)²)
```

Standing assumptions (per the Extreme Spread article):
- Shots are approximately Rayleigh-distributed around the center of impact
- Horizontal and vertical dispersion are independent (σ_h ≈ σ_v)
- No fliers (outliers excluded)

ES is a **measurement on shots actually placed on the target** — no center-of-impact or σ calculation is needed to compute ES itself. Estimating σ FROM ES is a separate inference problem (see §3 below).

The Extreme Spread article notes itself as "a draft and needs review." The 2D Euclidean distance definition above is universal across the literature (Litz, Sierra, Ballistipedia, NRA test protocols) and matches the Excel file's `Extreme Spread` column — so the definition is reliable independent of the draft-status note.

---

## 2. The three Ballistipedia range statistics

Ballistipedia distinguishes three measurements on a shot group, each scaling linearly with σ:

| Statistic | Definition | Geometric character |
|---|---|---|
| **Extreme Spread (ES)** | Max 2D pairwise distance between any two shots | Maximum chord of the group — a 2D measurement |
| **Diagonal (D)** | Diagonal of the bounding rectangle around the group | Bounds-of-bounding-box — 2D measurement, larger than ES on average |
| **Figure of Merit (FoM)** | `(max_x − min_x + max_y − min_y) / 2` (per standard usage in Ballistipedia's data) | Average of horizontal and vertical bounding extents — equivalent in scaling to 1D range statistics (matches Tippett 1925 d_n) |

These three are different measurements producing different numerical values for the same group. LoadOut's hit probability service uses one of them (almost certainly ES; verification deferred to BFP Phase 20 Group A).

---

## 3. Estimating σ from a single observed ES

The Rayleigh scaling property: if ES is the extreme spread of n shots from a bivariate normal distribution with per-axis standard deviation σ, then

```
E[ES_n(σ)] = σ × E[ES_n(σ=1)]
```

So given an observed ES of n shots:

```
σ_hat = ES_observed / E[ES_n(σ=1)]
```

where `E[ES_n(σ=1)]` is the expected value of ES for n shots at σ=1, which comes from the Sigma1RangeStatistics spreadsheet.

This is a **method-of-moments estimator**. Robust alternatives use the median:

```
σ_hat_median = ES_observed / median(ES_n(σ=1))
```

The two are close (mean and median of ES differ by only ~2% due to slight positive skew). The choice between them is a usage convention; the spreadsheet provides both.

---

## 4. Numerical data extracted from `Sigma1RangeStatistics.xls`

The following values are facts extracted from the linked spreadsheet. Cited as: *Data extracted from `Sigma1RangeStatistics.xls`, available via the Range Statistics article on Ballistipedia (URL above), authored by David Bookstaber, last saved 30 November 2014.*

The spreadsheet contains two sheets — `Moments` (Mean, StDev, Skew, Kurtosis for each measure) and `Quantiles` (seven quantile bands for each measure) — covering group sizes n = 2 through n = 100. The values reproduced below are at σ = 1; for any other σ, multiply by σ.

### 4.1 Extreme Spread — the load-bearing column for LoadOut

| n (shots in group) | ES Mean (σ=1) | ES Median (σ=1) | ES StDev (σ=1) |
|---|---|---|---|
| 2 | 1.772475 | 1.665466 | 0.926860 |
| 3 | 2.408692 | 2.337820 | 0.892325 |
| 4 | 2.792686 | 2.733707 | 0.856932 |
| **5** | **3.066255** | **3.012307** | 0.826528 |
| 6 | 3.275918 | 3.224410 | 0.804376 |
| 7 | 3.444070 | 3.394366 | 0.783613 |
| 8 | 3.586174 | 3.536971 | 0.767364 |
| 9 | 3.705391 | 3.656699 | 0.753379 |
| 10 | 3.811162 | 3.763395 | 0.741687 |
| 11 | 3.903902 | 3.857037 | 0.731031 |
| 12 | 3.988186 | 3.941047 | 0.720567 |
| 13 | 4.063824 | 4.015986 | 0.712318 |
| 14 | 4.133272 | 4.085857 | 0.704597 |
| 15 | 4.196044 | 4.149149 | 0.696698 |
| 16 | 4.255408 | 4.208376 | 0.690763 |
| 20 (approx) | ~4.46 | ~4.42 | — |
| 25 (approx) | ~4.66 | ~4.62 | — |
| 50 (approx) | ~5.20 | ~5.17 | — |
| 100 | 5.61 (last row of spreadsheet) | ~5.59 | — |

(Approximate values shown for n ≥ 20 are estimates from the spreadsheet trend; precise values available in the original file.)

LoadOut's default group size is N=5. For N=5: **ES Mean = 3.066, ES Median = 3.012.**

### 4.2 Figure of Merit — for reference / cross-check

| n | FoM Mean (σ=1) |
|---|---|
| 2 | 1.128511 |
| 3 | 1.692529 |
| 4 | 2.058441 |
| **5** | **2.326247** |
| 6 | 2.535161 |
| 7 | 2.704965 |
| 8 | 2.847609 |
| 9 | 2.969436 |
| 10 | 3.077263 |

These are mathematically equivalent to Tippett 1925's d_n values for the expected range of n samples from a unit normal distribution. **This column is NOT the right divisor for 2D ES estimation in LoadOut.** It is reproduced here only to anchor the analytical note in §5.

### 4.3 Diagonal — for completeness, not currently used by LoadOut

| n | Diagonal Mean (σ=1) | Diagonal Median (σ=1) |
|---|---|---|
| 2 | 1.772475 | 1.665466 |
| 3 | 2.539577 | 2.471452 |
| 4 | 3.033385 | 2.980106 |
| **5** | **3.396416** | **3.350081** |
| 10 | 4.421905 | 4.382873 |

---

## 5. Critical analytical note — the v1 audit's `d_n = 2.33` recommendation

The `loadout_ballistics_audit_v1.zip` package (delivered 2026-05-12) identified C-2: a defect in `hit_probability_service.dart` (line 220) and `hit_probability_map_service.dart` (lines 499, 586) where σ is computed as `groupMoa / 4`. The audit recommended replacing the divisor `4` with `2.33`, citing Ballistipedia.

**Direct verification of Ballistipedia's spreadsheet does not support this recommendation.** Specifically:

| Source claimed by audit | Actual value at N=5 in spreadsheet |
|---|---|
| Audit: "Ballistipedia d_n = 2.33 for N=5" | ES Mean = **3.066** (3.012 median) |
| | FoM Mean = **2.326** (the only column matching 2.33) |

The audit's 2.33 matches the **Figure of Merit** column in `Sigma1RangeStatistics.xls`, not the Extreme Spread column. Figure of Merit is a different statistic from Extreme Spread (see §2). For 2D Extreme Spread — which is what LoadOut measures (per the standard definition in §1 and the standard convention in the ballistics literature) — the correct divisor at N=5 is approximately **3.066** (mean-based estimator) or **3.012** (median-based estimator).

### 5.1 Impact on the C-2 fix

| Scenario | σ formula at N=5 | σ vs ES-Mean-correct |
|---|---|---|
| Original code | σ = ES / 4 | ~24% too small |
| Audit's proposed fix | σ = ES / 2.33 | ~32% too large |
| Apparent correct (ES Mean) | σ = ES / 3.066 | baseline |
| Apparent correct (ES Median) | σ = ES / 3.012 | within ~2% of baseline |

The audit's proposed fix does not restore correctness — it inverts the sign of the error from "σ understated" to "σ overstated." The ~33pp hit-probability overstatement at the audit's example case (1000yd, 18×30 silhouette, ES=2.5") becomes a similarly-sized understatement, not zero.

### 5.2 Disposition

This finding is **not yet locked** — three scenarios remain possible until BFP Phase 20 Group A executes hand-verification against the LoadOut code:

1. **LoadOut measures 2D ES** (standard convention, expected outcome) → correct divisor is 3.066 (mean) or 3.012 (median). Phase 20 fix is `/4 → /3.066` or `/4 → /3.012`.
2. **LoadOut measures FoM internally** (unusual, but possible) → audit's 2.33 is correct. Phase 20 fix is `/4 → /2.326` as audit recommended.
3. **LoadOut measures 1D per-axis ES** (unusual for shot dispersion, possible if the code splits horizontal and vertical separately) → 1D Tippett d_n=2.326 applies. Same numerical answer as scenario 2 but for different reason.

Phase 20 Group A's first task: read `hit_probability_service.dart` and the surrounding `group_stats_service.dart` to determine which statistic the code consumes. The "groupMoa" variable name strongly suggests 2D ES, but verification at the code level is required before locking the divisor.

---

## 6. BFP Phase Mapping

| Phase | Use of this reference |
|---|---|
| **Phase 19** (Group Statistics service) | §1 (ES definition) and §2 (three statistics) inform what the service should compute and report |
| **Phase 20** (σ factor — closes C-2) | §3 (estimation method), §4.1 (ES Mean/Median values), §5 (audit error analysis). Group A determines which statistic LoadOut measures; Group B locks the divisor and applies the fix. |
| **Phase 21** (Single-aim hit probability) | Consumes σ from Phase 20. §4.1 anchor values are used in test fixtures (the cardinal-case example: 18×30 silhouette / 1000yd / ES=2.5" / N=5 is re-derived under the corrected divisor). |
| **Phase 22** (WEZ / Hit Probability Map) | Same as Phase 21 — consumes σ; cardinal-case anchors re-derived |

---

## 7. Hand-Verification Protocol for Claude Code (during Phase 20)

When BFP Phase 20 executes, Claude Code follows this protocol (carried from BFP plan §0.6):

1. **Locate the formula in this reference.** §3 gives the σ-from-ES formula; §4.1 gives the numerical anchors at N=5.
2. **Locate the LoadOut implementation.** Read `hit_probability_service.dart` line 220, and `hit_probability_map_service.dart` lines 499 and 586. Determine: (a) what statistic does the input represent (ES, FoM, or other)? (b) what is the current divisor (per the C-2 finding, it is `4`)?
3. **Resolve the statistic question.** If the input is 2D ES, proceed with divisor 3.066 (mean) or 3.012 (median). If something else, re-evaluate via §5.2.
4. **Hand-derive the corrected σ** at one cardinal case (suggested: ES = 2.5" at 1000 yd / N=5, 18×30 silhouette — the v1 audit's example). Show the arithmetic chain.
5. **Compute the resulting hit probability change.** The audit's claim of 33pp overstatement is anchored to `σ = ES / 4`. Under the corrected divisor, the hit probability shifts by a different amount; document this in the group report.
6. **Update test fixtures** at every site that consumed the old `/4` divisor. Identify them by grep before changing; document the count in the group report.
7. **Add Phase 20 anchor tests** at N=3, N=5, N=10 using the ES Mean values from §4.1. Each test fixture's expected σ value should be hand-derivable using the chain in step 4.

The operator decides "mean vs median" between Group A and Group B. If undecided at execution time, default to **ES Mean (3.066 for N=5)** as that's the method-of-moments / MLE-style estimator and matches more conventional statistical practice. Median is preferred only if the operator wants robust-to-flier behavior at the cost of slight bias.

---

## 8. Citation block (paste-ready for code comments)

For LoadOut code comments that cite Ballistipedia (per `Ballistics.md` §11 citation discipline):

```dart
// Sigma estimation from Extreme Spread per Ballistipedia Range Statistics
// methodology. ES Mean at sigma=1 for N shots from Sigma1RangeStatistics.xls
// (Bookstaber, available at https://ballistipedia.com/index.php?title=Range_Statistics).
// For N=5: divisor = 3.066255 (mean) or 3.012307 (median).
// See docs/references/ballistipedia_range_statistics.md for the full table
// and the analytical note on the v1 audit's incorrect 2.33 recommendation.
```

For BFP plan / audit-trail references:

> Ballistipedia, Range Statistics article (https://ballistipedia.com/index.php?title=Range_Statistics, accessed 2026-05-17, last edited 13 April 2024) and `Sigma1RangeStatistics.xls` (Bookstaber, 30 November 2014). Numerical d_n table for Extreme Spread at σ=1.

---

## 9. What's NOT in this file (and why)

- **Verbatim Ballistipedia page text** — not redistributed under default-copyright assumption
- **The `Sigma1RangeStatistics.xls` file itself** — not redistributed; cite by URL. Future verifiers re-download from Ballistipedia.
- **The on-page chart image** — not reproduced
- **Pages we didn't capture** — Diagonal (page exists but not consumed by Phase 19–22), Projectile Dispersion Classifications (referenced in See Also but content not pulled), About ShotStat (not visited; may contain license terms that would loosen the posture above)
- **CEP / Mean Radius derivations** — Ballistipedia covers these on separate pages; if BFP Phase 19 or 21 ends up needing them, separate capture from those pages would happen at that time

If a future BFP phase needs additional Ballistipedia material, the same protocol applies: visit page → confirm content → extract facts → cite by URL → don't redistribute page text.

---

## 10. Verification status

| Item | Verified | By |
|---|---|---|
| ES = 2D Euclidean distance | ✓ | Extreme Spread page screenshot 2026-05-17 |
| ES Mean / Median values for N=2 through N=100 | ✓ | Direct read of `Sigma1RangeStatistics.xls` via pandas + xlrd, 2026-05-17 |
| Audit's 2.33 ≠ ES column; 2.33 = FoM column | ✓ | Numerical comparison in §5 |
| LoadOut measures 2D ES (vs FoM, vs 1D ES) | ⏳ | Pending Phase 20 Group A code-level verification |
| Mean vs median estimator choice | ⏳ | Pending operator decision in Phase 20 |
| Hit probability change under corrected divisor | ⏳ | Pending Phase 21 hand-derivation |

⏳ items are explicit BFP Phase 20 / Phase 21 deliverables.

---

## End of reference
