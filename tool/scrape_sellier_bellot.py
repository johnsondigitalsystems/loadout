#!/usr/bin/env python3
"""Scrape Sellier & Bellot factory ammunition specs.

S&B's site at https://www.sellier-bellot.cz lists ammunition lines
under ``/en/products/<category>/<line>``. Each line page renders a
detailed spec table with rows in the form:

    Caliber & Catalog №  Bullet                Cartridge   Velocity ...
    22-250 REM. V330462  1365 SBT 55 3.60 N/A  16.5 59.60  1122 ...

The columns include V0 in m/s, energy, BC G1, BC G7. We extract:
* Caliber (first cell of each row)
* Catalog № (second cell)
* Bullet weight (in grains, fourth cell after bullet code/type)
* V0 in m/s -> fps
* G1 BC (column 'Ballistic coefficient G1')
* G7 BC (column 'Ballistic coefficient G7')

Output schema mirrors ``factory_loads.json``.

Usage::

    python3 tool/scrape_sellier_bellot.py --output /tmp/sb_factory_loads.json
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
from html import unescape
from pathlib import Path

ORIGIN = "https://www.sellier-bellot.cz"
HEADERS = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0)"}

LINE_PAGES = [
    # rifle
    "/en/products/rifle-ammunition/exergy-edge/",
    "/en/products/rifle-ammunition/hunting-rifle-ammunition-with-pts-bullets/",
    "/en/products/rifle-ammunition/rifle-ammunition-fmj/",
    "/en/products/rifle-ammunition/rifle-ammunition-hpc/",
    "/en/products/rifle-ammunition/rifle-ammunition-sp/",
    "/en/products/rifle-ammunition/rifle-ammunition-spce/",
    "/en/products/rifle-ammunition/rifle-ammunition-target-match/",
    "/en/products/rifle-ammunition/rifle-ammunition-training-fmj/",
    "/en/products/rifle-ammunition/rifle-ammunition-with-exergy-blue-bullets/",
    "/en/products/rifle-ammunition/rifle-ammunition-with-exergy-bullets/",
    "/en/products/rifle-ammunition/rifle-hunting-ammunition-with-sierra-bullets/",
    # pistol
    "/en/products/pistol-and-revolver-ammunition/pistol-and-revolver-cartridges/",
    "/en/products/pistol-and-revolver-ammunition/xrg-defense/",
    "/en/products/pistol-and-revolver-ammunition/nontox-cartridges/",
    # law enforcement
    "/en/products/law-enforcement-products/sniper-line-ammunition/",
    "/en/products/law-enforcement-products/tactical-ammunition/",
    "/en/products/law-enforcement-products/lead-free-bullets/",
    # rimfire
    "/en/products/rimfire-ammunition/",
]

LINE_TO_NAME = {
    "exergy-edge": ("eXergy Edge", "hunting"),
    "hunting-rifle-ammunition-with-pts-bullets": ("PTS Hunting", "hunting"),
    "rifle-ammunition-fmj": ("Rifle FMJ", "target"),
    "rifle-ammunition-hpc": ("HPC", "hunting"),
    "rifle-ammunition-sp": ("Soft Point", "hunting"),
    "rifle-ammunition-spce": ("SPCE", "hunting"),
    "rifle-ammunition-target-match": ("Target Match", "match"),
    "rifle-ammunition-training-fmj": ("Training FMJ", "target"),
    "rifle-ammunition-with-exergy-blue-bullets": ("eXergy Blue", "hunting"),
    "rifle-ammunition-with-exergy-bullets": ("eXergy", "hunting"),
    "rifle-hunting-ammunition-with-sierra-bullets": ("Sierra GameKing", "hunting"),
    "pistol-and-revolver-cartridges": ("Pistol & Revolver", "general"),
    "xrg-defense": ("XRG Defense", "defense"),
    "nontox-cartridges": ("Nontox", "general"),
    "sniper-line-ammunition": ("Sniper Line", "match"),
    "tactical-ammunition": ("Tactical", "defense"),
    "lead-free-bullets": ("Lead Free", "general"),
    "rimfire-ammunition": ("Rimfire", "rimfire"),
}

CALIBER_NORMALIZER = {
    "308 win": ".308 Winchester",
    "30-06 spring": ".30-06 Springfield",
    "22-250 rem": ".22-250 Remington",
    "223 rem": ".223 Remington",
    "243 win": ".243 Winchester",
    "270 win": ".270 Winchester",
    "300 win. mag": ".300 Winchester Magnum",
    "300 wsm": ".300 WSM",
    "300 aac blackout": ".300 AAC Blackout",
    "338 lapua mag": ".338 Lapua Magnum",
    "7 mm rem. mag": "7mm Remington Magnum",
    "7mm rem. mag": "7mm Remington Magnum",
    "7 × 57": "7x57 Mauser",
    "7 × 57 r": "7x57R",
    "7 × 64": "7x64",
    "7 × 65 r": "7x65R",
    "7x57": "7x57 Mauser",
    "7x57r": "7x57R",
    "7x64": "7x64",
    "7x65r": "7x65R",
    "8 × 57 jrs": "8x57 JRS",
    "8 × 57 js": "8x57 JS",
    "8x57 jrs": "8x57 JRS",
    "8x57 js": "8x57 JS",
    "9 × 57": "9x57",
    "5,6 × 50 r mag.": "5.6x50R Magnum",
    "6,5 × 55 se": "6.5x55 SE",
    "6.5x55 se": "6.5x55 SE",
    "6,5 creedmoor": "6.5 Creedmoor",
    "6.5 creedmoor": "6.5 Creedmoor",
    "9,3 × 62": "9.3x62",
    "9.3x62": "9.3x62",
    "9,3 × 74 r": "9.3x74R",
    "9 mm luger": "9mm Luger",
    "9x19": "9mm Luger",
    "5,56 × 45": "5.56x45mm NATO",
    "5,56x45": "5.56x45mm NATO",
    "7,62 × 39": "7.62x39",
    "7.62x39": "7.62x39",
    "7,62 × 51": "7.62x51mm NATO",
    "7,62 × 54 r": "7.62x54R",
    "303 british": ".303 British",
    "458 lott": ".458 Lott",
    "458 win mag": ".458 Win Magnum",
    "375 h&h": ".375 H&H Magnum",
    ".22 lr": ".22 Long Rifle",
    "22 lr": ".22 Long Rifle",
}


def _http_get(url: str, *, timeout: float = 15.0, retries: int = 2) -> str:
    last_err = ""
    for _ in range(retries + 1):
        try:
            r = subprocess.run(
                ["curl", "-s", "-L", "-A", HEADERS["User-Agent"], "-m", str(int(timeout)), url],
                capture_output=True,
                check=True,
                timeout=timeout + 5,
            )
            return r.stdout.decode("utf-8", errors="replace")
        except subprocess.TimeoutExpired as e:
            last_err = f"timeout: {e}"
        except subprocess.CalledProcessError as e:
            last_err = f"curl exit {e.returncode}"
        time.sleep(1.0)
    raise RuntimeError(f"GET {url} failed: {last_err}")


def normalize_caliber(c: str) -> str:
    s = c.strip().rstrip(",").rstrip(".")
    key = s.lower()
    if key in CALIBER_NORMALIZER:
        return CALIBER_NORMALIZER[key]
    # Replace comma with dot for Czech decimal
    s = s.replace(",", ".")
    return s


def line_for_url(url: str) -> tuple[str, str]:
    slug = url.rstrip("/").split("/")[-1]
    return LINE_TO_NAME.get(slug, (slug.replace("-", " ").title(), "general"))


def parse_line_page(url: str, html: str) -> list[dict]:
    """Parse the comparison table on each S&B line page.

    Each <tr> data row has 37 cells:
      [0] image (empty after stripping HTML)
      [1] catalog number (V330462)
      [2] bullet number (1365)
      [3] bullet type (SBT)
      [4] weight in grains (55)
      [5] weight in grams (3.60)
      [6] bullet length / N/A
      [7] cartridge weight g
      [8] cartridge length mm
      [9] V0 m/s (with comma thousands separator)
      [10..13] V100..V400 m/s
      [14..18] E0..E400 joules
      [19] test barrel length
      [20..24] points of impact MRD
      [25] (numeric MRD)
      [26..30] another points-of-impact set
      [31] G1 BC
      [32] G7 BC
      [33..36] pcs/box, boxes/case, weight kg/lb

    The caliber is in the <img alt="Cartridge 22-250 REM. SBT 55 GRS">
    of the first <th class="image"> cell.
    """
    rows: list[dict] = []
    line_name, application = line_for_url(url)
    table_blocks = re.findall(r"<table[^>]*>(.*?)</table>", html, re.DOTALL)

    for tbl in table_blocks:
        trs = re.findall(r"<tr[^>]*>(.*?)</tr>", tbl, re.DOTALL)
        for tr in trs:
            # Caliber from img alt: "Cartridge <CALIBER> <STYLE> <weight> GRS"
            alt_m = re.search(r'<img[^>]+alt="Cartridge\s+([^"]+)"', tr)
            if not alt_m:
                continue
            alt_text = alt_m.group(1).strip()
            # Drop the trailing weight + GRS/gr
            alt_clean = re.sub(r"\s+\d+\s*(?:GRS|gr|grs?)\s*$", "", alt_text, flags=re.I).strip()
            # Drop the bullet style/code suffix - one of these tokens
            # marks the end of the caliber.
            STYLE_TOKENS = (
                "SBT", "FMJ", "SP", "HP", "TM", "XRG", "HPC", "SPCE", "PTS",
                "EXE", "EX", "RTG", "JSP", "TXR", "TFMJ", "JHP", "JFP", "TC",
                "FN", "EDGE", "BLUE", "EXERGY", "LRX", "TGK", "TIPSTRIKE",
                "LFR", "LRN", "WC", "RNL", "WFN", "FMJN", "TXFMJ", "PHP",
                "PHN", "TCR", "TRR", "LWC", "LSWC", "SPCE", "GAME-KING",
            )
            # Try to find the boundary
            tok_match = re.search(
                rf"\s+(?:{'|'.join(STYLE_TOKENS)})\b",
                alt_clean,
                re.IGNORECASE,
            )
            if tok_match:
                caliber_raw = alt_clean[:tok_match.start()].strip()
            else:
                caliber_raw = alt_clean
            caliber = normalize_caliber(caliber_raw)
            tds = re.findall(r"<t[hd][^>]*>(.*?)</t[hd]>", tr, re.DOTALL)
            cells = []
            for td in tds:
                t = re.sub(r"<[^>]+>", " ", td)
                t = unescape(t)
                t = re.sub(r"\s+", " ", t).strip()
                t = t.replace("\xa0", " ")
                cells.append(t)
            if len(cells) < 30:
                continue
            # Catalog number
            cat_no = cells[1] if cells[1].startswith("V") else ""
            try:
                weight_grs = float(cells[4])
            except (ValueError, IndexError):
                continue
            if not (5 <= weight_grs <= 1000):
                continue
            try:
                # Cells use comma as thousands separator (e.g. "1,122")
                v0_str = cells[9].replace(",", "").replace(" ", "")
                v0_ms = float(v0_str)
            except (ValueError, IndexError):
                continue
            mv_fps = int(round(v0_ms / 0.3048))
            if not (200 <= mv_fps <= 5000):
                continue
            # Find BC pair
            bc_g1 = None
            bc_g7 = None
            for i in range(min(len(cells) - 1, 36)):
                a = cells[i].replace(",", ".").replace(" ", "")
                b = cells[i + 1].replace(",", ".").replace(" ", "")
                if not re.match(r"^0?\.\d+$", a):
                    continue
                if not re.match(r"^0?\.\d+$", b):
                    continue
                try:
                    g1 = float(a)
                    g7 = float(b)
                except ValueError:
                    continue
                if 0.05 <= g1 <= 1.5 and 0.05 <= g7 <= 1.5 and g7 < g1:
                    bc_g1 = g1
                    bc_g7 = g7
                    break
            if bc_g1 is None:
                continue
            bullet_type = cells[3] if len(cells) > 3 else ""
            rows.append({
                "manufacturer": "Sellier & Bellot",
                "line": line_name,
                "caliber": caliber,
                "bulletWeightGr": weight_grs,
                "factoryMvFps": mv_fps,
                "bcG1": round(bc_g1, 3),
                "bcG7": round(bc_g7, 3),
                "bulletLengthIn": None,
                "application": application,
                "notes": f"{bullet_type} — {cat_no}" if cat_no else bullet_type,
            })
    return rows


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", "-o", type=Path, required=True)
    parser.add_argument("--throttle", type=float, default=0.2)
    args = parser.parse_args(argv)

    rows: list[dict] = []
    seen_keys: set = set()
    failed = 0
    for ui, path in enumerate(LINE_PAGES, start=1):
        url = ORIGIN + path
        try:
            html = _http_get(url)
        except Exception as e:
            failed += 1
            sys.stderr.write(f"[{ui}/{len(LINE_PAGES)}] FAIL {type(e).__name__}: {e}\n")
            continue
        page_rows = parse_line_page(url, html)
        for row in page_rows:
            key = (row["caliber"], row["bulletWeightGr"], row["line"], row["notes"])
            if key not in seen_keys:
                seen_keys.add(key)
                rows.append(row)
        sys.stderr.write(f"[{ui}/{len(LINE_PAGES)}] {path.split('/')[-2]}: +{len(page_rows)} (total {len(rows)})\n")
        time.sleep(args.throttle)

    sys.stderr.write(f"Total: {len(rows)} rows kept, {failed} failed\n")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(rows, indent=2) + "\n")
    sys.stderr.write(f"Wrote {args.output}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
