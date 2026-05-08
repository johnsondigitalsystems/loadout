#!/usr/bin/env python3
"""Merge per-manufacturer factory_loads files into the master JSON.

Reads:
  assets/seed_data/factory_loads.json   - existing master
  /tmp/<mfg>_factory_loads.json         - per-scraper outputs

Writes back to assets/seed_data/factory_loads.json (or --output).

Dedup rule: a row is considered a duplicate if there's an existing row
with the same (manufacturer, line, caliber, bulletWeightGr,
factoryMvFps, notes-or-bulletStyle) tuple. The master entries are kept
verbatim; new entries are appended.

Usage::

    python3 tool/merge_factory_loads.py \
        --master assets/seed_data/factory_loads.json \
        --inputs /tmp/hornady_factory_loads.json \
                 /tmp/federal_factory_loads.json \
                 /tmp/norma_factory_loads.json \
                 /tmp/berger_factory_loads.json \
                 /tmp/browning_factory_loads.json \
                 /tmp/fiocchi_factory_loads.json \
                 /tmp/sako_factory_loads.json \
                 /tmp/rws_factory_loads.json \
        --output assets/seed_data/factory_loads.json
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def normalize_caliber(c: str) -> str:
    if not c:
        return ""
    s = c.strip()
    # Drop trailing periods and double spaces
    s = " ".join(s.split())
    return s


def make_key(row: dict) -> tuple:
    """Dedup key — close enough to catch obvious duplicates without
    being so strict that variants get collapsed."""
    return (
        (row.get("manufacturer") or "").strip().lower(),
        (row.get("line") or "").strip().lower(),
        normalize_caliber(row.get("caliber") or "").lower(),
        round(float(row.get("bulletWeightGr") or 0), 1),
        int(row.get("factoryMvFps") or 0),
        (row.get("notes") or "").strip().lower(),
    )


def coerce_row(row: dict) -> dict:
    """Apply minor consistency fixes."""
    out = dict(row)
    # Make sure expected keys exist
    for k in ("manufacturer", "line", "caliber", "bulletWeightGr",
              "factoryMvFps", "bcG1", "bcG7", "bulletLengthIn",
              "application", "notes"):
        out.setdefault(k, None)
    # Ensure numeric types
    if out["bulletWeightGr"] is not None:
        try:
            out["bulletWeightGr"] = float(out["bulletWeightGr"])
        except (TypeError, ValueError):
            out["bulletWeightGr"] = None
    if out["factoryMvFps"] is not None:
        try:
            out["factoryMvFps"] = int(round(float(out["factoryMvFps"])))
        except (TypeError, ValueError):
            out["factoryMvFps"] = None
    for k in ("bcG1", "bcG7", "bulletLengthIn"):
        if out[k] is not None:
            try:
                out[k] = float(out[k])
            except (TypeError, ValueError):
                out[k] = None
    return out


def is_usable(row: dict) -> bool:
    """Reject rows that aren't useful for the ballistics calculator.

    - Must have caliber + bullet weight.
    - Must have factoryMvFps in a sensible band (200-5000 fps).
    - Must have at least one BC (G1 or G7).
    """
    if not row.get("manufacturer") or not row.get("caliber"):
        return False
    if row.get("bulletWeightGr") is None:
        return False
    mv = row.get("factoryMvFps")
    if mv is None:
        return False
    try:
        mv_int = int(mv)
    except (TypeError, ValueError):
        return False
    if not (200 <= mv_int <= 5000):
        return False
    bc1 = row.get("bcG1")
    bc7 = row.get("bcG7")
    if bc1 is None and bc7 is None:
        return False
    return True


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--master", type=Path, required=True)
    parser.add_argument("--inputs", type=Path, nargs="+", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)

    sys.stderr.write(f"Reading master {args.master}...\n")
    master = json.loads(args.master.read_text())
    sys.stderr.write(f"  {len(master)} existing rows\n")

    seen_keys: set = set()
    for row in master:
        seen_keys.add(make_key(row))

    out_rows: list[dict] = list(master)
    added = 0
    skipped_dup = 0
    skipped_bad = 0
    by_mfg = {}

    for path in args.inputs:
        if not path.exists():
            sys.stderr.write(f"  SKIP missing {path}\n")
            continue
        try:
            data = json.loads(path.read_text())
        except json.JSONDecodeError as e:
            sys.stderr.write(f"  SKIP bad JSON {path}: {e}\n")
            continue
        if not isinstance(data, list):
            sys.stderr.write(f"  SKIP not a list {path}\n")
            continue
        sys.stderr.write(f"  Reading {path}: {len(data)} rows\n")
        for row in data:
            if not isinstance(row, dict):
                continue
            row = coerce_row(row)
            if not is_usable(row):
                skipped_bad += 1
                continue
            key = make_key(row)
            if key in seen_keys:
                skipped_dup += 1
                continue
            seen_keys.add(key)
            out_rows.append(row)
            added += 1
            mfg = row["manufacturer"]
            by_mfg[mfg] = by_mfg.get(mfg, 0) + 1

    sys.stderr.write(f"\nAdded: {added}\n")
    sys.stderr.write(f"Skipped dup: {skipped_dup}\n")
    sys.stderr.write(f"Skipped bad: {skipped_bad}\n")
    sys.stderr.write(f"Total rows: {len(out_rows)}\n")
    sys.stderr.write("\nBy manufacturer (new rows added):\n")
    for mfg, n in sorted(by_mfg.items(), key=lambda x: -x[1]):
        sys.stderr.write(f"  {mfg:20s} +{n}\n")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(out_rows, indent=2) + "\n")
    sys.stderr.write(f"\nWrote {args.output}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
