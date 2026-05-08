#!/usr/bin/env python3
"""Scrape Lapua factory ammunition specs from product detail pages.

Lapua's site at https://www.lapua.com lists factory-loaded centerfire
and rimfire cartridges under ``/product/<slug>``. Each product page
embeds WooCommerce-style attribute rows:

    <tr class="...attribute_pa_muzzle-velocity">
      <th>Muzzle velocity</th>
      <td>880 m/s (2887 fps)</td>
    </tr>
    <tr class="...attribute_pa_bc-g1"><th>BC G1</th><td>0.255</td></tr>
    <tr class="...attribute_pa_bc-g7"><th>BC G7</th><td>...</td></tr>

Plus the title and breadcrumbs to identify the product line.

URL discovery: walk the category pages (cartridges-for-rifle-and-pistol,
hunting-ammunition, sport-shooting-ammunition, factory-loaded-cartridge,
shop, rimfire-ammunition).

Output schema mirrors ``factory_loads.json``.

Usage::

    python3 tool/scrape_lapua.py --output /tmp/lapua_factory_loads.json
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

ORIGIN = "https://www.lapua.com"
HEADERS = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0)"}

LINE_PAGES = [
    "/products/cartridges-for-rifle-and-pistol/",
    "/products/rimfire-ammunition/",
    "/shop/",
    "/product-category/product-type/factory-loaded-cartridge/",
    "/product-category/product-type/hunting-ammunition/",
    "/product-category/product-type/sport-shooting-ammunition/",
]


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
    seen: set[str] = set()
    out: list[str] = []
    for path in LINE_PAGES:
        try:
            html = _http_get(ORIGIN + path)
        except Exception as e:
            sys.stderr.write(f"  page FAIL {path}: {e}\n")
            continue
        hrefs = re.findall(r'href="(https://www\.lapua\.com/product/[^"]+)"', html)
        for h in hrefs:
            if h not in seen:
                seen.add(h)
                out.append(h)
        time.sleep(0.2)
    return out


_ATTR_RE = re.compile(
    r'<tr[^>]*woocommerce-product-attributes-item--attribute_(?P<key>[a-z0-9_-]+)[^>]*>'
    r'.*?<th[^>]*>(?P<label>[^<]+)</th>.*?<td[^>]*>(?P<value>.*?)</td>',
    re.DOTALL,
)


def parse_attrs(html: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for m in _ATTR_RE.finditer(html):
        key = m.group("key")
        val = re.sub(r"<[^>]+>", " ", m.group("value"))
        val = unescape(val)
        val = re.sub(r"\s+", " ", val).strip()
        if val and val != "–" and val != "-":
            out[key] = val
    return out


def parse_title(html: str) -> str:
    m = re.search(r"<title>([^<]+)</title>", html)
    if not m:
        return ""
    t = unescape(m.group(1))
    # Title format: ".222 Rem. / 3.6 g (55 gr) FMJ - Lapua"
    t = re.sub(r"\s*-\s*Lapua\s*$", "", t).strip()
    return t


def parse_caliber(title: str, url: str = "") -> str | None:
    """Lapua titles can take two forms:
    1) Centerfire: ".222 Rem. / 3.6 g (55 gr) FMJ" - caliber before " / "
    2) Rimfire:    ".22 LR ammo | Rimfire Cartridges | Lapua <Line>"
                   — caliber is the first token before " ammo".
    """
    if not title:
        return None
    s = title
    # Form 2 (rimfire): pattern is ".22 LR ammo | ..."
    if "|" in s:
        first = s.split("|")[0].strip()
        first = re.sub(r"\s+ammo\s*$", "", first, flags=re.I).strip()
        return _normalize_lapua_caliber(first)
    # Form 1 (centerfire): take first token before " / " or " -"
    m = re.match(r"([^/\-]+)", s)
    if not m:
        return None
    cal = m.group(1).strip()
    return _normalize_lapua_caliber(cal)


_LAPUA_CALIBER_MAP = {
    ".22 lr": ".22 Long Rifle",
    "22 lr": ".22 Long Rifle",
    ".308 win": ".308 Winchester",
    ".300 win mag": ".300 Winchester Magnum",
    ".300 win. mag": ".300 Winchester Magnum",
    "338 lapua mag": ".338 Lapua Magnum",
    ".338 lapua mag": ".338 Lapua Magnum",
    "300 norma mag": ".300 Norma Magnum",
    ".300 norma mag": ".300 Norma Magnum",
    "30-06 spr": ".30-06 Springfield",
    "30-06 sprg": ".30-06 Springfield",
    ".30-06 spr": ".30-06 Springfield",
    ".30-06 sprg": ".30-06 Springfield",
    "243 win": ".243 Winchester",
    ".243 win": ".243 Winchester",
    "270 win": ".270 Winchester",
    ".270 win": ".270 Winchester",
    "6.5 creedmoor": "6.5 Creedmoor",
    "6.5x55 se": "6.5x55 SE",
    "6.5x55": "6.5x55",
    "7-08 rem": "7mm-08 Remington",
    "7mm-08 rem": "7mm-08 Remington",
    "7mm-08 rem.": "7mm-08 Remington",
    ".223 rem": ".223 Remington",
    "223 rem": ".223 Remington",
    ".222 rem": ".222 Remington",
    "222 rem": ".222 Remington",
    ".22-250 rem": ".22-250 Remington",
    "22-250 rem": ".22-250 Remington",
    ".32 s&w long": ".32 S&W Long",
    "32 s&w long": ".32 S&W Long",
    "32 sw long": ".32 S&W Long",
    "32 sw lwc": ".32 S&W Long",
}


def _normalize_lapua_caliber(c: str) -> str:
    s = c.strip()
    # Drop trailing "."
    s = s.rstrip(".")
    # Comma-decimal -> dot-decimal
    s = s.replace(",", ".")
    # Drop trailing weight tokens that snuck into the regex match
    s = re.sub(r"\s+\d+(?:\.\d+)?\s*g(?:r)?\s*$", "", s).strip()
    return _LAPUA_CALIBER_MAP.get(s.lower(), s)


def parse_weight_grains(title: str, attrs: dict) -> float | None:
    # Title pattern includes "(55 gr)"
    m = re.search(r"\((\d+(?:\.\d+)?)\s*gr\)", title)
    if m:
        return float(m.group(1))
    if "pa_bullet-weight" in attrs:
        v = attrs["pa_bullet-weight"]
        m = re.search(r"(\d+(?:\.\d+)?)\s*(?:gr|grain)", v, re.I)
        if m:
            return float(m.group(1))
    return None


def parse_mv_fps(attrs: dict) -> int | None:
    if "pa_muzzle-velocity" not in attrs:
        return None
    v = attrs["pa_muzzle-velocity"]
    # "880 m/s (2887 fps)"
    m = re.search(r"\((\d+)\s*fps\)", v)
    if m:
        return int(m.group(1))
    m = re.search(r"(\d+)\s*m/s", v)
    if m:
        return int(round(int(m.group(1)) / 0.3048))
    return None


def parse_bc(attrs: dict, key: str) -> float | None:
    if key not in attrs:
        return None
    v = attrs[key]
    if v in {"–", "-", "N/A"}:
        return None
    m = re.search(r"(\d+\.\d+)", v)
    if m:
        try:
            f = float(m.group(1))
            if 0.05 <= f <= 1.5:
                return round(f, 3)
        except ValueError:
            pass
    return None


def line_for_url(url: str, title: str) -> tuple[str, str]:
    """Lapua product lines: Scenar, Scenar-L, Naturalis, Mega, Lock Base,
    FMJ, Polar Biathlon, Center-X, Midas+, X-Act, Pistol King, Pistol OSP,
    Long Range, Super Long Range, GB Match, etc.
    """
    s = url.lower()
    if "naturalis" in s:
        return "Naturalis", "hunting"
    if "mega" in s:
        return "Mega", "hunting"
    if "lock-base" in s:
        return "Lock Base", "hunting"
    if "scenar-l" in s:
        return "Scenar-L", "match"
    if "scenar" in s:
        return "Scenar", "match"
    if "fmj" in s:
        return "FMJ", "target"
    if "polar-biathlon" in s:
        return "Polar Biathlon", "match"
    if "center-x" in s:
        return "Center-X", "match"
    if "midas-plus" in s:
        return "Midas+", "match"
    if "x-act" in s:
        return "X-Act", "match"
    if "pistol-king" in s:
        return "Pistol King", "match"
    if "pistol-osp" in s:
        return "Pistol OSP", "match"
    if "long-range" in s:
        return "Long Range", "match"
    if "super-long-range" in s:
        return "Super Long Range", "match"
    if "gb-match" in s:
        return "GB Match", "match"
    if "trx" in s:
        return "TRX", "hunting"
    if "wadcutter" in s:
        return "Wadcutter", "match"
    return "Lapua", "general"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", "-o", type=Path, required=True)
    parser.add_argument("--throttle", type=float, default=0.2)
    args = parser.parse_args(argv)

    sys.stderr.write("Fetching Lapua product URLs...\n")
    urls = fetch_product_urls()
    sys.stderr.write(f"  {len(urls)} unique product URLs\n")

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
        title = parse_title(html)
        attrs = parse_attrs(html)
        caliber = parse_caliber(title)
        weight = parse_weight_grains(title, attrs)
        mv = parse_mv_fps(attrs)
        bc1 = parse_bc(attrs, "pa_bc-g1")
        bc7 = parse_bc(attrs, "pa_bc-g7")
        if caliber is None or weight is None or mv is None:
            skipped += 1
            continue
        if bc1 is None and bc7 is None:
            skipped += 1
            continue
        line, application = line_for_url(url, title)
        key = (caliber, weight, line, title)
        if key in seen_keys:
            skipped += 1
        else:
            seen_keys.add(key)
            rows.append({
                "manufacturer": "Lapua",
                "line": line,
                "caliber": caliber,
                "bulletWeightGr": weight,
                "factoryMvFps": mv,
                "bcG1": bc1,
                "bcG7": bc7,
                "bulletLengthIn": None,
                "application": application,
                "notes": title,
            })
        time.sleep(args.throttle)

    sys.stderr.write(f"Total: {len(rows)} rows kept, {skipped} skipped, {failed} failed\n")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(rows, indent=2) + "\n")
    sys.stderr.write(f"Wrote {args.output}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
