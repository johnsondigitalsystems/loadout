#!/usr/bin/env python3
"""Scrape RWS factory ammunition specs from product detail pages.

RWS (RUAG / now part of Beretta Defence Technologies) publishes
detailed ballistics for each centerfire / rimfire SKU at
``https://www.rws-ammunition.com/en/products/<category>/<slug>``.

Each product page renders specifications inline (visible text):

    "V0 830 m/s
     E0 3686 J
     MRD 173 m
     ...
     BC value 0.421
     Barrel length 500 mm
     Range Velocity ..."

Plus the title encodes caliber + bullet style + weight (grams).

We extract:
* V0 (m/s -> fps)
* BC value (G1)
* Caliber (parsed from title)
* Bullet weight (grams in URL slug or body, converted to grains)

Output schema mirrors ``factory_loads.json``.

Usage::

    python3 tool/scrape_rws.py --output /tmp/rws_factory_loads.json
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
import urllib.request
from html import unescape
from pathlib import Path

ORIGIN = "https://www.rws-ammunition.com"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0)",
    "Accept": "text/html",
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


def fetch_product_urls() -> list[str]:
    """Discover all centerfire / pistol / rimfire product detail pages."""
    seen: set[str] = set()
    out: list[str] = []
    base_pages = [
        "/en/products/centerfire-rifle-cartridges",
        "/en/products/pistol-cartridges-coup-de-grace-training",
        "/en/products/rimfire-cartridges",
    ]
    for base in base_pages:
        for page in range(1, 12):
            if page == 1:
                url = ORIGIN + base
            else:
                # URL-encode the brackets so curl doesn't interpret them
                # as a glob pattern.
                url = (
                    f"{ORIGIN}{base}/?tx_twruag_ammolist%5B%40widget_0%5D"
                    f"%5BcurrentPage%5D={page}"
                )
            try:
                html = _http_get(url)
            except Exception as e:
                sys.stderr.write(f"  index FAIL {url}: {e}\n")
                break
            hrefs = re.findall(r'href="([^"]+)"', html)
            new = 0
            for h in hrefs:
                if h.startswith("/en/products/"):
                    full = ORIGIN + h
                elif h.startswith("https://www.rws-ammunition.com/en/products/"):
                    full = h
                else:
                    continue
                # Skip pagination URLs (have ?tx_twruag in the path).
                if "?" in full or "#" in full:
                    continue
                # Detail pages have one extra slash beyond the category.
                cat_segments = full.replace(ORIGIN, "").strip("/").count("/")
                if cat_segments < 3:
                    continue
                if full not in seen:
                    seen.add(full)
                    out.append(full)
                    new += 1
            sys.stderr.write(f"  {base} p{page}: +{new} new\n")
            if new == 0 and page > 1:
                break
            time.sleep(0.2)
    return out


CALIBER_FIXES = [
    (re.compile(r"\b6,5\b"), "6.5"),
    (re.compile(r"\b8x57\b", re.I), "8x57"),
    (re.compile(r"\b9,3\b"), "9.3"),
    (re.compile(r"\bMag\b\.?", re.I), "Magnum"),
]


def parse_caliber_from_title(title: str) -> str | None:
    # Title format: "RWS .308 Win Speed Tip Pro Short Rifle 10.7g"
    # We want to pull out ".308 Win" / "6.5 Creedmoor" / etc.
    s = title.strip()
    # Strip RWS prefix
    s = re.sub(r"^RWS\s+", "", s, flags=re.IGNORECASE)
    # Standard cartridge names
    cal_re = re.compile(
        r"^("
        r"\.\d{3}\s*[\w-]+(?:\s+(?:Mag|Magnum|Win|WSM|H&H|Spr|HMR))?"
        r"|\d+(?:[.,]\d+)?\s*x\s*\d+(?:[.,]?\d*)?\s*[\w]*"
        r"|\d+\s*(?:mm|x)\s*[\w]+"
        r"|\d+\s+\w+(?:\s+(?:Mag|Magnum|Win|WSM|H&H|Spr|HMR))?"
        r")"
    )
    m = cal_re.match(s)
    if m:
        cal = m.group(1).strip()
        # Apply fixes
        for pat, rep in CALIBER_FIXES:
            cal = pat.sub(rep, cal)
        return cal
    return None


def parse_weight_from_title(title: str) -> float | None:
    """RWS uses grams in titles like '10.7g'. Convert to grains."""
    m = re.search(r"(\d+(?:[.,]\d+)?)\s*g\b", title, re.IGNORECASE)
    if not m:
        return None
    try:
        grams = float(m.group(1).replace(",", "."))
    except ValueError:
        return None
    grains = grams * 15.4324  # 1 gram = 15.4324 grains
    if 5 <= grains <= 1000:
        return round(grains, 1)
    return None


def extract_specs(html: str) -> tuple[int | None, float | None, str | None]:
    """Return (mv_fps, bc_g1, title)."""
    text = re.sub(r"<script[^>]*>.*?</script>", " ", html, flags=re.DOTALL)
    text = re.sub(r"<style[^>]*>.*?</style>", " ", text, flags=re.DOTALL)
    text = re.sub(r"<[^>]+>", " ", text)
    text = unescape(text)
    text = re.sub(r"\s+", " ", text).strip()

    # Title: usually first H1 or page title
    title_m = re.search(r"^([^|]*?)\s*\|\s*RWS", text, re.IGNORECASE)
    title = title_m.group(1).strip() if title_m else ""
    if not title:
        # try the og:title from HTML
        m = re.search(r'<meta[^>]+property="og:title"[^>]+content="([^"]+)"', html)
        if m:
            title = unescape(m.group(1)).strip()

    # MV
    mv_m = re.search(r"V0\s+(\d+(?:[.,]\d+)?)\s*m/s", text, re.IGNORECASE)
    mv_fps = None
    if mv_m:
        try:
            mv_ms = float(mv_m.group(1).replace(",", "."))
            mv_fps = int(round(mv_ms / 0.3048))
        except ValueError:
            pass
    # BC
    bc_m = re.search(r"BC value\s+(\d+\.\d+)", text, re.IGNORECASE)
    bc_g1 = None
    if bc_m:
        try:
            bc_g1 = float(bc_m.group(1))
        except ValueError:
            pass

    return mv_fps, bc_g1, title


APPLICATION_HINTS = [
    (re.compile(r"speed.?tip|hit|rt|driven", re.I), "hunting"),
    (re.compile(r"target.?elite|target|match|r.?100|r.?50|r-50", re.I), "match"),
    (re.compile(r"hexagon|practice|range|training|trainer", re.I), "target"),
    (re.compile(r"defense|coup|tactical|le", re.I), "defense"),
    (re.compile(r"vmax|varmint|hp", re.I), "varmint"),
]


def application_for(title: str) -> str:
    for pat, app in APPLICATION_HINTS:
        if pat.search(title):
            return app
    return "general"


def line_for(title: str) -> str:
    """Extract the product line (e.g. 'Speed Tip Pro', 'Hit', 'Evo Green').

    Title format: "RWS <caliber> <line/style> <weight>g".
    """
    s = title.strip()
    s = re.sub(r"^RWS\s+", "", s, flags=re.I)
    # Strip trailing weight
    s = re.sub(r"\s+\d+(?:[.,]\d+)?\s*g\s*$", "", s).strip()
    # Strip caliber prefix - leave the rest. Try matching the caliber
    # exactly first; if not, walk past punctuation tokens.
    cal = parse_caliber_from_title(title) or ""
    if cal and s.lower().startswith(cal.lower()):
        s = s[len(cal):].strip()
    # Strip a stray leading dot/period (artefacts of "5,6 x 50 R MAG. HIT" etc.)
    s = s.lstrip(".  ")
    s = s.strip()
    # Title-case fully-uppercase line names ("HIT" -> "HIT" stays, but
    # "SPEED TIP PRO" stays — keep these as-is to match how RWS markets
    # them).
    return s or "RWS"


def make_row(url: str, html: str) -> dict | None:
    mv, bc, title = extract_specs(html)
    if mv is None or bc is None or not title:
        return None
    if not (200 <= mv <= 5000):
        return None
    if not (0.05 <= bc <= 1.5):
        return None
    caliber = parse_caliber_from_title(title)
    if not caliber:
        return None
    weight = parse_weight_from_title(title)
    if weight is None:
        # Try URL slug
        slug_m = re.search(r"-(\d+)-(\d+)g", url)
        if slug_m:
            weight = float(slug_m.group(1)) + float(slug_m.group(2)) / 10.0
            weight = weight * 15.4324
            weight = round(weight, 1)
            if not (5 <= weight <= 1000):
                weight = None
    if weight is None:
        return None
    line = line_for(title)
    application = application_for(title)
    return {
        "manufacturer": "RWS",
        "line": line,
        "caliber": caliber,
        "bulletWeightGr": weight,
        "factoryMvFps": mv,
        "bcG1": round(bc, 3),
        "bcG7": None,
        "bulletLengthIn": None,
        "application": application,
        "notes": title,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", "-o", type=Path, required=True)
    parser.add_argument("--throttle", type=float, default=0.2)
    parser.add_argument("--limit", type=int, default=0)
    args = parser.parse_args(argv)

    sys.stderr.write("Fetching RWS product URLs...\n")
    urls = fetch_product_urls()
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
        except Exception as e:
            failed += 1
            sys.stderr.write(f"[{ui}/{len(urls)}] FAIL {type(e).__name__}: {e}\n")
            continue
        row = make_row(url, html)
        if row is None:
            skipped += 1
            continue
        key = (row["caliber"], row["bulletWeightGr"], row["line"], row["notes"])
        if key in seen_keys:
            skipped += 1
        else:
            seen_keys.add(key)
            rows.append(row)
        if ui % 25 == 0:
            sys.stderr.write(f"[{ui}/{len(urls)}] kept {len(rows)} skip {skipped} fail {failed}\n")
        time.sleep(args.throttle)

    sys.stderr.write(f"Total: {len(rows)} rows kept, {skipped} skipped, {failed} failed\n")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(rows, indent=2) + "\n")
    sys.stderr.write(f"Wrote {args.output}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
