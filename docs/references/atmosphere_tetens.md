# Atmosphere Reference — Tetens Vapor Pressure Formula

> **Purpose:** Reference data for BFP Phase 6 (atmosphere audit). LoadOut's atmosphere model uses the Tetens vapor pressure formula to compute saturation vapor pressure for humid-air density correction. This file is the authoritative reference for that formula during BFP execution.
>
> **Sourced from:** `docs/references/nws_vapor_pressure.pdf` (committed to the repo as a U.S. federal work — public domain). Cross-referenced against Wikipedia (CC-BY-SA) and primary published sources (Tetens 1930, Murray 1967).
>
> **License posture:** NWS PDF is U.S. federal work, public domain — committed directly. Wikipedia citations are CC-BY-SA with attribution. Tetens 1930 (German journal) and Murray 1967 (J. Applied Meteorology) are academic publications cited by full bibliographic reference but not redistributed.

---

## Source record

| Source | Location / URL | Type | License |
|---|---|---|---|
| NWS / NOAA vapor pressure documentation | `docs/references/nws_vapor_pressure.pdf` | U.S. National Weather Service technical doc (El Paso office wxcalc) | Public domain (U.S. federal work) |
| Source URL | `https://www.weather.gov/media/epz/wxcalc/vaporPressure.pdf` | — | — |
| Wikipedia "Tetens equation" | `https://en.wikipedia.org/wiki/Tetens_equation` | Encyclopedia (cross-reference) | CC-BY-SA 4.0, attribution required |
| Tetens, O. (1930) | *Z. Geophys 6: 297-309* | Primary publication, original German | Public domain (>95 years old) |
| Monteith & Unsworth (2013) | *Principles of Environmental Physics*, 4th ed | Modern textbook citing Tetens 1930 | Commercial; cited bibliographically only |
| Murray, F.W. (1967) | *J. Applied Meteorology 6: 203-204* (DOI: 10.1175/1520-0450(1967)006<0203:OTCOSV>2.0.CO;2) | Academic article, over-ice extension | Academic; cited bibliographically only |
| AMS Glossary "saturation vapor pressure" | `https://glossary.ametsoc.org` | Concept definition only (not formula) | American Meteorological Society |

Access date for all online sources: 2026-05-17.

---

## 1. The Tetens formula

### Above 0°C (over liquid water)

From NWS:
```
es = 6.11 × 10^((7.5 × T) / (237.3 + T))      [mb or hPa; T in °C]
```

From Tetens 1930 / Monteith & Unsworth via Wikipedia:
```
P = 0.61078 × exp((17.27 × T) / (T + 237.3))   [kPa; T in °C]
```

**These two are mathematically identical.** The differences are unit/base conventions only:

- `6.11 mb = 0.611 kPa` (NWS uses a rounded coefficient)
- `6.1078 mb = 0.61078 kPa` (Tetens' precise original coefficient)
- `10^x = exp(x · ln 10)`, and `7.5 · ln 10 = 17.269` ≈ `17.27`
- `1 kPa = 10 mb = 10 hPa`

The NWS-vs-Tetens coefficient difference (`6.11` vs `6.1078`) introduces a uniform multiplicative error of `+0.036%` across all temperatures (see anchor table §3). For the audit purposes, both forms are acceptable; Phase 6 verification just needs to confirm LoadOut's code is internally consistent (one form, matching units).

### Below 0°C (Murray 1967, over ice)

```
P = 0.61078 × exp((21.875 × T) / (T + 265.5))   [kPa; T in °C]
```

Equivalent base-10 form:
```
es = 6.1078 × 10^((9.5 × T) / (T + 265.5))      [mb or hPa; T in °C]
```

Different coefficient pair (`21.875/265.5` for ice vs `17.27/237.3` for water). At T < 0°C, saturation vapor pressure over ice is materially lower than over supercooled liquid water — about 9% lower at -10°C, 18% lower at -20°C, 25% lower at -30°C. This is the well-known Bergeron–Findeisen mechanism in cloud physics; it's physical, not a rounding artifact.

For ballistics: Phase 6 verification needs to determine which form (or both) LoadOut consumes. Typical small-arms shooting is above freezing, so the over-water form covers most use cases. Cold-weather and high-altitude shooters need the over-ice form for accurate humid-air density at low temperatures.

### Stated accuracy

Per Monteith & Unsworth (cited by Wikipedia): *"Values of saturation vapour pressure from Tetens' formula are within 1 Pa of exact values up to 35°C."* That's a tolerance of ±0.001 kPa or ±0.01 mb across the typical 0–35°C range — adequate for ballistics-grade humid-air corrections.

---

## 2. Inputs and what LoadOut probably needs

For atmospheric density correction in `atmosphere.dart`, the typical computation chain:

1. **Air temperature T** (from environment, °C)
2. **Relative humidity RH** (from environment, percent)
3. **Saturation vapor pressure es(T)** — Tetens formula
4. **Actual vapor pressure e** = `RH/100 × es(T)`
5. **Humid air density correction** applied to dry-air ICAO/station-pressure value

The dewpoint form (`6.11 × 10^((7.5 × Td) / (237.3 + Td))`) gives actual vapor pressure directly if dewpoint Td is the input rather than RH. NWS uses the dewpoint form because it's their standard meteorological measurement.

LoadOut's exact input convention (RH or Td) should be verified in Phase 6 Group A.

---

## 3. Cardinal-case anchor table

Hand-derived values at cardinal temperatures. Computed at planning time; verified arithmetic; suitable for Phase 6 test fixtures. All values in **mb (= hPa)** for direct comparison; multiply by 0.1 for kPa.

### Over water (Tetens, NWS form)

| T (°C) | NWS form (6.11) | Tetens precise (6.1078) | Δ NWS vs Tetens |
|---:|---:|---:|---:|
| 0 | 6.1100 | 6.1078 | +0.036% |
| 10 | 12.2833 | 12.2789 | +0.036% |
| 20 | 23.3894 | 23.3809 | +0.036% |
| 25 | 31.6863 | 31.6749 | +0.036% |
| 30 | 42.4416 | 42.4263 | +0.036% |
| 35 | 56.2408 | 56.2206 | +0.036% |
| 50 | 123.3949 | 123.3504 | +0.036% |

The Δ is uniform across all temperatures because the coefficient `6.11` vs `6.1078` is a pure multiplicative factor.

### Over ice (Murray 1967)

| T (°C) | Murray over-ice | Tetens over-water (for comparison) | Ratio (ice/water) |
|---:|---:|---:|---:|
| -30 | 0.3764 | 0.5018 | 0.750 |
| -20 | 1.0279 | 1.2462 | 0.825 |
| -10 | 2.5945 | 2.8571 | 0.908 |
| 0 (boundary) | — | 6.1078 | — |

At T = 0°C, the two formulas converge to the same value (both forms give the triple-point vapor pressure). Below 0°C they diverge.

### Hand-derivation chain (one example, T = 25°C, NWS form)

```
es = 6.11 × 10^((7.5 × 25) / (237.3 + 25))
   = 6.11 × 10^(187.5 / 262.3)
   = 6.11 × 10^0.71483
   = 6.11 × 5.18596
   = 31.686 mb
```

A Phase 6 group report would show this kind of arithmetic chain for each anchor case verified.

---

## 4. BFP Phase Mapping

| Phase | Use of this reference |
|---|---|
| **Phase 6 — Atmosphere Model** | Primary consumer. Group A verifies LoadOut's `atmosphere.dart` Tetens implementation against this reference (which coefficient pair? which form? what units?). Group B (or later) verifies cardinal cases hit the anchor values in §3. |
| **Phase 7 — Drag tables** | Indirect — drag depends on air density which depends on humid-air correction which depends on Tetens. Phase 7 doesn't audit Tetens directly but consumes its output. |
| **Phase 15 — Zero atm vs runtime atm separation** | Same as Phase 6 — both atmospheres use Tetens; Phase 15 verifies they're applied correctly in sequence. |

---

## 5. Hand-Verification Protocol for Claude Code (during Phase 6)

When BFP Phase 6 executes (carried from BFP plan §0.6):

1. **Read `atmosphere.dart`** — find the saturation-vapor-pressure function. Note:
   - Coefficient (6.11, 6.1078, or other)
   - Algebraic form (10^/base-10 vs exp/natural-log)
   - Temperature unit (°C, K, °F)
   - Output unit (mb, hPa, kPa, Pa)
   - Whether the over-ice form is implemented separately, or only the over-water form

2. **Cross-check against this reference's §1 forms.** Confirm LoadOut's implementation is one of the equivalent forms (or document the discrepancy if not).

3. **Hand-derive at three cardinal cases** from §3: T = 0°C, T = 25°C, T = -10°C (if over-ice is supported). Show arithmetic chains.

4. **Compare to the LoadOut output** at the same inputs. Document residuals.
   - If residual > 0.05% — investigate. Most likely cause: coefficient mismatch between 6.11 and 6.1078, or temperature-unit conversion bug.
   - If residual > 1% — surface as a finding.

5. **Note the 6.11 vs 6.1078 question.** Some practitioners use the rounded NWS form (6.11); others use the precise Tetens form (6.1078). LoadOut should use ONE consistently and the code comment should cite which source it follows. If LoadOut uses 6.1078, cite Tetens 1930 / Wikipedia / Monteith & Unsworth. If LoadOut uses 6.11, cite NWS.

6. **Note the over-ice question.** If LoadOut's humidity correction is intended for all atmospheric conditions, the over-ice form is needed at T < 0°C. If LoadOut only supports above-freezing shooting (which would be unusual), this is fine to skip but should be documented.

7. **Test fixture re-baselining.** Any existing Phase 6 atmosphere fixtures that consumed prior (possibly wrong) Tetens output get re-baselined against the anchor values in §3.

---

## 6. Phase 6 Group Report Template (relevant excerpt)

```
## Pre-flight
- File: lib/services/ballistics/atmosphere.dart
- Function: <function name> (e.g., `_saturationVaporPressureMb` or similar)
- Lines: <line numbers>

## Hand-verification of Tetens formula
Source: docs/references/atmosphere_tetens.md §3 + nws_vapor_pressure.pdf
Form audited: <NWS 6.11 base-10 form / Tetens 6.1078 base-10 form / Wikipedia exp form>
Units: <mb / hPa / kPa / Pa> input <°C / K / °F>

Cardinal cases verified:
  T = 0°C:  expected es = 6.1100 mb (NWS) or 6.1078 mb (Tetens), observed LoadOut output = ___
  T = 25°C: expected es = 31.686 mb (NWS) or 31.675 mb (Tetens), observed LoadOut output = ___
  T = -10°C (over ice, Murray): expected es = 2.594 mb, observed LoadOut output = ___

Residuals: <values>
Coefficient decision: <which one LoadOut uses; citation chain>
Over-ice support: <yes/no; if no, justification>
```

---

## 7. Citation block (paste-ready for code comments)

```dart
// Saturation vapor pressure via Tetens equation per NWS / Tetens 1930.
// Over liquid water (T > 0°C):  es = 6.11 * 10^((7.5*T)/(237.3+T)) [mb, T in °C]
// Source: NWS wxcalc, docs/references/nws_vapor_pressure.pdf
//         (original: Tetens, O. 1930. Z. Geophys 6: 297-309)
// Over ice (T < 0°C, optional): Murray 1967 (DOI: 10.1175/1520-0450(1967)
//         006<0203:OTCOSV>2.0.CO;2)
// Accuracy: within 1 Pa up to 35°C per Monteith & Unsworth (2013).
// See docs/references/atmosphere_tetens.md for the full anchor table.
```

For BFP plan / audit-trail references:

> National Weather Service (El Paso office), *Vapor Pressure* calculator documentation, `https://www.weather.gov/media/epz/wxcalc/vaporPressure.pdf` (accessed 2026-05-17). Original published source: Tetens, O. (1930), *Über einige meteorologische Begriffe*, Z. Geophys 6: 297-309.

---

## 8. What's NOT in this file

- **Atmospheric density formula** — Tetens gives saturation vapor pressure only; the humid-air density correction (combining dry-air density + water vapor) is a separate calculation. Covered in BFP Phase 6 as part of the same audit but draws from a different reference (ideal gas law + Avogadro's number, both universal).
- **ICAO standard atmosphere** — temperature, pressure, density profile vs altitude. Separate reference (next walkthrough).
- **Higher-precision alternatives** — Arden Buck equation, Goff-Gratch, Wagner & Pruß (IAPWS), etc. These exceed Tetens' accuracy but are not what LoadOut uses (per Ballistics.md §1 and the existing solver). Out of scope for Phase 6 unless LoadOut is upgrading to a higher-precision formula (which the BFP plan doesn't authorize).
- **Original Tetens 1930 German paper** — not extracted; cited bibliographically only. The formula's coefficients are facts from the citation chain, anchored by NWS public-domain documentation.

---

## 9. Verification status

| Item | Status | By |
|---|---|---|
| NWS form: `6.11 × 10^((7.5·T)/(237.3+T))` | ✓ Confirmed | `docs/references/nws_vapor_pressure.pdf` (page 1) |
| Tetens precise form: `6.1078 × 10^((7.5·T)/(237.3+T))` | ✓ Confirmed | Wikipedia citing Tetens 1930 (screenshot 2026-05-17) |
| Equivalent exp form: `0.61078 × exp((17.27·T)/(T+237.3))` | ✓ Confirmed | Wikipedia citing Monteith & Unsworth 2013 |
| Murray over-ice form: `6.1078 × exp((21.875·T)/(T+265.5)) × 0.1` (kPa, equivalent in mb shown above) | ✓ Confirmed | Wikipedia citing Murray 1967 (DOI: 10.1175/1520-0450(1967)006<0203:OTCOSV>2.0.CO;2) |
| Cardinal-case anchor values | ✓ Hand-computed | This file §3 |
| Accuracy: ±1 Pa up to 35°C | ✓ Confirmed | Wikipedia citing Monteith & Unsworth 2013 |
| LoadOut's actual implementation form | ⏳ Pending | Phase 6 Group A code-level verification |
| Over-ice support in LoadOut | ⏳ Pending | Phase 6 Group A code-level verification |
| Coefficient (6.11 vs 6.1078) used by LoadOut | ⏳ Pending | Phase 6 Group A code-level verification |

⏳ items are explicit BFP Phase 6 Group A deliverables.

---

## End of reference
