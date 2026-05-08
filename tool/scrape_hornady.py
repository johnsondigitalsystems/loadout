#!/usr/bin/env python3
"""Scrape Hornady factory ammunition specs from product detail pages.

Hornady's site at https://www.hornady.com renders each ammunition SKU
as a per-product page like
``https://www.hornady.com/ammunition/rifle/6-5-creedmoor-140-gr-eld-match``.
Each page embeds the full product record inline as a single JS variable
``var item = { ... };`` — including:

* ``cartridgename`` — caliber as printed on the box
* ``weight`` — bullet weight in grains
* ``ball_coef`` (G1) and ``ball_coef_2`` (G7)
* ``muzzlevelocity`` — published muzzle velocity (fps)
* ``sku`` — Hornady part number
* ``linktitle`` — the product line ("Match", "Precision Hunter", etc.)
* ``bullettitle`` — bullet style ("140 gr ELD Match")
* ``applicationname`` — Hunting / Target/Match / Defense / etc.

We discover the full SKU list by parsing
``https://www.hornady.com/sitemap.xml`` for ``/ammunition/<category>/<slug>``
URLs (rifle, handgun, rimfire, shotgun) and visiting each.

Output schema mirrors ``factory_loads.json``:

    {
      "manufacturer": "Hornady",
      "line": "<linktitle>",
      "caliber": "<cartridgename>",
      "bulletWeightGr": <weight>,
      "factoryMvFps": <muzzlevelocity>,
      "bcG1": <ball_coef or null>,
      "bcG7": <ball_coef_2 or null>,
      "bulletLengthIn": null,
      "application": "<derived from applicationname>",
      "notes": "<bullet style> — <sku>"
    }

Polite throttling: 0.15s between requests. Hornady's CDN is a generous
host but it's nice to be a good citizen.

Usage::

    python3 tool/scrape_hornady.py --output /tmp/hornady_factory_loads.json
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

ORIGIN = "https://www.hornady.com"
SITEMAP_URL = f"{ORIGIN}/sitemap.xml"
HEADERS = {
    "User-Agent": "LoadOut-FactoryLoadsScraper/1.0",
    "Accept": "text/html,application/xhtml+xml",
}

APPLICATION_MAP = {
    "Target/Match": "match",
    "Match": "match",
    "Big Game Hunting": "hunting",
    "Hunting": "hunting",
    "Varmint": "varmint",
    "Varmint Hunting": "varmint",
    "Predator": "varmint",
    "Self Defense": "defense",
    "Personal Defense": "defense",
    "Personal Protection": "defense",
    "Defense": "defense",
    "Tactical": "defense",
    "Law Enforcement": "defense",
    "Cowboy Action": "target",
    "Hog/Boar": "hunting",
    "Dangerous Game": "hunting",
    "Plinking/Training": "target",
    "Practice": "target",
}


def _http_get(url: str, *, timeout: float = 20.0) -> str:
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8", errors="replace")


def fetch_ammunition_urls() -> list[str]:
    """Pull the sitemap and return every /ammunition/<cat>/<slug> URL."""
    xml = _http_get(SITEMAP_URL)
    locs = re.findall(r"<loc>([^<]+)</loc>", xml)
    out = []
    for u in locs:
        if "/ammunition/" not in u:
            continue
        path = u.split("/ammunition/", 1)[1].strip("/")
        if not path:
            continue
        # Skip top-level line pages (one slash component is the line, two is a SKU page).
        if "/" not in path:
            continue
        # Filter out non-product pages like search results.
        first, rest = path.split("/", 1)
        if first not in {"rifle", "handgun", "rimfire", "shotgun"}:
            continue
        if not rest:
            continue
        out.append(u)
    return sorted(set(out))


def extract_item_json(html: str) -> dict | None:
    """Pull the ``var item = {...};`` JSON literal from the page HTML.

    Hornady's HTML serializer emits valid JSON inside a JS variable
    declaration. We balance braces to find the end of the object since
    the content can contain ``}`` characters inside string values.
    """
    start_marker = "var item = {"
    start = html.find(start_marker)
    if start < 0:
        return None
    i = start + len("var item = ")
    depth = 0
    end = -1
    while i < len(html):
        c = html[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break
        elif c == "\\":
            # JS string escape — skip the next char.
            i += 2
            continue
        elif c in ("'", '"'):
            # Skip past the string literal.
            quote = c
            i += 1
            while i < len(html):
                if html[i] == "\\":
                    i += 2
                    continue
                if html[i] == quote:
                    break
                i += 1
        i += 1
    if end < 0:
        return None
    raw = html[start + len("var item = "): end]
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return None


def strip_html(s: str) -> str:
    if not s:
        return ""
    s = unescape(s)
    s = re.sub(r"<[^>]+>", "", s)
    s = re.sub(r"\s+", " ", s).strip()
    # Hornady marks trade & registered with sup tags + ™/®. Drop the symbols
    # so the line names match the existing factory_loads.json conventions.
    s = s.replace("™", "").replace("®", "").strip()
    return s


def application_for(name: str) -> str:
    if not name:
        return "general"
    name = name.strip()
    if name in APPLICATION_MAP:
        return APPLICATION_MAP[name]
    n = name.lower()
    if "match" in n or "target" in n:
        return "match"
    if "varmint" in n or "predator" in n:
        return "varmint"
    if "defense" in n or "tactical" in n or "duty" in n:
        return "defense"
    if "hunt" in n or "game" in n or "deer" in n:
        return "hunting"
    if "rimfire" in n:
        return "rimfire"
    return "general"


def parse_bc(v) -> float | None:
    if v is None:
        return None
    try:
        f = float(v)
    except (TypeError, ValueError):
        return None
    if 0.001 <= f <= 1.5:
        return round(f, 3)
    return None


def parse_mv(v) -> int | None:
    if v is None:
        return None
    try:
        f = float(v)
    except (TypeError, ValueError):
        return None
    iv = int(round(f))
    if 200 <= iv <= 5000:
        return iv
    return None


def parse_weight(v) -> float | None:
    if v is None:
        return None
    try:
        f = float(v)
    except (TypeError, ValueError):
        return None
    if 5 <= f <= 1000:
        return float(f)
    return None


def normalize_caliber(s: str) -> str:
    return strip_html(s)


def make_row(item: dict) -> dict | None:
    weight = parse_weight(item.get("weight"))
    if weight is None:
        return None
    caliber = normalize_caliber(item.get("cartridgename") or "")
    if not caliber:
        return None
    mv = parse_mv(item.get("muzzlevelocity"))
    if mv is None:
        return None
    bc1 = parse_bc(item.get("ball_coef"))
    bc7 = parse_bc(item.get("ball_coef_2"))
    # Skip rows with no usable BC at all - the calculator can't use them.
    if bc1 is None and bc7 is None:
        return None
    line = strip_html(item.get("linktitle") or "")
    bullet_title = strip_html(item.get("bullettitle") or "")
    sku = (item.get("sku") or "").strip()
    application = application_for(item.get("applicationname") or "")
    notes = bullet_title
    if sku:
        notes = f"{notes} — {sku}" if notes else sku
    return {
        "manufacturer": "Hornady",
        "line": line,
        "caliber": caliber,
        "bulletWeightGr": weight,
        "factoryMvFps": mv,
        "bcG1": bc1,
        "bcG7": bc7,
        "bulletLengthIn": None,
        "application": application,
        "notes": notes,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", "-o", type=Path, required=True)
    parser.add_argument("--throttle", type=float, default=0.15)
    parser.add_argument("--limit", type=int, default=0,
                        help="Only fetch first N urls (debugging)")
    args = parser.parse_args(argv)

    sys.stderr.write("Fetching sitemap...\n")
    urls = fetch_ammunition_urls()
    sys.stderr.write(f"  {len(urls)} ammunition product URLs\n")
    if args.limit:
        urls = urls[: args.limit]

    rows: list[dict] = []
    seen_keys: set = set()
    fail_count = 0
    skipped = 0

    for ui, url in enumerate(urls, start=1):
        try:
            html = _http_get(url)
        except urllib.error.HTTPError as e:
            sys.stderr.write(f"[{ui}/{len(urls)}] HTTP {e.code} {url}\n")
            fail_count += 1
            continue
        except Exception as e:
            sys.stderr.write(f"[{ui}/{len(urls)}] FAIL {type(e).__name__}: {e}\n")
            fail_count += 1
            continue
        item = extract_item_json(html)
        if item is None:
            sys.stderr.write(f"[{ui}/{len(urls)}] no item JSON: {url}\n")
            skipped += 1
            continue
        row = make_row(item)
        if row is None:
            skipped += 1
            sys.stderr.write(f"[{ui}/{len(urls)}] skipped (incomplete data): {url}\n")
        else:
            key = (row["caliber"], row["bulletWeightGr"], row["line"], row["notes"])
            if key in seen_keys:
                skipped += 1
            else:
                seen_keys.add(key)
                rows.append(row)
                if ui % 50 == 0:
                    sys.stderr.write(f"[{ui}/{len(urls)}] {len(rows)} kept, {skipped} skip, {fail_count} fail\n")
        time.sleep(args.throttle)

    sys.stderr.write(f"Total: {len(rows)} rows kept, {skipped} skipped, {fail_count} failed\n")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(rows, indent=2) + "\n")
    sys.stderr.write(f"Wrote {args.output}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
