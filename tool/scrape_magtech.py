#!/usr/bin/env python3
"""Scrape Magtech factory ammunition specs via WordPress REST API.

Magtech's site at https://magtechammunition.com is a WordPress site
exposing the full product catalog via the WP REST API at
``/wp-json/wp/v2/produto?per_page=100&page=N``. Each produto entry
includes an ``acf`` object with:

* bullet_style ("LWC", "FMJ", etc.)
* bullet_weight (grains as a string)
* desc_ballistic_coeficient ("0.055" — G1 BC)
* desc_symbol (catalog SKU like "38B")
* muzzle.velocity (m/s) + muzzley.velocity (fps)

Plus the title encodes caliber + weight + style.

Output schema mirrors ``factory_loads.json``.

Usage::

    python3 tool/scrape_magtech.py --output /tmp/magtech_factory_loads.json
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

ORIGIN = "https://magtechammunition.com"
HEADERS = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0)"}


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


def fetch_all_products() -> list[dict]:
    out: list[dict] = []
    page = 1
    while True:
        url = f"{ORIGIN}/wp-json/wp/v2/produto?per_page=100&page={page}"
        try:
            body = _http_get(url)
        except Exception as e:
            sys.stderr.write(f"  page {page} FAIL: {e}\n")
            break
        try:
            data = json.loads(body)
        except json.JSONDecodeError:
            break
        if not isinstance(data, list) or not data:
            break
        out.extend(data)
        sys.stderr.write(f"  page {page}: +{len(data)} (total {len(out)})\n")
        if len(data) < 100:
            break
        page += 1
        time.sleep(0.2)
    return out


CALIBER_NORMALIZER = {
    "32 auto": ".32 Auto",
    "380 auto": ".380 Auto",
    "9mm luger": "9mm Luger",
    "9mm luger+p": "9mm Luger +P",
    "40 sw": ".40 S&W",
    "45 auto": ".45 Auto",
    "38 spl": ".38 Special",
    "38 spl+p": ".38 Special +P",
    "357 mag": ".357 Magnum",
    "44 mag": ".44 Remington Magnum",
    "10mm": "10mm Auto",
    "30-30 win": ".30-30 Winchester",
    "30-06 sprg": ".30-06 Springfield",
    "308 win": ".308 Winchester",
    "270 win": ".270 Winchester",
    "243 win": ".243 Winchester",
    "223 rem": ".223 Remington",
    "300 blk": ".300 AAC Blackout",
    "300 blackout": ".300 AAC Blackout",
    "5.56 nato": "5.56x45mm NATO",
    "5.56x45": "5.56x45mm NATO",
    "5.56x45mm": "5.56x45mm NATO",
    "7.62 nato": "7.62x51mm NATO",
    "22 lr": ".22 Long Rifle",
    "22 mag": ".22 WMR",
    "454 casull": ".454 Casull",
    "44-40": ".44-40 Winchester",
    "45 colt": ".45 Colt",
    "300 win mag": ".300 Winchester Magnum",
    "338 lapua mag": ".338 Lapua Magnum",
    "7mm rem mag": "7mm Remington Magnum",
    "8x57 js": "8x57 JS",
    "6.5 creedmoor": "6.5 Creedmoor",
    "6.5x55": "6.5x55 SE",
    "300 prc": ".300 PRC",
    "6.5 prc": "6.5 PRC",
    "300 norma mag": ".300 Norma Magnum",
}


def parse_caliber_and_weight(title: str) -> tuple[str | None, float | None, str]:
    """Title format: "9MM LUGER 115GR FMJ" or "300 WSM 165GR SP" etc."""
    if not title:
        return None, None, ""
    s = unescape(title).strip()
    # Drop anything after a parenthesis
    s = re.sub(r"\s*\([^)]*\)\s*", "", s).strip()
    # Match: <CALIBER> <WEIGHT>GR <STYLE>
    m = re.match(
        r"(?P<cal>.+?)\s+(?P<gr>\d+(?:\.\d+)?)\s*GR\s*(?P<style>.+?)$",
        s,
        re.IGNORECASE,
    )
    if not m:
        return None, None, ""
    cal_raw = m.group("cal").strip()
    grains = float(m.group("gr"))
    style = m.group("style").strip()
    # Cleanup caliber: lowercase + lookup
    cal_key = cal_raw.lower().strip()
    cal = CALIBER_NORMALIZER.get(cal_key, cal_raw)
    return cal, grains, style


def application_for(style: str, line: str | None = None) -> str:
    s = (style or "").lower() + " " + (line or "").lower()
    if "match" in s or "target" in s or "competition" in s or "smk" in s:
        return "match"
    if "defense" in s or "tactical" in s or "guardian" in s or "+p" in s:
        return "defense"
    if "varmint" in s or "predator" in s:
        return "varmint"
    if "fmj" in s or "lrn" in s or "lswc" in s or "lwc" in s or "range" in s or "training" in s:
        return "target"
    if "hunt" in s or "sp" in s or "jsp" in s or "fmj-deer" in s:
        return "hunting"
    return "general"


def make_row(product: dict) -> dict | None:
    title_raw = (product.get("title") or {}).get("rendered") or ""
    if not title_raw:
        return None
    title = re.sub(r"<[^>]+>", "", title_raw)
    title = unescape(title).strip()
    cal, weight, style = parse_caliber_and_weight(title)
    if cal is None or weight is None:
        return None
    acf = product.get("acf") or {}
    bc_str = acf.get("desc_ballistic_coeficient") or ""
    try:
        bc = float(str(bc_str).replace(",", "."))
    except ValueError:
        bc = None
    if bc is None or not (0.05 <= bc <= 1.5):
        return None
    # Imperial muzzle velocity (fps) is in `muzzley.velocity`.
    muzzley = acf.get("muzzley") or {}
    mv_str = muzzley.get("velocity") or ""
    try:
        mv_fps = int(re.sub(r"[^\d]", "", str(mv_str))) if mv_str else 0
    except (TypeError, ValueError):
        mv_fps = 0
    if not (200 <= mv_fps <= 5000):
        # Try metric muzzle velocity if imperial missing
        muzzle = acf.get("muzzle") or {}
        mv_ms_str = muzzle.get("velocity") or ""
        try:
            mv_ms = int(re.sub(r"[^\d]", "", str(mv_ms_str))) if mv_ms_str else 0
            if 100 <= mv_ms <= 1500:
                mv_fps = int(round(mv_ms / 0.3048))
        except (TypeError, ValueError):
            pass
    if not (200 <= mv_fps <= 5000):
        return None

    sku = acf.get("desc_symbol") or ""
    line = "Magtech"  # Magtech doesn't expose a marketing line clearly
    application = application_for(style)
    notes = style if style else title
    if sku:
        notes = f"{notes} — {sku}" if notes else sku

    return {
        "manufacturer": "Magtech",
        "line": line,
        "caliber": cal,
        "bulletWeightGr": weight,
        "factoryMvFps": mv_fps,
        "bcG1": round(bc, 3),
        "bcG7": None,
        "bulletLengthIn": None,
        "application": application,
        "notes": notes,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", "-o", type=Path, required=True)
    args = parser.parse_args(argv)

    sys.stderr.write("Fetching Magtech products...\n")
    products = fetch_all_products()
    sys.stderr.write(f"  {len(products)} products\n")

    rows: list[dict] = []
    seen_keys: set = set()
    skipped = 0
    for p in products:
        row = make_row(p)
        if row is None:
            skipped += 1
            continue
        key = (row["caliber"], row["bulletWeightGr"], row["line"], row["notes"])
        if key in seen_keys:
            skipped += 1
        else:
            seen_keys.add(key)
            rows.append(row)

    sys.stderr.write(f"Total: {len(rows)} rows kept, {skipped} skipped\n")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(rows, indent=2) + "\n")
    sys.stderr.write(f"Wrote {args.output}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
