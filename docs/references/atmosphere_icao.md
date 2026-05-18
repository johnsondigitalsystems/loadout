# Atmosphere Reference — ICAO / U.S. Standard Atmosphere 1976

> **Purpose:** Reference data for BFP Phase 6 (atmosphere audit). LoadOut's atmosphere model uses the ICAO standard atmosphere (= U.S. Standard Atmosphere 1976) as its baseline for temperature, pressure, density, and speed of sound vs altitude. This file is the authoritative reference for that model during BFP execution.
>
> **Sourced from:** `docs/references/us-standard-atmosphere_st76-1562_noaa.pdf` (committed to the repo, public domain). Cross-referenced against NASA Glenn Research Center and Engineering Toolbox.
>
> **License posture:** USSA 1976 PDF is a joint NOAA/NASA/USAF publication — U.S. federal work, public domain. NASA Glenn page is also federal work, public domain. Engineering Toolbox content is copyrighted with a permissive use grant ("can be used with NO WARRANTY or LIABILITY"); cited per their template.

---

## Source record

| Source | Location / URL | Type | License |
|---|---|---|---|
| U.S. Standard Atmosphere 1976 | `docs/references/us-standard-atmosphere_st76-1562_noaa.pdf` (243 pages) | Joint NOAA/NASA/USAF technical publication | Public domain (U.S. federal work) |
| NASA Glenn Research Center "Earth Atmosphere Model" | `https://www.grc.nasa.gov/www/k-12/airplane/atmos.html` | Federal educational page; simple piecewise formulas | Public domain |
| Engineering Toolbox "International Standard Atmosphere" | `https://www.engineeringtoolbox.com/international-standard-atmosphere-d_985.html` | Commercial reference site | Copyrighted; permissive use grant with attribution |
| ISO 2533:1975 "Standard Atmosphere" | iso.org (paywalled) | International standard | **Not used** — paywalled. Equivalent to USSA 1976 in 0–32 km range. |

Access date for online sources: 2026-05-17.

**Equivalence note:** ICAO standard atmosphere (defined by ISO 2533:1975), U.S. Standard Atmosphere 1976, and the underlying physics model are essentially identical in the 0–32 km altitude range that matters for ballistics. They differ only in extended-altitude treatment above 32 km, which is outside ballistics scope. Citing USSA 1976 satisfies ICAO references for any practical purpose in this codebase.

**OCR caveat:** The committed `us-standard-atmosphere_st76-1562_noaa.pdf` has degraded OCR (the scan-to-PDF tool produced a text layer that's mostly garbled). For Phase 6 execution, Claude Code may want to re-OCR the file with Acrobat Pro (or equivalent) for searchability. Alternatively, use this reference file for the cardinal values; refer to the PDF only for direct primary-source verification when needed.

---

## 1. Standard sea-level reference conditions

| Symbol | Value (SI) | Value (Imperial) |
|---|---|---|
| Temperature T_0 | 288.15 K | 15.00 °C / 59.00 °F |
| Pressure P_0 | 101325 Pa = 1013.25 hPa | 29.921 inHg / 2116.22 lbf/ft² |
| Density ρ_0 | 1.225 kg/m³ | 0.07647 lb/ft³ |
| Speed of sound a_0 | 340.29 m/s | 1116.50 ft/s |
| Standard gravity g_0 | 9.80665 m/s² | 32.174 ft/s² |
| Specific gas constant (dry air) R | 287.05287 J/(kg·K) | 1716.5 ft²/(s²·°R) |
| Molar mass of dry air M | 0.0289644 kg/mol | — |
| Tropopause altitude | 11 000 m geopotential | 36 089 ft (geopotential), 36 152 ft (geometric per NASA Glenn) |

---

## 2. Atmospheric model — three altitude zones

The USSA 1976 / ICAO model defines air properties piecewise across altitude bands. For ballistics, only the troposphere and lower stratosphere matter; the upper-stratosphere model is included for completeness.

### 2.1 Troposphere (0 ≤ h < 11 000 m, or 0 ≤ h < 36 152 ft)

Temperature varies linearly with altitude. **Lapse rate L = −0.0065 K/m** (equivalent to −6.5 K/km, or −3.566 °F per 1000 ft).

**SI form:**
```
T(h) = T_0 + L × h = 288.15 - 0.0065 × h         [K, h in m]
P(h) = P_0 × (T(h) / T_0)^(-g_0 / (R × L))
     = 101325 × (1 - 0.0065 × h / 288.15)^5.2558  [Pa, h in m]
ρ(h) = P(h) / (R × T(h))                          [kg/m³]
a(h) = sqrt(γ × R × T(h)),  γ = 1.4              [m/s]
```

**Imperial form (per NASA Glenn):**
```
T = 59 - 0.00356 × h                              [°F, h in ft]
P = 2116 × ((T + 459.7) / 518.6)^5.256            [lbf/ft², h in ft, T in °F]
ρ = P / (1718 × (T + 459.7))                      [slugs/ft³]
```

The exponent `5.2558` (SI) or `5.256` (Imperial) is `-g_0 / (R × L)`. Both forms produce mathematically identical results within rounding.

### 2.2 Lower stratosphere (11 000 m ≤ h < 20 000 m, or 36 152 ft ≤ h < 65 617 ft)

Temperature is **isothermal at T = 216.65 K (−56.5 °C / −69.7 °F)**. Pressure decreases exponentially.

**SI form:**
```
T(h) = 216.65 K (constant)
P(h) = 22632 × exp(-g_0 × (h - 11000) / (R × 216.65))   [Pa, h in m]
     = 22632 × exp(-(h - 11000) / 6341.62)
ρ(h) = P(h) / (R × 216.65)                              [kg/m³]
a(h) = 295.07 m/s (constant in this zone)
```

**Imperial form (per NASA Glenn):**
```
T = -70 °F (approximately; precise USSA 1976 value is -69.7°F)
P = 473.1 × exp(1.73 - 0.000048 × h)               [lbf/ft², h in ft]
```

### 2.3 Upper stratosphere (h > 82 345 ft = 25 100 m)

Out of ballistics scope. Included from NASA Glenn for completeness:

```
T = -205.05 + 0.00164 × h                          [°F, h in ft]
P = 51.97 × ((T + 459.7) / 389.98)^(-11.388)       [lbf/ft²]
```

For LoadOut purposes, only zones 2.1 and 2.2 are required.

---

## 3. Cardinal-case anchor table

Hand-derived values at standard altitudes. Computed at planning time using the formulas in §2; cross-checked against Engineering Toolbox tabular values; suitable as Phase 6 test fixtures.

| Altitude (ft) | Altitude (m) | T (°C) | T (K) | P (hPa) | P (inHg) | ρ (kg/m³) | a (m/s) |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0 | 15.00 | 288.15 | 1013.25 | 29.921 | 1.22500 | 340.29 |
| 1 000 | 305 | 13.02 | 286.17 | 977.17 | 28.856 | 1.18955 | 339.12 |
| 5 000 | 1 524 | 5.09 | 278.24 | 843.07 | 24.896 | 1.05555 | 334.39 |
| 10 000 | 3 048 | -4.81 | 268.34 | 696.82 | 20.577 | 0.90464 | 328.39 |
| 15 000 | 4 572 | -14.72 | 258.43 | 571.82 | 16.886 | 0.77082 | 322.27 |
| 18 000 | 5 486 | -20.66 | 252.49 | 506.00 | 14.942 | 0.69815 | 318.54 |
| 20 000 | 6 096 | -24.62 | 248.53 | 465.63 | 13.750 | 0.65269 | 316.03 |
| 25 000 | 7 620 | -34.53 | 238.62 | 376.01 | 11.104 | 0.54895 | 309.67 |
| 30 000 | 9 144 | -44.44 | 228.71 | 300.90 | 8.885 | 0.45831 | 303.17 |
| 36 152 (tropopause) | 11 019 | -56.50 | 216.65 | 225.64 | 6.663 | 0.36282 | 295.07 |

### 3.1 Hand-derivation example (5000 ft / 1524 m)

```
h = 1524 m

Temperature:
T(1524) = 288.15 + (-0.0065)(1524)
        = 288.15 - 9.906
        = 278.24 K = 5.09 °C ✓

Pressure:
P(1524) = 101325 × (1 - 0.0065 × 1524 / 288.15)^5.2558
        = 101325 × (1 - 0.034376)^5.2558
        = 101325 × (0.965624)^5.2558
        = 101325 × 0.83206
        = 84307 Pa = 843.07 hPa ✓

Density:
ρ(1524) = 84307 / (287.05287 × 278.24)
        = 84307 / 79869
        = 1.05555 kg/m³ ✓

Speed of sound:
a(1524) = sqrt(1.4 × 287.05287 × 278.24)
        = sqrt(111817)
        = 334.39 m/s ✓
```

A Phase 6 group report would show this kind of arithmetic chain for each anchor case verified.

### 3.2 Engineering Toolbox cross-check (selected points)

Engineering Toolbox tabulates values at metric altitudes. Spot-check at 500 m (an altitude not in my anchor table, intentionally cross-referenced):

| Quantity | This file (computed) | Engineering Toolbox | Agreement |
|---|---|---|---|
| T at 500 m | 284.90 K (11.75 °C) | 284.9 K (11.75 °C) | ✓ exact |
| P at 500 m | 954.6 hPa | 0.9546 bar = 954.6 hPa | ✓ exact |
| ρ at 500 m | 1.16735 kg/m³ | 1.1673 kg/m³ | ✓ exact |

Cross-check confirms the USSA 1976 model produces the published Engineering Toolbox values.

---

## 4. BFP Phase Mapping

| Phase | Use of this reference |
|---|---|
| **Phase 6 — Atmosphere Model** | Primary consumer. Verifies LoadOut's `atmosphere.dart` ICAO fallback against this reference. Sea-level constants + lapse rate + zone formulas all hand-derived. |
| **Phase 7 — Drag tables** | Drag depends on Mach number, which depends on speed of sound, which depends on T from this reference. Indirect consumer. |
| **Phase 15 — Zero atm vs runtime atm separation** | Both atmospheres reference this model when station data is unavailable. Phase 15 verifies they're applied correctly in sequence (zero subtracted, runtime added). |

---

## 5. Hand-Verification Protocol for Claude Code (during Phase 6)

When BFP Phase 6 executes (carried from BFP plan §0.6):

1. **Read `atmosphere.dart`** — find:
   - Sea-level constants (T_0, P_0, ρ_0)
   - Lapse rate L
   - Tropopause altitude
   - Pressure formula (with its exponent)
   - Density formula
   - Speed of sound formula
   - Any handling of geopotential vs geometric altitude

2. **Cross-check each constant against §1.** Note especially:
   - T_0: 288.15 K vs 15°C — must use consistent unit
   - P_0: 101325 Pa vs 1013.25 hPa vs 29.921 inHg — code must use one
   - ρ_0: 1.225 kg/m³ (the most-cited convention)
   - R: 287.05287 J/(kg·K) for dry air

3. **Cross-check formulas against §2.** Watch for:
   - Lapse rate sign — `T = T_0 - L|h|` with L positive, OR `T = T_0 + L·h` with L negative. Both are correct conventions; code must be internally consistent.
   - Pressure exponent: `-g_0/(R·L) = 5.2558`. Some sources round to 5.256 or 5.26.
   - Geopotential vs geometric altitude. Standard atmospheres use geopotential; the difference is negligible for ballistics (<0.1% at 10 km).

4. **Hand-derive at three cardinal cases** from §3: sea level, 5000 ft, and the tropopause boundary (36 152 ft). Show arithmetic chains as in §3.1.

5. **Compare to LoadOut output** at the same inputs. Document residuals.
   - If residual > 0.1% on any of T, P, ρ — investigate (likely a constant mismatch or unit conversion).
   - If residual > 0.5% — surface as a finding.

6. **Verify zone-boundary handling.** At the tropopause (11 000 m / 36 152 ft), LoadOut should transition from troposphere formulas to lower-stratosphere formulas. Verify the transition is continuous (no jump in T, P, ρ at the boundary).

7. **Test fixture re-baselining.** Any existing Phase 6 atmosphere fixtures that consumed prior (possibly incorrect) values get re-baselined against §3.

---

## 6. Phase 6 Group Report Template (relevant excerpt)

```
## Hand-verification of ICAO / USSA 1976 atmosphere model
Source: docs/references/atmosphere_icao.md §3 + us-standard-atmosphere_st76-1562_noaa.pdf

Constants verified:
  T_0 = ___ K (expected 288.15)
  P_0 = ___ Pa (expected 101325)
  rho_0 = ___ kg/m³ (expected 1.225)
  Lapse rate = ___ K/m (expected -0.0065)
  Pressure exponent = ___ (expected 5.2558)
  Tropopause altitude = ___ m (expected 11000)

Cardinal cases verified:
  Sea level:   T=__°C P=__hPa rho=__kg/m³ (expected 15.00, 1013.25, 1.225)
  5000 ft:     T=__°C P=__hPa rho=__kg/m³ (expected 5.09, 843.07, 1.05555)
  Tropopause:  T=__°C P=__hPa rho=__kg/m³ (expected -56.50, 225.64, 0.36282)

Zone boundary continuity at 11 000 m: __ (must be continuous)
Residuals: __

Atmosphere applied to test trajectory at 1000 yd / sea level / .308 175 SMK / 2650 fps MV:
  Drop with model: __ mil
  Drop with corrected model: __ mil
  Delta: __ mil
```

---

## 7. Citation block (paste-ready for code comments)

```dart
// ICAO standard atmosphere = U.S. Standard Atmosphere 1976.
// Sea-level: T_0 = 288.15 K, P_0 = 101325 Pa, rho_0 = 1.225 kg/m^3.
// Troposphere (0-11 km): T = T_0 + L*h, L = -0.0065 K/m.
// Pressure: P = P_0 * (T/T_0)^5.2558, where 5.2558 = -g_0/(R*L).
// Source: NOAA/NASA/USAF (1976). U.S. Standard Atmosphere, 1976.
//         docs/references/us-standard-atmosphere_st76-1562_noaa.pdf
// Cross-reference: NASA Glenn Earth Atmosphere Model,
//         https://www.grc.nasa.gov/www/k-12/airplane/atmos.html
// See docs/references/atmosphere_icao.md for the full anchor table.
```

For BFP plan / audit-trail references:

> National Oceanic and Atmospheric Administration, National Aeronautics and Space Administration, and United States Air Force (1976). *U.S. Standard Atmosphere, 1976*. NOAA-S/T 76-1562. Washington, DC: U.S. Government Printing Office. Committed at `docs/references/us-standard-atmosphere_st76-1562_noaa.pdf`. Cross-reference: NASA Glenn Research Center, *Earth Atmosphere Model*, `https://www.grc.nasa.gov/www/k-12/airplane/atmos.html` (accessed 2026-05-17).

For Engineering Toolbox cross-reference (per their citation template):

> The Engineering Toolbox (2005). *International Standard Atmosphere*. [online] Available at: `https://www.engineeringtoolbox.com/international-standard-atmosphere-d_985.html` [Accessed 2026-05-17].

---

## 8. What's NOT in this file

- **Station pressure correction** — adjusting sea-level standard pressure for the shooter's actual altitude. Separate calculation in `atmosphere.dart`; uses the same model but applies the inverse (given measured station pressure and altitude, recover effective sea-level conditions).
- **Density altitude calculation** — derived from observed T, P, RH using this model + Tetens (see `atmosphere_tetens.md`). Phase 6 audits both pieces independently.
- **Humid-air correction** — combines this reference (dry-air density) with Tetens (vapor pressure). Cardinal-case combined values are computed in Phase 6 from both references.
- **Non-standard atmospheres** — Army Standard Metro, ICAO hot/cold/tropical day variants, etc. LoadOut uses the USSA 1976 baseline; other models are out of scope unless Phase 6 surfaces a need.
- **Upper stratosphere model (h > 25 km)** — out of ballistics scope. NASA Glenn formulas included in §2.3 for completeness only.

---

## 9. Verification status

| Item | Status | By |
|---|---|---|
| Sea-level constants (T_0, P_0, ρ_0, a_0) | ✓ Confirmed | NASA Glenn + Engineering Toolbox cross-check; USSA 1976 PDF in repo |
| Troposphere lapse rate -6.5 K/km | ✓ Confirmed | NASA Glenn formula + Engineering Toolbox table |
| Pressure exponent 5.2558 | ✓ Confirmed | Hand-derivation `g_0 × M / (R* × L) = 5.2558` |
| Tropopause altitude 11 000 m / 36 152 ft | ✓ Confirmed | NASA Glenn (note: USSA 1976 uses geopotential 11 km exactly; difference vs geometric is <0.1%) |
| Cardinal anchors at SL, 1k, 5k, 10k, 15k, 20k, tropopause | ✓ Hand-computed | This file §3; spot-cross-checked vs Engineering Toolbox at 500 m |
| Lower stratosphere isothermal T = 216.65 K | ✓ Confirmed | USSA 1976 / NASA Glenn (-69.7°F = -56.50°C) |
| LoadOut's actual implementation form | ⏳ Pending | Phase 6 Group A code-level verification |
| LoadOut's tropopause boundary handling | ⏳ Pending | Phase 6 Group A code-level verification |
| Geopotential vs geometric altitude convention in LoadOut | ⏳ Pending | Phase 6 Group A code-level verification |

⏳ items are explicit BFP Phase 6 Group A deliverables.

---

## End of reference
