#!/usr/bin/env python3
"""Scrape Federal Premium factory ammunition ballistics from the live site.

Federal's ballistics calculator at
``https://www.federalpremium.com/ballistics-calculator`` is a Salesforce
Commerce Cloud (Demandware) page that drives a cascading
caliber → bulletStyle → bulletWeight → loadDetails dropdown via three
JSON endpoints under
``https://www.federalpremium.com/on/demandware.store/Sites-VistaFederal-Site/default/``:

* ``BallisticCalculator-BulletStyles`` — POST {caliber} → list of
  bullet families (ELD-X, Berger Hybrid, Fusion, etc.).
* ``BallisticCalculator-BulletWeights`` — POST {caliber, bulletStyle} →
  list of bullet weights and SKU productIds.
* ``BallisticCalculator-LoadDetails`` — POST {caliber, bulletStyle,
  bulletWeight} → ``mv`` (muzzle velocity, fps), ``bc`` (G1 BC),
  ``loadNumber``, ``loadProductNames``.

The full caliber list lives in the page HTML as a static ``<select>``.
We extract that, then walk every (caliber, style, weight) combination
and emit one factory_loads.json row per SKU productId returned.

Output schema (matches the existing ``factory_loads.json`` shape):

    {
      "manufacturer": "Federal",
      "line": "<bulletStyle>",
      "caliber": "<caliber>",
      "bulletWeightGr": <float>,
      "factoryMvFps": <int>,
      "bcG1": <float>,
      "bcG7": null,
      "bulletLengthIn": null,
      "application": "<inferred from bulletStyle>",
      "notes": "<bulletStyle> — <productId>"
    }

Federal publishes G1 BC only (no G7), so ``bcG7`` is always null in
the output. The ``application`` is heuristically inferred from the
bullet style ("Berger Hybrid" → match, "Fusion" → hunting, etc.).

Re-running is idempotent — Federal's data rarely shifts and the API
returns the same rows in the same order. Polite throttling: 0.2s
between requests (Federal's CDN tolerates this fine).

Usage::

    python3 tool/scrape_federal.py \\
        --output /tmp/federal_factory_loads.json
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from html import unescape
from pathlib import Path

ORIGIN = "https://www.federalpremium.com"
ENDPOINT_BULLET_STYLES = (
    f"{ORIGIN}/on/demandware.store/Sites-VistaFederal-Site/default/"
    f"BallisticCalculator-BulletStyles"
)
ENDPOINT_BULLET_WEIGHTS = (
    f"{ORIGIN}/on/demandware.store/Sites-VistaFederal-Site/default/"
    f"BallisticCalculator-BulletWeights"
)
ENDPOINT_LOAD_DETAILS = (
    f"{ORIGIN}/on/demandware.store/Sites-VistaFederal-Site/default/"
    f"BallisticCalculator-LoadDetails"
)
HEADERS = {
    "User-Agent": "LoadOut-FactoryLoadsScraper/1.0",
    "Accept": "application/json, text/plain, */*",
    "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
}

# Heuristic: map bullet styles to applications used in factory_loads.json.
# Existing rows use {match, hunting, target, defense, rimfire, varmint}.
APPLICATION_MAP = [
    (re.compile(r"matchking|berger|hybrid|otm|gold ?medal|target|hpbt", re.I), "match"),
    (re.compile(r"hst|defense|defender|center.?strike|tactical", re.I), "defense"),
    (re.compile(r"v.?max|varmint|tnt|hot[- ]?cor|sx|hollow ?point", re.I), "varmint"),
    (re.compile(r"eld.?x|trophy|fusion|terminal|nosler|partition|scirocco|ballistic.tip|copper|sst|interlock|btsp|tipped|interbond", re.I), "hunting"),
    (re.compile(r"fmj|ball|train|practice|bulk|range|round.?nose|jacketed.?soft", re.I), "target"),
]


def _http_post_form(url: str, payload: dict[str, str], *, timeout: float = 15.0) -> dict:
    body = urllib.parse.urlencode(payload).encode()
    req = urllib.request.Request(url, data=body, headers=HEADERS, method="POST")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read())


def _http_get(url: str, *, timeout: float = 15.0) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": HEADERS["User-Agent"]})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8", errors="replace")


def fetch_calibers() -> list[str]:
    """Pull the static caliber dropdown from the calculator page."""
    html = _http_get(f"{ORIGIN}/ballistics-calculator")
    section = re.search(
        r'<select[^>]*id="factoryCaliber"[^>]*>(.*?)</select>',
        html,
        re.DOTALL,
    )
    if not section:
        raise RuntimeError("Could not find factoryCaliber select on calculator page.")
    options = re.findall(
        r'<option[^>]*value="([^"]*)"[^>]*>([^<]*)</option>',
        section.group(1),
    )
    out = []
    for v, _t in options:
        v = unescape(v).strip()
        if v:
            out.append(v)
    return out


def fetch_bullet_styles(caliber: str) -> list[str]:
    try:
        d = _http_post_form(ENDPOINT_BULLET_STYLES, {"caliber": caliber})
    except urllib.error.HTTPError as e:
        sys.stderr.write(f"  HTTP {e.code} on bulletStyles for {caliber!r}\n")
        return []
    return d.get("bulletStyles", []) or []


def fetch_bullet_weights(caliber: str, style: str) -> list[dict]:
    try:
        d = _http_post_form(
            ENDPOINT_BULLET_WEIGHTS,
            {"caliber": caliber, "bulletStyle": style},
        )
    except urllib.error.HTTPError as e:
        sys.stderr.write(
            f"  HTTP {e.code} on bulletWeights for {caliber!r} {style!r}\n"
        )
        return []
    return d.get("bulletWeights", []) or []


def fetch_load_details(caliber: str, style: str, weight: str) -> dict:
    try:
        d = _http_post_form(
            ENDPOINT_LOAD_DETAILS,
            {"caliber": caliber, "bulletStyle": style, "bulletWeight": str(weight)},
        )
    except urllib.error.HTTPError as e:
        sys.stderr.write(
            f"  HTTP {e.code} on loadDetails for {caliber!r} {style!r} {weight!r}\n"
        )
        return {}
    return d.get("loadDetails", {}) or {}


def application_for(style: str) -> str:
    for pat, app in APPLICATION_MAP:
        if pat.search(style):
            return app
    return "general"


def parse_weight(weight_raw: str | int | float) -> float | None:
    """Parse the bulletWeight value Federal returns.

    Federal usually returns a plain integer string ("140", "180").
    Slugs (12 GA shotshells) come back as "1 1/4 oz" or "1.125 oz HE";
    we skip these (no bullet weight in grains for shot loads).
    """
    if weight_raw is None:
        return None
    s = str(weight_raw).strip()
    # "143", "150", "180.5"
    m = re.match(r"^([0-9]+(?:\.[0-9]+)?)$", s)
    if m:
        return float(m.group(1))
    return None


def parse_bc(bc_raw: str | int | float | None) -> float | None:
    if bc_raw is None:
        return None
    s = str(bc_raw).strip()
    if not s:
        return None
    try:
        v = float(s)
    except ValueError:
        return None
    if 0.0 < v < 1.5:
        return v
    return None


def parse_mv(mv_raw: str | int | float | None) -> int | None:
    if mv_raw is None:
        return None
    try:
        v = int(round(float(str(mv_raw))))
    except ValueError:
        return None
    if 200 <= v <= 5000:
        return v
    return None


def normalize_caliber(c: str) -> str:
    """Match the casing/punctuation conventions used in factory_loads.json.

    Federal's API uses ``"308 Win"``; the existing file uses
    ``".308 Winchester"`` for some loads but ``"308 Win"`` is also
    common. We leave the value as Federal returns it — the downstream
    cartridge picker matches loosely so both forms resolve.
    """
    return c.replace("&amp;", "&").strip()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", "-o", type=Path, required=True)
    parser.add_argument("--throttle", type=float, default=0.2)
    parser.add_argument("--limit-calibers", type=int, default=0,
                        help="Stop after N calibers (debugging)")
    args = parser.parse_args(argv)

    sys.stderr.write("Fetching Federal calibers list...\n")
    calibers = fetch_calibers()
    sys.stderr.write(f"  got {len(calibers)} calibers\n")
    if args.limit_calibers:
        calibers = calibers[: args.limit_calibers]

    rows: list[dict] = []
    seen_keys: set[tuple] = set()

    for ci, cal in enumerate(calibers, start=1):
        sys.stderr.write(f"[{ci}/{len(calibers)}] {cal}\n")
        styles = fetch_bullet_styles(cal)
        time.sleep(args.throttle)
        for style in styles:
            weights = fetch_bullet_weights(cal, style)
            time.sleep(args.throttle)
            for w in weights:
                weight_raw = w.get("bulletWeight")
                bw = parse_weight(weight_raw)
                if bw is None:
                    continue
                ld = fetch_load_details(cal, style, weight_raw)
                time.sleep(args.throttle)
                if not ld:
                    continue
                # Each LoadDetails response represents a unique (caliber,
                # style, weight) bucket. Federal sometimes returns multiple
                # productIds and product names for a single bucket
                # (different MV variants). Try to expand into one row per
                # product when available, otherwise emit a single row.
                product_ids = ld.get("loadNumber") or []
                product_names = ld.get("loadProductNames") or []
                muzzle_velocitys = ld.get("muzzleVelocitys") or []
                # Coerce to lists.
                if isinstance(product_ids, str):
                    product_ids = [product_ids]
                if isinstance(product_names, str):
                    product_names = [product_names]
                if isinstance(muzzle_velocitys, list):
                    mv_list = muzzle_velocitys
                else:
                    mv_list = [muzzle_velocitys]
                # Default-MV path
                default_mv = parse_mv(ld.get("mv"))
                bc = parse_bc(ld.get("bc"))
                if bc is None or default_mv is None:
                    continue
                # If multiple muzzle velocities, generate one row per MV.
                # If only one, just emit a single row.
                mvs_int: list[int] = []
                for m in mv_list:
                    mvi = parse_mv(m)
                    if mvi is not None and mvi not in mvs_int:
                        mvs_int.append(mvi)
                if not mvs_int:
                    mvs_int = [default_mv]
                # Build one row per MV per productId. Many entries have
                # only one MV per productId so this collapses to a single
                # row in practice.
                if not product_ids:
                    product_ids = [""]
                if not product_names:
                    product_names = [""]
                # Use the first productId / name for the notes; we don't
                # fan out by product id since the API returns the same
                # MV/BC for all of them in a bucket.
                pid = product_ids[0] if product_ids else ""
                pname = product_names[0] if product_names else ""
                for mv in mvs_int:
                    key = (cal, style, bw, mv)
                    if key in seen_keys:
                        continue
                    seen_keys.add(key)
                    notes_bits = [style]
                    if pid:
                        notes_bits.append(pid)
                    rows.append({
                        "manufacturer": "Federal",
                        "line": style,
                        "caliber": normalize_caliber(cal),
                        "bulletWeightGr": bw,
                        "factoryMvFps": mv,
                        "bcG1": bc,
                        "bcG7": None,
                        "bulletLengthIn": None,
                        "application": application_for(style),
                        "notes": " — ".join(notes_bits),
                    })

    sys.stderr.write(f"Total rows: {len(rows)}\n")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(rows, indent=2) + "\n")
    sys.stderr.write(f"Wrote {args.output}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
