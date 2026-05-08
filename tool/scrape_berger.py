#!/usr/bin/env python3
"""Scrape Berger Bullets factory ammunition specs from product pages.

Berger's site at https://bergerbullets.com/ ships ammunition as
WooCommerce products under
``https://bergerbullets.com/product/<slug>``. Each product page has a
``<table class="woocommerce-product-attributes">`` block with the
specs we need:

* "Bullet Weight" (e.g. "140 Grain")
* "G1 BC" / "G7 BC"
* "Muzzle Velocity (fps)"
* "Caliber" — sometimes attribute, sometimes embedded in title

URL discovery: ``https://bergerbullets.com/product-sitemap.xml``.

Output schema mirrors ``factory_loads.json``.

Usage::

    python3 tool/scrape_berger.py --output /tmp/berger_factory_loads.json
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

ORIGIN = "https://bergerbullets.com"
SITEMAP = f"{ORIGIN}/product-sitemap.xml"
HEADERS = {
    "User-Agent": "LoadOut-FactoryLoadsScraper/1.0",
    "Accept": "text/html",
}

# Map Berger product line slugs to display names + applications.
LINE_DEFINITIONS = [
    ("elite-hunter", "Elite Hunter", "hunting"),
    ("classic-hybrid-hunter", "Classic Hybrid Hunter", "hunting"),
    ("classic-hunter", "Classic Hunter", "hunting"),
    ("hybrid-target", "Hybrid Target", "match"),
    ("long-range-hybrid-target", "Long Range Hybrid Target", "match"),
    ("otm-tactical", "OTM Tactical", "match"),
    ("target", "Target", "match"),
    ("match-grade", "Match Grade", "match"),
    ("eol-elite-hunter", "EOL Elite Hunter", "hunting"),
]


def _http_get(url: str, *, timeout: float = 25.0) -> str:
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8", errors="replace")


def fetch_product_urls() -> list[str]:
    xml = _http_get(SITEMAP)
    locs = re.findall(r"<loc>([^<]+)</loc>", xml)
    return sorted(set(u for u in locs if "/product/" in u and ("ammunition" in u or "ammo" in u)))


_ATTR_ROW_RE = re.compile(
    r'<tr[^>]*woocommerce-product-attributes-item--attribute_(?P<key>[a-z0-9_-]+)[^>]*>.*?'
    r'<th[^>]*>(?P<label>[^<]+)</th>.*?'
    r'<td[^>]*>(?P<value>.*?)</td>',
    re.DOTALL,
)


def parse_product_attributes(html: str) -> dict[str, str]:
    """Pull the WooCommerce attributes table into a dict."""
    out: dict[str, str] = {}
    for m in _ATTR_ROW_RE.finditer(html):
        key = m.group("key")
        # Strip the value down to plain text
        val = m.group("value")
        val = re.sub(r"<[^>]+>", " ", val)
        val = unescape(val).strip()
        val = re.sub(r"\s+", " ", val)
        if val:
            out[key] = val
    return out


def parse_jsonld(html: str) -> dict | None:
    for m in re.finditer(
        r'<script[^>]+type="application/ld\+json"[^>]*>(.+?)</script>',
        html,
        re.DOTALL,
    ):
        try:
            obj = json.loads(m.group(1))
        except json.JSONDecodeError:
            continue
        if isinstance(obj, dict):
            if obj.get("@type") == "Product":
                return obj
            if isinstance(obj.get("@graph"), list):
                for x in obj["@graph"]:
                    if isinstance(x, dict) and x.get("@type") == "Product":
                        return x
        elif isinstance(obj, list):
            for x in obj:
                if isinstance(x, dict) and x.get("@type") == "Product":
                    return x
    return None


def parse_int(s: str) -> int | None:
    if not s:
        return None
    m = re.search(r"(\d+(?:,\d{3})*)", s)
    if not m:
        return None
    try:
        return int(m.group(1).replace(",", ""))
    except ValueError:
        return None


def parse_float(s: str) -> float | None:
    if not s:
        return None
    m = re.search(r"(\d+(?:\.\d+)?)", s)
    if not m:
        return None
    try:
        return float(m.group(1))
    except ValueError:
        return None


def line_for_url(url: str) -> tuple[str, str] | None:
    for slug, display, app in LINE_DEFINITIONS:
        if slug in url:
            return display, app
    return None


def caliber_for_url(url: str) -> str | None:
    """Convert Berger URL slug to a caliber string.

    URLs follow ``https://bergerbullets.com/product/<caliber-slug>-<weight>gr-<line>-rifle-ammunition/``.
    We can pluck the caliber by stripping the line and weight tokens.
    """
    slug = url.rstrip("/").split("/")[-1]
    # Drop trailing "-rifle-ammunition"
    slug = re.sub(r"-rifle-ammunition$", "", slug)
    slug = re.sub(r"-ammunition$", "", slug)
    # Drop the line token from end
    for line_slug, _disp, _app in LINE_DEFINITIONS:
        slug = re.sub(rf"-{line_slug}(?:-|$)", "", slug)
    # Drop the weight (ends in "gr" or "grain")
    slug = re.sub(r"-\d+(?:-\d+)?(?:gr|grain).*$", "", slug)
    # Convert to caliber form
    cal = slug.replace("-", " ")
    return cal.strip() or None


CALIBER_NORMALIZER = {
    "6 5 mm creedmoor": "6.5 Creedmoor",
    "6 5 creedmoor": "6.5 Creedmoor",
    "6 5 prc": "6.5 PRC",
    "6 mm creedmoor": "6mm Creedmoor",
    "300 norma magnum": "300 Norma Magnum",
    "300 prc": "300 PRC",
    "300 winchester magnum": "300 Win Mag",
    "300 win mag": "300 Win Mag",
    "300 winchester short magnum wsm": "300 WSM",
    "300 winchester short magnum": "300 WSM",
    "338 lapua magnum": "338 Lapua Magnum",
    "338 lapua mag": "338 Lapua Magnum",
    "300 weatherby magnum": "300 Weatherby Magnum",
    "260 remington": ".260 Remington",
    "223 remington": ".223 Remington",
    "243 winchester": ".243 Winchester",
    "243 win": ".243 Winchester",
    "270 winchester": ".270 Winchester",
    "270 win": ".270 Winchester",
    "270 wsm": ".270 WSM",
    "30 06 springfield": ".30-06 Springfield",
    "30 06": ".30-06 Springfield",
    "308 winchester": ".308 Winchester",
    "308 win": ".308 Winchester",
    "7 mm magnum": "7mm Rem Magnum",
    "7 mm rem mag": "7mm Rem Magnum",
    "7mm rem mag": "7mm Rem Magnum",
    "7 mm prc": "7mm PRC",
    "7mm prc": "7mm PRC",
    "7 mm 08 remington": "7mm-08 Remington",
    "7 mm 08": "7mm-08 Remington",
    "7mm 08": "7mm-08 Remington",
    "375 cheytac": ".375 CheyTac",
    "338 norma magnum": ".338 Norma Magnum",
    "338 win mag": ".338 Winchester Magnum",
    "6 5 grendel": "6.5 Grendel",
    "224 valkyrie": "224 Valkyrie",
    "22 250 remington": ".22-250 Remington",
    "22 250 rem": ".22-250 Remington",
    "270 wby mag": ".270 Weatherby Magnum",
    "270 weatherby magnum": ".270 Weatherby Magnum",
    "26 nosler": "26 Nosler",
    "28 nosler": "28 Nosler",
    "30 nosler": "30 Nosler",
    "33 nosler": "33 Nosler",
    "375 hh magnum": ".375 H&H Magnum",
    "375 h h magnum": ".375 H&H Magnum",
}


def normalize_caliber(c: str) -> str:
    if not c:
        return c
    key = c.lower().strip()
    return CALIBER_NORMALIZER.get(key, c.strip())


def make_row(url: str, html: str) -> dict | None:
    attrs = parse_product_attributes(html)
    if not attrs:
        return None
    weight = parse_int(attrs.get("pa_bullet-weight") or attrs.get("bullet-weight") or "")
    if weight is None:
        # Try fallback - URL slug
        m = re.search(r"-(\d+)(?:-(\d+))?gr", url)
        if m:
            base = int(m.group(1))
            decimal = m.group(2)
            if decimal:
                weight = float(f"{base}.{decimal}")
            else:
                weight = base
    if weight is None:
        return None
    bc1 = parse_float(attrs.get("pa_g1-bc") or attrs.get("g1-bc") or "")
    bc7 = parse_float(attrs.get("pa_g7-bc") or attrs.get("g7-bc") or "")
    if bc1 is not None and not (0.05 <= bc1 <= 1.5):
        bc1 = None
    if bc7 is not None and not (0.05 <= bc7 <= 1.5):
        bc7 = None
    if bc1 is None and bc7 is None:
        return None
    mv = parse_int(attrs.get("pa_muzzle-velocity") or attrs.get("muzzle-velocity") or "")
    if mv is None or not (200 <= mv <= 5000):
        return None
    caliber = attrs.get("pa_caliber") or attrs.get("caliber") or ""
    if not caliber:
        # Try the URL-derived caliber
        slug_caliber = caliber_for_url(url)
        caliber = slug_caliber or ""
    caliber = normalize_caliber(caliber)
    if not caliber:
        return None

    line_app = line_for_url(url)
    if line_app:
        line, application = line_app
    else:
        # Fallback - guess from URL or attribute
        line = attrs.get("pa_product-line") or attrs.get("product-line") or "Match Grade"
        application = "match"

    # Notes - take product title
    title_m = re.search(r"<h1[^>]*class="
                        r"\"product_title[^\"]*\"[^>]*>([^<]+)</h1>", html)
    title = title_m.group(1).strip() if title_m else ""
    title = unescape(title)

    return {
        "manufacturer": "Berger",
        "line": line,
        "caliber": caliber,
        "bulletWeightGr": float(weight),
        "factoryMvFps": mv,
        "bcG1": round(bc1, 3) if bc1 is not None else None,
        "bcG7": round(bc7, 3) if bc7 is not None else None,
        "bulletLengthIn": None,
        "application": application,
        "notes": title or line,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", "-o", type=Path, required=True)
    parser.add_argument("--throttle", type=float, default=0.15)
    parser.add_argument("--limit", type=int, default=0)
    args = parser.parse_args(argv)

    sys.stderr.write("Fetching Berger sitemap...\n")
    urls = fetch_product_urls()
    sys.stderr.write(f"  {len(urls)} ammunition product URLs\n")
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
        time.sleep(args.throttle)

    sys.stderr.write(f"Total: {len(rows)} rows kept, {skipped} skipped, {failed} failed\n")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(rows, indent=2) + "\n")
    sys.stderr.write(f"Wrote {args.output}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
