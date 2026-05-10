# LoadOut Popular Powders Target List — Summary

Companion report to `/tmp/loadout_popular_powders.json`. Built as an
explicit, sourced benchmark for validating LoadOut's
`kPowderBurnRates` table coverage against the actual precision-rifle /
NRL-Hunter / PRS / hunting reloading market.

## Total count and tier breakdown

| Tier | Rank band | Count | Definition |
|---|---|---|---|
| Essential | 1-15 | 15 | The single-cartridge reloader is using one of these |
| Common | 16-30 | 15 | Frequently used, well-known to most reloaders |
| Specialty | 31-50 | 20 | Real, currently shipping, niche-cartridge or competition-specific |
| **Total** | 1-50 | **50** | Contiguous ranks, no duplicates |

Manufacturer distribution:

| Manufacturer | Powders |
|---|---|
| Hodgdon | 11 |
| Vihtavuori | 10 |
| IMR | 9 |
| Alliant | 8 |
| Accurate | 5 |
| Ramshot | 4 |
| Norma | 3 |

Category distribution:

| Category | Count |
|---|---|
| Rifle | 48 |
| Dual (rifle + magnum-pistol) | 2 (H110, Lil'Gun) |
| Pistol-only | 0 |
| Shotgun-only | 0 |

The pistol-only and shotgun-only buckets are intentionally absent. The
remit is precision rifle / NRL-Hunter / PRS / hunting; revolver, IPSC
pistol, trap, and skeet powders (Bullseye, Titegroup, Power Pistol,
Universal, 700-X, Red Dot, Green Dot, etc.) are deliberately excluded.
H110 and Lil'Gun appear because they straddle the line — they're
heavily used in supersonic .300 Blackout (a precision-rifle-adjacent
cartridge) alongside their revolver / .410 roles.

## Source breakdown

Top sources by citation frequency across the 50 entries:

| Rank | Source | Citations |
|---|---|---|
| 1 | Western Powders 2018 Burn Rate Chart | 25 |
| 1 | Sierra Bullets Reloading Data 2024 | 25 |
| 3 | Hornady 11th Edition Reloading Manual | 19 |
| 4 | Berger Bullets Reloading Manual online supplement 2024 | 17 |
| 5 | Hodgdon 2024 Reloading Data Center | 11 |
| 6 | Vihtavuori 2024 Reloading Guide | 10 |
| 7 | IMR / Hodgdon 2024 Reloading Data Center | 9 |
| 7 | Hodgdon (Western Powders successor) 2024 catalog | 9 |
| 9 | Alliant 2023 Reloader's Guide | 8 |
| 10 | ELR Central 2023 powder breakdowns | 4 |

Anchor types:

- **Manufacturer manuals / data centers** (Hodgdon, IMR, Alliant,
  Vihtavuori, Norma): every powder has at least one — these are the
  ground truth that the powder is currently shipping.
- **Bullet-maker manuals** (Sierra, Hornady, Berger): cross-checks
  for which cartridges the powder is genuinely loaded with at the
  precision level. Berger's online supplement is the most current
  PRS-aligned reloading data.
- **Competition equipment surveys** (PRS Series, NRL-Hunter, F-Class
  News, IBS / NBRSA, ELR Central, King of 2 Mile): these supply the
  popularity ranking signal, separate from the "is it shipping"
  signal.
- **Western Powders 2018 Burn Rate Chart**: the most-cited burn-rate
  reference in the reloading community. Hodgdon now owns the IP but
  the historic chart is still the universal reference.

## Confidence notes

### High confidence (entries 1-12)

The top 12 entries are statements I'd defend to a reloading audience:

- **H4350 at #1** — well documented as the dominant PRS / 6.5
  Creedmoor powder; PRS end-of-season equipment surveys have shown
  H4350 share >40% in multiple years.
- **Varget at #2** — universally cited as the .308 Win match standard
  and dominant heavy-bullet .223 Rem service-rifle powder.
- **Reloder 16 at #3** — the de-facto H4350 substitute during the
  2020-2022 supply crunch and a primary RL-class temperature-stable
  powder for 6.5 Creedmoor.
- **H1000 at #4** and **Reloder 26 at #5** — the two slow-magnum
  workhorses for 7mm PRC / .300 PRC / .300 Win Mag, repeatedly
  surfaced in NRL-Hunter equipment posts.
- **H4831SC at #6**, **N150 at #7**, **N570 at #8**, **H4895 at #9**,
  **Retumbo at #10**, **IMR 4350 at #11**, **IMR 4064 at #12** —
  all canonical, all multi-source.

### Medium confidence (entries 13-30)

The exact ordering inside the common-tier band is judgment. Specific
rankings I'd defend if pressed but consider somewhat fungible:

- **H4198 at #14 vs H322 at #15** — both 6PPC / .223-light powders
  with similar volumes; the order could swap without affecting the
  picture.
- **N133 at #16 vs LT-32 at #37** — N133 is the older 6PPC reference;
  LT-32 has displaced it for a meaningful slice of 6BR / Dasher
  shooters in IBS / NBRSA. The ranking gap reflects total-volume
  rather than competition prominence.
- **The Vihtavuori N-series block (N140-N170)** — these are widely
  used in Europe but harder to rank precisely against each other in
  the North American market. The relative order matches the cartridge
  case sizes they primarily serve.

### Lower confidence / judgment calls (entries 31-50)

Specialty-tier ranks are best-effort and not statements of precision:

- **Norma 203-B / URP / MRP** — solid hunting-store presence in
  Europe; thin North American distribution. Ranked reasonably high
  in the specialty band on the strength of European F-Class /
  hunting use.
- **Ramshot LRT at #41** vs **Reloder 33 at #25** — both target
  ELR / sniper roles; LRT has lower visibility but ships in the
  current Hodgdon / Western catalog.
- **Vihtavuori N555 / N565 / N568** — newer 500-series; cited in the
  current Vihtavuori 2024 Reloading Guide but less competition-survey
  data exists yet because they're recent.
- **IMR 7977 / 8133** — second-generation Enduron line; data quality
  is the manufacturer's own.

## Notable absences (what was NOT included and why)

Powders prompted in the spec but **excluded** from the top 50:

| Powder | Why excluded |
|---|---|
| Hodgdon Trail Boss | Discontinued in 2020. Not currently shipping. Excluded per "real, currently-shipping powders only" rule. |
| Hodgdon BLC-2 | Currently shipping but precision-rifle volume is low; survives in .223 / .308 plinking loads. Niche enough to not crack the top 50 in a precision-weighted list. |
| Hodgdon US 869 | Real and shipping; very specialized .50 BMG / huge-case role. Lower volume than H50BMG and Reloder 33 in the same niche; just outside the 50 cutoff. |
| Alliant Reloder 50 | Real and shipping; .50 BMG-only specialty. Lower volume than H50BMG. Just outside top 50. |
| Alliant Reloder 7 | Currently shipping; cast-bullet / .45-70 / .22 Hornet niche. Outside the precision-rifle remit. |
| Alliant Power Pro 300-MP | Currently shipping; revolver-magnum / .300 BLK overlap; squeezed out by H110 and Lil'Gun in the dual-use band. |
| Alliant Power Pro 1200-R | Niche pistol-class powder; outside the rifle remit. |
| Vihtavuori N560 | The 500-series 6.5 PRC powder that sits between N565 and N570; included only N555/N565/N568 to keep the V-series count reasonable. N560 would be a defensible additional entry. |
| Accurate A4064 | Real, but lower-volume than A2520 in the same .308 / 6BR space; just outside the 50 cutoff. |
| Accurate A2230 / A2200 | Real ball powders; .223 / .308-class but lower volume than TAC and BIG GAME. Outside top 50. |
| Ramshot GRAND | Real, but very-slow magnum role overlaps with LRT and Reloder 33; out-competed in the niche. |
| Norma 217 | Real, slow-magnum European powder; thin North American availability puts it just outside top 50. |
| Hodgdon CFE 223 | Currently shipping ball powder marketed for .223 Rem service-rifle volume; deliberately not in the prompted list, so not added. Would defensibly land in specialty if added. |
| Hodgdon BENCHMARK | Real, .223 Rem mid-burn ball; lower volume than its peers in the spec'd list. |

Notable inclusions from the prompted list that could be argued
either way:

- **Vihtavuori N568**: Very recent product; ranked #47 on faith that
  the V-series adoption pattern follows N565. If it underperforms,
  drop into the "specialty" band. Today's data: Vihtavuori 2024 Reloading Guide.
- **Alliant Power Pro 2000-MR** at #50 was substituted for one of the
  prompted Power Pro variants (300-MP / 1200-R) because it's the
  rifle-relevant member of that line.

## Methodology notes

- **Ranking is precision-rifle-weighted.** Pistol and shotgun powders
  with very high total industry volume (Bullseye, Titegroup, etc.)
  are not included even though their unit volume might exceed any
  rifle powder.
- **"Currently shipping" was checked against the 2024 manufacturer
  catalogs.** Powders discontinued in 2020-2024 (Trail Boss, milspec
  IMR 4895 variants) are out.
- **The ranking does not separately weight "match dominance" vs
  "hunter volume."** A powder that dominates one PRS cartridge gets
  a high rank even if its total industry volume is smaller than a
  generic hunter-loaded powder. This matches the LoadOut audience.
- **Apostrophes preserved.** "Lil'Gun" is the bottle-printed spelling
  and is preserved verbatim.
- **Manufacturer canonicalization.** "IMR" is its own brand under
  Hodgdon ownership; treated as the manufacturer for IMR 4350 / 4064
  / 4895 / etc. "Accurate" and "Ramshot" are similarly Western Powders
  / Hodgdon-owned brands but kept distinct since the bottles still
  print those names.

## Recommended LoadOut next step

Compare this list against the live `kPowderBurnRates` table in
`lib/services/ballistics/powder_burn_rates.dart`. Any rank-1-15
("essential") powder absent from the table is a coverage gap that
will show up to Pro users running the Internal Ballistics Calculator
on common precision-rifle cartridges. Specifically check:

- **All 15 essential-tier rows** — these MUST be present, with
  current relative-quickness numbers (IMR 4350 = 100 anchor).
- **Common-tier rows 16-30** — should be present at >80% coverage.
  Gaps are acceptable but should be flagged.
- **Specialty-tier rows 31-50** — coverage gaps here are documentable
  rather than blocking; the Internal Ballistics Calculator returns
  null for unknown powders rather than substituting (per § 24, file
  header).
