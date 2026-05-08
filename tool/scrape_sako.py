#!/usr/bin/env python3
"""Scrape Sako factory ammunition specs from product line pages.

Sako's site at https://www.sako.global lists ammunition lines under
``/ammunition/<line>`` (gamehead, gamehead-pro, super-hammerhead, etc.).
Each line page lists every variant in a tabular form like:

    "Muzzle velocity 835 m/s Ballistic coefficient 0.471 Caliber
     7,62 x 39 Bullet weight 8 g / 123 gr"

We extract:
* Muzzle velocity (m/s -> fps)
* Ballistic coefficient (G1)
* Caliber
* Bullet weight (g + gr; we use the gr value)

Sako lines are mostly hunting cartridges; the few "TRG" lines target
match shooting.

Output schema mirrors ``factory_loads.json``.

Usage::

    python3 tool/scrape_sako.py --output /tmp/sako_factory_loads.json
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

ORIGIN = "https://www.sako.global"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0)",
    "Accept": "text/html,application/xhtml+xml",
}

LINE_TO_APPLICATION = {
    "gamehead": ("Gamehead", "hunting"),
    "gamehead-pro": ("Gamehead Pro", "hunting"),
    "gamehead-varmint": ("Gamehead Varmint", "varmint"),
    "gamehead-varmint-rx": ("Gamehead Varmint RX", "varmint"),
    "hammerhead": ("Hammerhead", "hunting"),
    "super-hammerhead": ("Super Hammerhead", "hunting"),
    "powerhead-blade": ("Powerhead Blade", "hunting"),
    "powerhead-blade-pro": ("Powerhead Blade Pro", "hunting"),
    "speedhead": ("Speedhead", "match"),
    "indoor": ("Indoor", "target"),
    "trg-defense": ("TRG Defense", "defense"),
    "trg-precision": ("TRG Precision", "match"),
}


def _http_get(url: str, *, timeout: float = 15.0, retries: int = 2) -> str:
    """HTTP GET via curl subprocess.

    Python's urllib hangs unpredictably on Sako's TLS handshake / cookie
    flow; curl works reliably. Shelling out also gives us a hard
    process-level timeout instead of urllib's soft-deadline behaviour.
    """
    import subprocess
    last_err = ""
    for _ in range(retries + 1):
        try:
            r = subprocess.run(
                [
                    "curl",
                    "-s",
                    "-A",
                    HEADERS["User-Agent"],
                    "-m",
                    str(int(timeout)),
                    "-L",
                    url,
                ],
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


def fetch_line_urls() -> list[str]:
    xml = _http_get(f"{ORIGIN}/sitemap.xml")
    locs = re.findall(r"<loc>([^<]+)</loc>", xml)
    out = []
    for u in locs:
        path = u.replace(ORIGIN, "").strip("/")
        parts = path.split("/")
        if len(parts) == 2 and parts[0] == "ammunition":
            slug = parts[1]
            if slug in LINE_TO_APPLICATION:
                out.append(u)
    return sorted(set(out))


def parse_line_page(url: str, html: str) -> list[dict]:
    rows: list[dict] = []
    text = re.sub(r"<[^>]+>", " ", html)
    text = unescape(text)
    text = re.sub(r"\s+", " ", text).strip()

    slug = url.rstrip("/").split("/")[-1]
    line_name, application = LINE_TO_APPLICATION.get(slug, (slug, "general"))

    # Pattern observed:
    #   "Caliber 6,5 Creedmoor Bullet weight 9.1 g / 140 gr Muzzle
    #    velocity 835 m/s Ballistic coefficient 0.471"
    block_re = re.compile(
        r"Caliber\s+(?P<cal>.+?)\s+"
        r"Bullet weight\s+(?P<gw>\d+(?:[.,]\d+)?)\s*g\s*/\s*"
        r"(?P<gr>\d+(?:\.\d+)?)\s*gr\s+"
        r"Muzzle velocity\s+(?P<mv>\d+(?:[.,]\d+)?)\s*m/s\s+"
        r"Ballistic coefficient\s+(?P<bc>\d+\.\d+)",
        re.IGNORECASE,
    )

    for m in block_re.finditer(text):
        try:
            grams = float(m.group("gw").replace(",", "."))
            grains = float(m.group("gr"))
            mv_ms = float(m.group("mv").replace(",", "."))
            bc = float(m.group("bc"))
        except (TypeError, ValueError):
            continue
        if not (5 <= grains <= 1000):
            continue
        if not (0.05 <= bc <= 1.5):
            continue
        # Convert m/s -> fps.
        mv_fps = int(round(mv_ms / 0.3048))
        if not (200 <= mv_fps <= 5000):
            continue
        cal = m.group("cal").strip()
        cal = re.sub(r"\s+(?:Bullet|Muzzle|Ballistic).*$", "", cal)
        cal = cal.replace(",", ".")  # Sako uses comma decimal: "6,5 Creedmoor"
        if not cal:
            continue
        rows.append({
            "manufacturer": "Sako",
            "line": line_name,
            "caliber": cal,
            "bulletWeightGr": grains,
            "factoryMvFps": mv_fps,
            "bcG1": round(bc, 3),
            "bcG7": None,
            "bulletLengthIn": None,
            "application": application,
            "notes": f"{line_name} {grains:g}gr",
        })
    return rows


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", "-o", type=Path, required=True)
    parser.add_argument("--throttle", type=float, default=0.2)
    args = parser.parse_args(argv)

    sys.stderr.write("Fetching Sako sitemap...\n")
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
            key = (row["caliber"], row["bulletWeightGr"], row["line"], row["factoryMvFps"])
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
