#!/usr/bin/env python3
"""Generates the elements array for loadout_moa_tree_flare.

Source: range_day_realistic_rewrite_v23.md Appendix B.
"""
import json

elements = []

# Center crosshair (gap from -0.25 to +0.25 MOA)
elements.append({"type": "line", "x1": -20.0, "y1": 0, "x2": -0.25, "y2": 0, "thickness": 1.0})
elements.append({"type": "line", "x1": 0.25, "y1": 0, "x2": 20.0, "y2": 0, "thickness": 1.0})
elements.append({"type": "line", "x1": 0, "y1": -20.0, "x2": 0, "y2": -0.25, "thickness": 1.0})
elements.append({"type": "line", "x1": 0, "y1": 0.25, "x2": 0, "y2": 40.0, "thickness": 1.0})

# Center dot (0.25 MOA diameter)
elements.append({"type": "dot", "x": 0, "y": 0, "radius": 0.125, "open": False})

# Major hashes (every 5 MOA out to +/-20)
for i in [5, 10, 15, 20]:
    elements.append({"type": "hash", "x":  i, "y": 0, "length": 2.0, "thickness": 1.5})
    elements.append({"type": "hash", "x": -i, "y": 0, "length": 2.0, "thickness": 1.5})
    elements.append({"type": "hash", "x": 0, "y": -i, "length": 2.0, "thickness": 1.5})

# Minor hashes (every 2 MOA, excluding majors)
for x in [2, 4, 6, 8, 12, 14, 16, 18]:
    elements.append({"type": "hash", "x":  x, "y": 0, "length": 1.0, "thickness": 1.0})
    elements.append({"type": "hash", "x": -x, "y": 0, "length": 1.0, "thickness": 1.0})
    elements.append({"type": "hash", "x": 0, "y": -x, "length": 1.0, "thickness": 1.0})

# Sub-hashes (every 1 MOA within +/-10), not at minor/major
for x in [1, 3, 7, 9, 11, 13]:
    elements.append({"type": "hash", "x":  x, "y": 0, "length": 0.5, "thickness": 0.7})
    elements.append({"type": "hash", "x": -x, "y": 0, "length": 0.5, "thickness": 0.7})
    elements.append({"type": "hash", "x": 0, "y": -x, "length": 0.5, "thickness": 0.7})

# Numbered labels at major positions
for i in [5, 10, 15, 20]:
    elements.append({"type": "number", "x":  i, "y": 3.5, "text": str(i), "fontSize": 2.0})
    elements.append({"type": "number", "x": -i, "y": 3.5, "text": str(i), "fontSize": 2.0})
    elements.append({"type": "number", "x": 3.5, "y": -i, "text": str(i), "fontSize": 2.0})

# Christmas tree: rows at 5/10/15/.../40 MOA, flaring widths
tree_widths = {5: 2, 10: 4, 15: 6, 20: 8, 25: 10, 30: 12, 35: 14, 40: 16}
for y_row, max_w in tree_widths.items():
    elements.append({"type": "hash", "x": 0, "y": y_row, "length": 2.0, "thickness": 1.5})
    pos = 2
    while pos <= max_w:
        elements.append({"type": "dot", "x":  pos, "y": y_row, "radius": 0.2, "open": False})
        elements.append({"type": "dot", "x": -pos, "y": y_row, "radius": 0.2, "open": False})
        pos += 2

# Numbered drops at major tree rows
for y_row in [10, 20, 30, 40]:
    elements.append({"type": "number", "x": -3.5, "y": y_row, "text": str(y_row), "fontSize": 2.0})

print(json.dumps(elements, indent=2))
