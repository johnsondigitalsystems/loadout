#!/usr/bin/env python3
"""Scrape Fiocchi USA factory ammunition specs.

Fiocchi's catalog at https://www.fiocchiusa.com lists ammunition lines
under ``/centerfire-rifle/<line>``, ``/centerfire-pistol/<line>``,
``/rimfire/<line>``, and ``/shotshell/<line>`` (the last is shot
loads which we skip). Each line page shows every SKU in a "Quickview"
block with this layout:

    Quickview Hyperformance Match, 6.5 Creedmoor, 142 Grain, Sierra
    MatchKing HP Boat-Tail, 2675 fps 65CMMKC $52.99 Available
    Grain Weight: 142 Bullet Style: Sierra MatchKing HP Boat-Tail
    Muzzle Velocity: 2675 Ballistic Coefficient: .611
    Package Quantity: 20 Usage: Competition, Target Shooting

We extract:
* Title (line name + caliber + grain + bullet style)
* SKU code (e.g. "65CMMKC")
* Grain weight
* Muzzle velocity (fps)
* Ballistic coefficient (G1)
* Usage (mapped to application)
* Caliber (parsed from title)

URL discovery: ``/sitemap_0.xml``.

Output schema mirrors ``factory_loads.json``.

Usage::

    python3 tool/scrape_fiocchi.py --output /tmp/fiocchi_factory_loads.json
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.request
from html import unescape
from pathlib import Path

ORIGIN = "https://www.fiocchiusa.com"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0)",
    "Accept": "text/html,application/xhtml+xml",
}


def _http_get(url: str, *, timeout: float = 25.0) -> str:
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8", errors="replace")


def fetch_line_urls() -> list[str]:
    sm = _http_get(f"{ORIGIN}/sitemap_index.xml")
    sub = re.findall(r"<loc>([^<]+)</loc>", sm)
    out: list[str] = []
    for sub_url in sub:
        try:
            xml = _http_get(sub_url)
        except Exception:
            continue
        urls = re.findall(r"<loc>([^<]+)</loc>", xml)
        for u in urls:
            path = u.replace(ORIGIN, "").strip("/")
            parts = path.split("/")
            # Lines like /centerfire-rifle/hyperformance-match/
            # Skip the parent listings without a sub-line.
            if len(parts) == 2 and parts[0] in {
                "centerfire-rifle",
                "centerfire-pistol",
                "rimfire",
            }:
                out.append(u)
    return sorted(set(out))


def application_for(usage: str) -> str:
    u = usage.lower()
    if "competition" in u or "target" in u or "match" in u:
        return "match"
    if "varmint" in u or "predator" in u:
        return "varmint"
    if "defense" in u or "tactical" in u or "duty" in u:
        return "defense"
    if "big game" in u or "hunt" in u or "deer" in u:
        return "hunting"
    if "training" in u or "range" in u or "practice" in u or "fmj" in u:
        return "target"
    return "general"


# Caliber list - approximate Fiocchi naming. We extract from the title,
# which has the cartridge name as the second field after the line name.
CALIBER_NORMALIZER = {
    "223 rem": ".223 Remington",
    "243 win": ".243 Winchester",
    "22-250": ".22-250 Remington",
    "270 win": ".270 Winchester",
    "30-06": ".30-06 Springfield",
    "30-06 sprg": ".30-06 Springfield",
    "300 wm": ".300 Winchester Magnum",
    "300 win magnum": ".300 Winchester Magnum",
    "308 win": ".308 Winchester",
    "338 lapua mag": ".338 Lapua Magnum",
    "9mm": "9mm Luger",
    "9mm luger": "9mm Luger",
    "40 sw": ".40 S&W",
    "45 acp": ".45 ACP",
    "38 spl": ".38 Special",
    "357 mag": ".357 Magnum",
    "44 mag": ".44 Remington Magnum",
    "10mm": "10mm Auto",
    "22 lr": ".22 Long Rifle",
    "300 blk": ".300 AAC Blackout",
    "5.7x28": "5.7x28mm",
}


def normalize_caliber(c: str) -> str:
    s = c.strip()
    key = s.lower()
    if key in CALIBER_NORMALIZER:
        return CALIBER_NORMALIZER[key]
    return s


def parse_line_page(url: str, html: str) -> list[dict]:
    rows: list[dict] = []
    text = re.sub(r"<[^>]+>", " ", html)
    text = unescape(text)
    text = re.sub(r"&reg;|&trade;|®|™", "", text)
    text = re.sub(r"\s+", " ", text).strip()

    # Determine line name from URL slug.
    slug = url.rstrip("/").split("/")[-1]
    line_name = slug.replace("-", " ").title()
    # Common renaming
    line_name_overrides = {
        "Hyperformance Match": "Hyperformance Match",
        "Hyperformance Hunt Rifle": "Hyperformance Hunt",
        "Hyperformance Defense Rifle": "Hyperformance Defense",
        "Hyperformance Defense Pistol": "Hyperformance Defense",
        "Field Dynamics": "Field Dynamics",
        "Range Dynamics Rifle": "Range Dynamics",
        "Range Dynamics Pistol": "Range Dynamics",
        "Defense Dynamics Rifle": "Defense Dynamics",
        "Defense Dynamics Pistol": "Defense Dynamics",
        "Cowboy Action Rifle": "Cowboy Action",
        "Backwoods Hunter": "Backwoods Hunter",
    }
    line_name = line_name_overrides.get(line_name, line_name)

    # Match each Quickview block. Title format observed:
    #   Quickview <line>, <caliber>, <grain> Grain, <bullet style>, <mv> fps
    #   <SKU> $<price> Available
    #   Grain Weight: N Bullet Style: ... Muzzle Velocity: N
    #   Ballistic Coefficient: .NNN Package Quantity: N Usage: ...
    block_re = re.compile(
        r"Quickview\s+"
        r"(?P<title>[^,]+,\s*[^,]+,\s*\d+\s*Grain[^Q]+?fps)\s+"
        r"(?P<sku>[A-Z0-9]+)\s+"
        r"\$[\d.]+\s+(?:Available|Sold Out)?\s*"
        r"Grain Weight:\s*(?P<gr>\d+(?:\.\d+)?)\s+"
        r"Bullet Style:\s*(?P<style>.+?)\s+"
        r"Muzzle Velocity:\s*(?P<mv>\d+)\s+"
        r"Ballistic Coefficient:\s*(?P<bc>\.?\d+(?:\.\d+)?)\s+"
        r"Package Quantity:\s*\d+\s+"
        r"Usage:\s*(?P<usage>[^/]+?)\s+(?:Compare|Quickview|/)",
        re.IGNORECASE,
    )

    for m in block_re.finditer(text):
        try:
            grains = float(m.group("gr"))
            mv = int(m.group("mv"))
            bc_str = m.group("bc")
            if bc_str.startswith("."):
                bc = float("0" + bc_str)
            else:
                bc = float(bc_str)
        except (TypeError, ValueError):
            continue
        if not (5 <= grains <= 1000):
            continue
        if not (200 <= mv <= 5000):
            continue
        if not (0.05 <= bc <= 1.5):
            continue
        title = m.group("title").strip()
        # Title is "<line>, <caliber>, <grain> Grain, <bullet>, <mv> fps"
        title_parts = [p.strip() for p in title.split(",")]
        if len(title_parts) < 3:
            continue
        # Caliber is second field
        caliber = title_parts[1]
        caliber = normalize_caliber(caliber)
        bullet_style = m.group("style").strip()
        sku = m.group("sku")
        usage = m.group("usage").strip()
        application = application_for(usage)
        rows.append({
            "manufacturer": "Fiocchi",
            "line": line_name,
            "caliber": caliber,
            "bulletWeightGr": grains,
            "factoryMvFps": mv,
            "bcG1": round(bc, 3),
            "bcG7": None,
            "bulletLengthIn": None,
            "application": application,
            "notes": f"{bullet_style} — {sku}" if sku else bullet_style,
        })
    return rows


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", "-o", type=Path, required=True)
    parser.add_argument("--throttle", type=float, default=0.2)
    args = parser.parse_args(argv)

    sys.stderr.write("Fetching Fiocchi sitemap...\n")
    urls = fetch_line_urls()
    sys.stderr.write(f"  {len(urls)} ammunition pages\n")

    rows: list[dict] = []
    seen_keys: set = set()
    failed = 0
    for ui, url in enumerate(urls, start=1):
        try:
            html = _http_get(url)
        except Exception as e:
            failed += 1
            sys.stderr.write(f"[{ui}/{len(urls)}] FAIL {type(e).__name__}: {e}\n")
            continue
        page_rows = parse_line_page(url, html)
        for row in page_rows:
            key = (row["caliber"], row["bulletWeightGr"], row["line"], row["notes"])
            if key not in seen_keys:
                seen_keys.add(key)
                rows.append(row)
        sys.stderr.write(f"[{ui}/{len(urls)}] {url.split('/')[-2]}/{url.split('/')[-1]}: +{len(page_rows)} (total {len(rows)})\n")
        time.sleep(args.throttle)

    sys.stderr.write(f"Total: {len(rows)} rows kept, {failed} failed\n")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(rows, indent=2) + "\n")
    sys.stderr.write(f"Wrote {args.output}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
