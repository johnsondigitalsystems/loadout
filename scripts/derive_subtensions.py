#!/usr/bin/env python3
# FILE: scripts/derive_subtensions.py
#
# ============================================================================
# WHAT THIS FILE DOES
# ============================================================================
# Authoring-time helper for the LoadOut reticle catalog. Given a reticle
# JSON with an `elements` array, proposes the 7 subtension density fields
# (`centerDotSizeUnits`, `majorHashIntervalUnits`, `minorHashIntervalUnits`,
# `subHashIntervalUnits`, `treeRowSpacingUnits`, `treeRowCount`,
# `treeRowWidthsUnits`, `treeDepthUnits`) by walking the elements
# geometrically.
#
# Usage:
#
#     python3 scripts/derive_subtensions.py path/to/reticle.json
#
# Output: pretty-printed JSON with the proposed subtensions block. The
# human reviews the proposal, edits if needed, and pastes into the
# canonical `assets/seed_data/reticles.json` row. This script is NOT
# part of the app runtime — it's an authoring aid only.
#
# Reference: range_day_realistic_rewrite_v23.md Appendix K (v2.3). The
# full design rationale, edge-case analysis, and worked example live in
# `docs/reticle_subtension_derivation.md` (the longer design doc from
# the same workstream).
#
# ============================================================================
# WHY IT EXISTS IN THE ARCHITECTURE
# ============================================================================
# The visual `elements` array IS the canonical reticle definition.
# Hand-authoring the 7 density fields alongside the elements would
# create two sources of truth for the same data — every visual edit
# would require manually updating the metadata. The derivation here
# computes the metadata once at authoring time so the elements stay
# canonical and the density fields are a deterministic projection.
#
# At runtime, the density fields are read directly from the seeded JSON
# (they ship inline in `assets/seed_data/reticles.json`). This script
# never runs on a user's device.
#
# ============================================================================
# WHY THIS IS HARDER THAN IT LOOKS
# ============================================================================
#   * `majorHashIntervalUnits` vs `minorHashIntervalUnits` requires
#     identifying visual TIERS by `length`, not just by interval mode.
#     A 3-tier reticle (sub / minor / major) has three distinct hash
#     lengths; we cluster them with an epsilon to handle float
#     imprecision in authored values.
#   * The center-dot filter must reject hollow dots (`open=true`) and
#     dots at non-origin positions. A reticle with a single floating
#     dot at (0.2, -1.5) is not a center dot.
#   * `treeRowSpacingUnits` only looks at filled dots at `y > 0` AND
#     `|x| > 0`. A vertical-stadia hash at `(0, 1.0)` is NOT a tree row.
#   * Mode-of-intervals ties are resolved by taking the smallest
#     interval — this matches the shooter convention where the "ruler"
#     scale is the finest regularly-spaced grid.
#
# ============================================================================
# WHO CONSUMES THIS FILE
# ============================================================================
#   - Reticle authors during the authoring pass when adding a new
#     reticle to `reticles.json`. Workflow documented in
#     `docs/RETICLE_AUTHORING_GUIDE.md`.
#   - NOT consumed by the app runtime. Adding `import` of this from
#     `lib/` is a bug.
#
# ============================================================================
# SIDE EFFECTS
# ============================================================================
# Prints to stdout. No file writes, no network, no DB.

# The brief's Appendix K uses Python 3.10+ union syntax (`float | None`).
# `from __future__ import annotations` defers annotation evaluation so
# the same source runs on Python 3.9 (the macOS system default) without
# diverging from the brief's verbatim code.
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from typing import Any

_PRECISION_DECIMALS = 3
_TIER_CLUSTER_EPSILON = 1e-3
_ZERO_ORIGIN_EPSILON = 1e-9


def _round(x: float) -> float:
    return round(x, _PRECISION_DECIMALS)


def _cluster(values: list[float], epsilon: float) -> list[float]:
    if not values:
        return []
    sorted_v = sorted(values)
    clusters: list[list[float]] = [[sorted_v[0]]]
    for v in sorted_v[1:]:
        if v - clusters[-1][-1] < epsilon:
            clusters[-1].append(v)
        else:
            clusters.append([v])
    return [_round(sum(c) / len(c)) for c in clusters]


def _mode_interval(positions: list[float]) -> float | None:
    if len(positions) < 2:
        return None
    clustered = _cluster([abs(p) for p in positions], _TIER_CLUSTER_EPSILON)
    if len(clustered) < 2:
        return None
    clustered.sort()
    gaps = [_round(clustered[i+1] - clustered[i]) for i in range(len(clustered) - 1)]
    c = Counter(gaps)
    max_count = max(c.values())
    candidates = sorted([g for g, n in c.items() if n == max_count])
    return candidates[0]


def derive_center_dot(elements: list[dict[str, Any]]) -> float | None:
    centers = [e for e in elements
               if e.get('type') == 'dot'
               and abs(e.get('x', 0)) < _ZERO_ORIGIN_EPSILON
               and abs(e.get('y', 0)) < _ZERO_ORIGIN_EPSILON
               and not e.get('open', False)]
    if not centers:
        return None
    return _round(2 * min(e.get('radius', 0) for e in centers))


def derive_hash_tiers(elements: list[dict[str, Any]]) -> dict[str, float | None]:
    horiz_hashes = [e for e in elements
                    if e.get('type') == 'hash'
                    and abs(e.get('y', 0)) < _ZERO_ORIGIN_EPSILON
                    and abs(e.get('x', 0)) > _ZERO_ORIGIN_EPSILON]
    if not horiz_hashes:
        return {'major': None, 'minor': None, 'sub': None}
    lengths = _cluster([e.get('length', 0) for e in horiz_hashes], _TIER_CLUSTER_EPSILON)
    lengths.sort(reverse=True)
    by_tier: dict[str, list[float]] = {'major': [], 'minor': [], 'sub': []}
    for e in horiz_hashes:
        L = e.get('length', 0)
        if lengths and abs(L - lengths[0]) < _TIER_CLUSTER_EPSILON:
            by_tier['major'].append(abs(e['x']))
        elif len(lengths) > 1 and abs(L - lengths[1]) < _TIER_CLUSTER_EPSILON:
            by_tier['minor'].append(abs(e['x']))
        elif len(lengths) > 2 and abs(L - lengths[2]) < _TIER_CLUSTER_EPSILON:
            by_tier['sub'].append(abs(e['x']))
    return {
        'major': _mode_interval(by_tier['major']),
        'minor': _mode_interval(by_tier['minor']),
        'sub': _mode_interval(by_tier['sub']),
    }


def derive_tree(elements: list[dict[str, Any]]) -> dict[str, Any]:
    tree_elements = [e for e in elements
                     if e.get('type') == 'dot'
                     and abs(e.get('x', 0)) > _ZERO_ORIGIN_EPSILON
                     and e.get('y', 0) > 0
                     and not e.get('open', False)]
    if not tree_elements:
        return {'row_spacing': None, 'row_count': 0, 'row_widths': [], 'depth': None}
    y_values = _cluster([e['y'] for e in tree_elements], _TIER_CLUSTER_EPSILON)
    y_values.sort()
    spacing = _mode_interval(y_values)
    widths: list[float] = []
    for y in y_values:
        row_dots = [e for e in tree_elements if abs(e['y'] - y) < _TIER_CLUSTER_EPSILON]
        if row_dots:
            widths.append(_round(max(abs(e['x']) for e in row_dots)))
    return {
        'row_spacing': spacing,
        'row_count': len(y_values),
        'row_widths': widths,
        'depth': _round(max(y_values) if y_values else 0),
    }


def derive_subtensions(reticle: dict[str, Any]) -> dict[str, Any]:
    elements = reticle.get('elements', [])
    hashes = derive_hash_tiers(elements)
    tree = derive_tree(elements)
    return {
        'centerDotSizeUnits': derive_center_dot(elements),
        'majorHashIntervalUnits': hashes['major'],
        'minorHashIntervalUnits': hashes['minor'],
        'subHashIntervalUnits': hashes['sub'],
        'treeRowSpacingUnits': tree['row_spacing'],
        'treeRowCount': tree['row_count'],
        'treeRowWidthsUnits': tree['row_widths'],
        'treeDepthUnits': tree['depth'],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description='Propose subtensions for a reticle.')
    parser.add_argument('reticle_json', help='Path to a reticle JSON with elements')
    args = parser.parse_args()
    with open(args.reticle_json) as fp:
        reticle = json.load(fp)
    proposed = derive_subtensions(reticle)
    print(json.dumps(proposed, indent=2))
    return 0


if __name__ == '__main__':
    sys.exit(main())
