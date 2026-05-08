#!/usr/bin/env python3
"""Scrape Browning Ammunition factory loads from product line pages.

Browning's site at https://browningammo.com renders ammunition lines as
``/Products/Ammunition/<Type>/<Line>`` pages. Each page has a list of
SKU rows with ballistic specs:

* Bullet Weight (grains)
* Ballistic Coefficient (G1)
* Muzzle Velocity (fps)
* Muzzle Energy (ft-lbs)
* Symbol (manufacturer SKU)

Output schema mirrors ``factory_loads.json``.

Usage::

    python3 tool/scrape_browning.py --output /tmp/browning_factory_loads.json
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

ORIGIN = "https://browningammo.com"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0)",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
}


def _http_get(url: str, *, timeout: float = 25.0) -> str:
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8", errors="replace")


def fetch_line_urls() -> list[str]:
    """Return only the per-line ammo pages.

    Skip the top-level rifle/handgun pages — they list every SKU but the
    line name resolves to a generic "Browning Rifle Ammunition" header.
    Per-line pages have a more useful product line name.
    """
    xml = _http_get(f"{ORIGIN}/sitemap.xml")
    locs = re.findall(r"<loc>([^<]+)</loc>", xml)
    out: list[str] = []
    for u in locs:
        if "/Products/Ammunition/" not in u:
            continue
        parts = [p for p in u.replace(ORIGIN, "").split("/") if p]
        # Line pages are at depth 4 (Products/Ammunition/Type/Line)
        if len(parts) == 4 and parts[0] == "Products" and parts[1] == "Ammunition":
            out.append(u)
    return sorted(set(out))


_LINE_NAME_RE = re.compile(
    r'<h1[^>]*>\s*([^<]+?)\s*</h1>',
    re.IGNORECASE,
)


def application_for(text: str) -> str:
    text = text.lower()
    if "match" in text or "target" in text or "competition" in text:
        return "match"
    if "varmint" in text or "predator" in text:
        return "varmint"
    if "duty" in text or "defense" in text or "defender" in text or "tactical" in text:
        return "defense"
    if "hunt" in text or "max-point" in text or "long-range-pro" in text or "silver" in text or "bxr" in text or "bxs" in text or "bxc" in text or "fmj-deer" in text or "tipped":
        return "hunting"
    return "general"


def parse_line_page(url: str, html: str) -> list[dict]:
    """Pull all SKU specs out of a Browning ammunition line page.

    Browning's "compare ammunition" widget renders one block per SKU
    with a consistent label format. We extract via a single regex
    capturing all the fields between "View more" and "Brand:".
    """
    rows: list[dict] = []
    text = re.sub(r"<[^>]+>", " ", html)
    text = unescape(text)
    text = re.sub(r"\s+", " ", text).strip()
    text = text.replace(" ", " ")

    # Browning's H1 is an image; pull line name from <title> instead.
    title_match = re.search(r"<title>([^<]+)</title>", html)
    line_name = title_match.group(1).strip() if title_match else ""
    line_name = unescape(line_name)
    line_name = re.sub(r"\s*\|\s*Browning Ammunition$", "", line_name)
    line_name = re.sub(r"\s*-\s*Browning Ammunition$", "", line_name)
    if not line_name or line_name.lower() in {"home", "ammunition"}:
        line_name = url.rstrip("/").split("/")[-1].replace("-", " ")
    application = application_for(url + " " + line_name)

    block_re = re.compile(
        r"View more\s+"
        r"Cartridge:\s*(?P<cart>.+?)\s+"
        r"Bullet Weight:\s*(?P<weight>\d+(?:\.\d+)?)\s*Grain\s+"
        r"(?:Bullet Type:\s*(?P<btype>.+?)\s+)?"
        r"Ballistic Coefficient:\s*(?P<bc>\d+\.\d+)\s+"
        r"Muzzle Velocity:\s*(?P<mv>\d+)\s+"
        r"Muzzle Energy:\s*\d+\s+"
        r"Rounds per Box:\s*\d+\s+"
        r"Usage:\s*(?P<usage>.*?)\s+"
        r"Symbol:\s*(?P<sku>B\d+)",
        re.IGNORECASE,
    )

    for m in block_re.finditer(text):
        try:
            weight = float(m.group("weight"))
            mv = int(m.group("mv"))
            bc = float(m.group("bc"))
        except (TypeError, ValueError):
            continue
        if not (200 <= mv <= 5000):
            continue
        if not (5 <= weight <= 1000):
            continue
        if not (0.05 <= bc <= 1.5):
            continue
        caliber = m.group("cart").strip()
        # Cleanup caliber - remove any trailing junk
        caliber = re.sub(r"\s+(Bullet|Type|Weight|Ballistic|Muzzle).*$", "", caliber)
        if not caliber:
            continue
        btype = (m.group("btype") or "").strip()
        sku = m.group("sku").strip()
        notes = btype if btype else line_name
        if sku:
            notes = f"{notes} — {sku}"
        rows.append({
            "manufacturer": "Browning",
            "line": line_name,
            "caliber": caliber,
            "bulletWeightGr": weight,
            "factoryMvFps": mv,
            "bcG1": round(bc, 3),
            "bcG7": None,
            "bulletLengthIn": None,
            "application": application,
            "notes": notes,
        })
    return rows


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", "-o", type=Path, required=True)
    parser.add_argument("--throttle", type=float, default=0.2)
    parser.add_argument("--limit", type=int, default=0)
    args = parser.parse_args(argv)

    sys.stderr.write("Fetching Browning sitemap...\n")
    urls = fetch_line_urls()
    sys.stderr.write(f"  {len(urls)} ammunition pages\n")
    if args.limit:
        urls = urls[: args.limit]

    rows: list[dict] = []
    seen_keys: set = set()
    failed = 0
    for ui, url in enumerate(urls, start=1):
        try:
            html = _http_get(url)
        except urllib.error.HTTPError as e:
            failed += 1
            sys.stderr.write(f"[{ui}/{len(urls)}] HTTP {e.code} {url}\n")
            continue
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
        sys.stderr.write(f"[{ui}/{len(urls)}] {url.split('/')[-1]}: +{len(page_rows)} (total {len(rows)})\n")
        time.sleep(args.throttle)

    sys.stderr.write(f"Total: {len(rows)} rows kept, {failed} failed\n")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(rows, indent=2) + "\n")
    sys.stderr.write(f"Wrote {args.output}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
