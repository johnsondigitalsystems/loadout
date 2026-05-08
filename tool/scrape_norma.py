#!/usr/bin/env python3
"""Scrape Norma factory ammunition specs from product detail pages.

Norma's site at https://www.norma-ammunition.com publishes one detail
page per SKU, each one embedding a schema.org ``Product`` JSON-LD blob
with these properties via ``additionalProperty`` entries:

* Caliber (e.g. "300 PRC")
* Weight (grains) and Weight (grams)
* Ballistic Coefficient (G1)
* Category (intent — "Dedicated Hunting" / "Match" / etc.)
* Product Type ("cartridge")

The same page also contains a velocity table in a structured form. The
muzzle velocity is the V0 column ("V0 930 m/s 3051 f/s") which we
extract via regex when the JSON-LD doesn't carry it.

We discover URLs from
``https://www.norma-ammunition.com/products/sitemap/sitemap-products-en.xml``
and skip ``/components/`` (those are bullets / brass / powder, not
loaded ammunition).

Output schema mirrors ``factory_loads.json``.

Usage::

    python3 tool/scrape_norma.py --output /tmp/norma_factory_loads.json
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

ORIGIN = "https://www.norma-ammunition.com"
SITEMAP = f"{ORIGIN}/products/sitemap/sitemap-products-en.xml"
HEADERS = {
    "User-Agent": "LoadOut-FactoryLoadsScraper/1.0",
    "Accept": "text/html",
}

LINE_FROM_URL = re.compile(r"/(hunting|shooting)/(?P<line>norma[-\w]+)/")
APPLICATION_FOR_CATEGORY = {
    "Dedicated Hunting": "hunting",
    "Match": "match",
    "Match - Sniper": "match",
    "Sport Shooting": "match",
    "Self-Defense": "defense",
    "Practice": "target",
    "Training": "target",
    "Plinking": "target",
    "Target Shooting": "match",
}


def _http_get(url: str, *, timeout: float = 25.0) -> str:
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8", errors="replace")


def fetch_urls() -> list[str]:
    xml = _http_get(SITEMAP)
    locs = re.findall(r"<loc>([^<]+)</loc>", xml)
    out: list[str] = []
    for u in locs:
        if "/products/components/" in u:
            continue
        if u.count("/") < 6:
            continue
        out.append(u)
    return sorted(set(out))


def extract_jsonld(html: str) -> list[dict]:
    """Return all JSON-LD <script> bodies parsed."""
    out: list[dict] = []
    for m in re.finditer(
        r'<script[^>]+type="application/ld\+json"[^>]*>(.+?)</script>',
        html,
        re.DOTALL,
    ):
        body = m.group(1).strip()
        try:
            obj = json.loads(body)
        except json.JSONDecodeError:
            continue
        if isinstance(obj, list):
            out.extend(o for o in obj if isinstance(o, dict))
        elif isinstance(obj, dict):
            out.append(obj)
    return out


def parse_v0_fps(html: str) -> int | None:
    """Pull the muzzle velocity in fps from the page text.

    Norma renders a table of velocities V0..V300; we want V0 in
    feet/second. The pattern is ``V0 930 m/s 3051 f/s``.
    """
    text = re.sub(r"<[^>]*>", " ", html)
    text = re.sub(r"\s+", " ", text)
    m = re.search(r"V0\s+\d+(?:\.\d+)?\s*m/s\s+(\d+)\s*f/s", text, re.I)
    if m:
        v = int(m.group(1))
        if 200 <= v <= 5000:
            return v
    # Fallback: just first ``XXXX f/s`` after V0
    m = re.search(r"V0[^V]*?(\d{3,4})\s*f/s", text, re.I)
    if m:
        v = int(m.group(1))
        if 200 <= v <= 5000:
            return v
    return None


def make_row(url: str, html: str) -> dict | None:
    jsonlds = extract_jsonld(html)
    product = None
    for j in jsonlds:
        if j.get("@type") == "Product":
            product = j
            break
    if not product:
        return None
    name = product.get("name", "").strip()
    sku = (product.get("sku") or "").strip()
    brand = (product.get("brand") or {}).get("name", "")
    props = {p.get("name"): p.get("value")
             for p in product.get("additionalProperty", []) or []}
    caliber = (props.get("Caliber") or "").strip()
    if not caliber:
        return None
    weight_grains = props.get("Weight (grains)")
    if weight_grains is None:
        return None
    try:
        weight = float(weight_grains)
    except (TypeError, ValueError):
        return None
    if not (5 <= weight <= 1000):
        return None
    bc1 = props.get("Ballistic Coefficient (G1)")
    bc7 = props.get("Ballistic Coefficient (G7)")
    try:
        bc1 = float(bc1) if bc1 is not None else None
    except (TypeError, ValueError):
        bc1 = None
    try:
        bc7 = float(bc7) if bc7 is not None else None
    except (TypeError, ValueError):
        bc7 = None
    if bc1 is None and bc7 is None:
        return None
    if bc1 is not None and not (0.05 <= bc1 <= 1.5):
        bc1 = None
    if bc7 is not None and not (0.05 <= bc7 <= 1.5):
        bc7 = None
    if bc1 is None and bc7 is None:
        return None

    mv = parse_v0_fps(html)
    if mv is None:
        return None

    category = props.get("Category") or ""
    application = APPLICATION_FOR_CATEGORY.get(category)
    if application is None:
        cl = category.lower()
        if "match" in cl or "sport" in cl:
            application = "match"
        elif "hunt" in cl:
            application = "hunting"
        elif "defense" in cl or "duty" in cl:
            application = "defense"
        elif "practice" in cl or "training" in cl or "plink" in cl:
            application = "target"
        else:
            application = "general"

    line = brand
    # Strip "Norma " prefix from brand names ("Norma Odin" -> "Odin")
    if line.lower().startswith("norma "):
        line = line[6:]
    if not line:
        url_match = LINE_FROM_URL.search(url)
        if url_match:
            line = url_match.group("line")
            line = line.replace("norma-", "").replace("-", " ").title()
    if not line:
        line = "Norma"

    notes_bits = [name]
    if sku:
        notes_bits.append(sku)
    notes = " — ".join(notes_bits)

    return {
        "manufacturer": "Norma",
        "line": line,
        "caliber": caliber,
        "bulletWeightGr": weight,
        "factoryMvFps": mv,
        "bcG1": round(bc1, 3) if bc1 is not None else None,
        "bcG7": round(bc7, 3) if bc7 is not None else None,
        "bulletLengthIn": None,
        "application": application,
        "notes": notes,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", "-o", type=Path, required=True)
    parser.add_argument("--throttle", type=float, default=0.15)
    parser.add_argument("--limit", type=int, default=0)
    args = parser.parse_args(argv)

    sys.stderr.write("Fetching Norma sitemap...\n")
    urls = fetch_urls()
    sys.stderr.write(f"  {len(urls)} candidate URLs\n")
    if args.limit:
        urls = urls[: args.limit]

    rows: list[dict] = []
    seen_keys: set = set()
    skipped = 0
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
        row = make_row(url, html)
        if row is None:
            skipped += 1
        else:
            key = (row["caliber"], row["bulletWeightGr"], row["line"], row["notes"])
            if key in seen_keys:
                skipped += 1
            else:
                seen_keys.add(key)
                rows.append(row)
                if ui % 50 == 0:
                    sys.stderr.write(f"[{ui}/{len(urls)}] kept {len(rows)} skip {skipped} fail {failed}\n")
        time.sleep(args.throttle)

    sys.stderr.write(f"Total: {len(rows)} rows kept, {skipped} skipped, {failed} failed\n")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(rows, indent=2) + "\n")
    sys.stderr.write(f"Wrote {args.output}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
