# Factory loads scraping pipeline

`assets/seed_data/factory_loads.json` is the master catalog of factory
ammunition SKUs the ballistics calculator and Range Day workspace pull
from. This directory contains the scrapers that populate it.

## Current state

As of the last scrape run (2026-05-08): **4143 entries** across 37
manufacturers, up from 2583 baseline. Per-manufacturer breakdown:

| Manufacturer        | Count |
|---------------------|------:|
| Federal             | 1000  |
| Hornady             |  925  |
| Norma               |  370  |
| Sellier & Bellot    |  277  |
| Magtech             |  217  |
| Winchester          |  207  |
| Remington           |  156  |
| Nosler              |  112  |
| Fiocchi             |   93  |
| Black Hills         |   81  |
| Sig Sauer           |   81  |
| Sako                |   75  |
| Lapua               |   58  |
| Speer               |   50  |
| Aguila              |   48  |
| Berger              |   45  |
| Browning            |   45  |
| RWS                 |   41  |
| CCI                 |   36  |
| Buffalo Bore        |   32  |
| IMI                 |   29  |
| PMC                 |   29  |
| GECO                |   25  |
| Sierra              |   17  |
| Underwood           |   14  |
| (smaller brands)    |  ~80  |

## Schema

Each row in `factory_loads.json`:

```json
{
  "manufacturer": "Hornady",
  "line": "Match",
  "caliber": "6.5 Creedmoor",
  "bulletWeightGr": 140.0,
  "factoryMvFps": 2710,
  "bcG1": 0.646,
  "bcG7": 0.326,
  "bulletLengthIn": null,
  "application": "match",
  "notes": "140 gr ELD Match — 81500"
}
```

Required fields: `manufacturer`, `caliber`, `bulletWeightGr`,
`factoryMvFps`, and at least one of `bcG1` / `bcG7`. `notes` carries
the bullet style + manufacturer SKU when known. `application` is
hint metadata for the cascading picker (`match`, `hunting`, `defense`,
`varmint`, `target`, `rimfire`, `general`).

## Scrapers

| Script                               | Source                                              | Approach |
|--------------------------------------|-----------------------------------------------------|----------|
| `scrape_hornady.py`                  | https://www.hornady.com/sitemap.xml + per-SKU page  | Each SKU page embeds `var item = {...}` JSON with `weight`, `muzzlevelocity`, `ball_coef` (G1), `ball_coef_2` (G7), `cartridgename`, `linktitle`, `applicationname`. Skips International variants (they use m/s in the same field as fps and would produce nonsense MVs). |
| `scrape_federal.py`                  | https://www.federalpremium.com/ballistics-calculator| Caliber dropdown HTML + three Demandware AJAX endpoints (`BallisticCalculator-{BulletStyles,BulletWeights,LoadDetails}`). Gives MV + G1 BC per (caliber, style, weight). |
| `scrape_norma.py`                    | https://www.norma-ammunition.com sitemap            | Each detail page has schema.org Product JSON-LD with `additionalProperty` entries, plus a velocity table where the V0 fps reading lives. |
| `scrape_berger.py`                   | https://bergerbullets.com WooCommerce sitemap       | WooCommerce product attribute table (`pa_bullet-weight`, `pa_g1-bc`, `pa_g7-bc`, `pa_muzzle-velocity`). |
| `scrape_browning.py`                 | https://browningammo.com/sitemap.xml                | Per-line ammunition pages with a "Quickview" block for each SKU; we regex out the labelled fields. |
| `scrape_fiocchi.py`                  | https://www.fiocchiusa.com/sitemap_0.xml            | Same pattern as Browning — line pages list each SKU with labelled spec fields. |
| `scrape_sako.py`                     | https://www.sako.global per-line pages              | Inline text spec rows ("Caliber X Bullet weight Y g / Z gr Muzzle velocity N m/s Ballistic coefficient B"). Uses `curl` subprocess because urllib hangs on Sako's TLS. |
| `scrape_rws.py`                      | https://www.rws-ammunition.com per-product pages    | Inline spec text ("V0 830 m/s ... BC value 0.421"). Title encodes caliber + line + weight. |
| `scrape_sellier_bellot.py`           | https://www.sellier-bellot.cz line pages            | Wide HTML table with one row per SKU and 37 cells covering caliber (in img alt), velocity, G1+G7 BC, etc. |
| `scrape_lapua.py`                    | https://www.lapua.com category pages                | WooCommerce `<table class="woocommerce-product-attributes">` with `pa_muzzle-velocity` (m/s + fps), `pa_bc-g1`, `pa_bc-g7`. |
| `scrape_magtech.py`                  | https://magtechammunition.com/wp-json/wp/v2/produto | WordPress REST API. Each `produto` has an `acf` block with `desc_ballistic_coeficient`, `muzzley.velocity` (fps), bullet weight, SKU symbol. |
| `merge_factory_loads.py`             | (consolidator)                                      | Reads master + scraped JSON files, dedups by `(manufacturer, line, caliber, weight, mv, notes)`, validates basic ranges, writes back. |

## Quality bar enforced by `merge_factory_loads.py`

- `factoryMvFps` must be in `[200, 5000]` fps.
- At least one of `bcG1` / `bcG7` must be present and in `[0.05, 1.5]`.
- Caliber + manufacturer + bullet weight must be non-null.
- Duplicates (same `(manufacturer, line, caliber, weight, mv, notes)`)
  are dropped on the second occurrence.

## Running a refresh

```sh
# Run individual scrapers to /tmp
python3 tool/scrape_hornady.py --output /tmp/hornady_factory_loads.json
python3 tool/scrape_federal.py --output /tmp/federal_factory_loads.json
python3 tool/scrape_norma.py --output /tmp/norma_factory_loads.json
python3 tool/scrape_berger.py --output /tmp/berger_factory_loads.json
python3 tool/scrape_browning.py --output /tmp/browning_factory_loads.json
python3 tool/scrape_fiocchi.py --output /tmp/fiocchi_factory_loads.json
python3 tool/scrape_sako.py --output /tmp/sako_factory_loads.json
python3 tool/scrape_rws.py --output /tmp/rws_factory_loads.json
python3 tool/scrape_sellier_bellot.py --output /tmp/sb_factory_loads.json
python3 tool/scrape_lapua.py --output /tmp/lapua_factory_loads.json
python3 tool/scrape_magtech.py --output /tmp/magtech_factory_loads.json

# Merge into master (preserves existing rows)
python3 tool/merge_factory_loads.py \
    --master assets/seed_data/factory_loads.json \
    --inputs /tmp/hornady_factory_loads.json \
             /tmp/federal_factory_loads.json \
             /tmp/norma_factory_loads.json \
             /tmp/berger_factory_loads.json \
             /tmp/browning_factory_loads.json \
             /tmp/fiocchi_factory_loads.json \
             /tmp/sako_factory_loads.json \
             /tmp/rws_factory_loads.json \
             /tmp/sb_factory_loads.json \
             /tmp/lapua_factory_loads.json \
             /tmp/magtech_factory_loads.json \
    --output assets/seed_data/factory_loads.json

# Verify
flutter test test/factory_load_repository_test.dart
flutter analyze
```

The scrapers are idempotent — manufacturers' published data only
changes when they release new product lines, so re-running picks up
just the new SKUs without disturbing existing rows. The merge step
preserves the original master rows verbatim and only appends new
non-duplicate entries.

## Manufacturers we couldn't get and why

These were probed but didn't yield usable data without much heavier
work. Future work should focus here:

| Manufacturer | Reason skipped | Notes |
|---|---|---|
| **Sierra** | They primarily sell *bullets* (reloading components), not factory ammunition. The site lists SMK / TMK / GameKing as bullets only. Sierra-branded factory ammunition is sold under the Black Hills + Federal "Sierra MatchKing" lines, which we capture via those scrapers. The 17 existing Sierra entries cover the limited Sierra-branded factory lineup. |
| **Black Hills** | Their site lists velocities per SKU but does **not** publish G1/G7 BCs anywhere on the public product pages. Without BC the entries can't be used in the calculator. |
| **PMC** | Same problem as Black Hills — line pages list MV per SKU but not BC. The 29 existing PMC entries already use generic FMJ BCs sourced from the matching Hornady/Sierra bullet. |
| **CCI / Speer** | CCI is mostly rimfire, where most products don't have a usable G1 BC. Speer (Lawman / Gold Dot) doesn't publish BC on the website. |
| **Aguila** | Static Gatsby site — product specs are rendered at build time and not in the static HTML. Need a headless browser. |
| **Buffalo Bore** | Product pages list MV per SKU but no BC. Without BC the entries aren't useful. |
| **Underwood** | Same as Buffalo Bore. |
| **Wolf / Tula / Brown Bear** | Steel-case practice ammo with no published BC; existing entries use generic FMJ BCs. |
| **Sig Sauer** | Site is behind Cloudflare bot challenge — `403 Forbidden` from our scraper. Existing 81 entries are sufficient for Sig's catalog. |
| **PPU (Prvi Partizan)** | Catalog browse uses a `search_rm.php` form that returns no data on direct POST. The static HTML pages have no MV/BC values inline. Would need session cookies / JS execution. |
| **Geco** | Their public product pages list calibers but not per-cartridge MV/BC. Their parent RWS site has the data; we scrape RWS instead. |

## Notes on data accuracy

- All scrapers pull from the manufacturer's official website. We never
  fabricate MV or BC values.
- When a manufacturer publishes both G1 and G7 (e.g. Hornady, Berger,
  Sellier & Bellot, Norma's match line), we capture both. When only
  G1 is published (most pistol / hunting loads), `bcG7` is null.
- Muzzle velocities are normalized to fps. Manufacturers that publish
  in m/s (Norma, Sako, RWS, S&B) get converted at `mv_fps = round(mv_ms / 0.3048)`.
- The "application" field is heuristically inferred from the line
  name + bullet style and is best-effort. The cascading picker uses it
  to filter in the UI but the calculator doesn't depend on it.
