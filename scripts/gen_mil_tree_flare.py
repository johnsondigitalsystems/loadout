#!/usr/bin/env python3
"""Generates the elements array for loadout_mil_tree_flare.
Output: JSON array pastable into the reticle entry.

Source: range_day_realistic_rewrite_v23.md Appendix A.
"""
import json

elements = []

# Center crosshair (gap from -0.06 to +0.06)
elements.append({"type": "line", "x1": -5.0, "y1": 0, "x2": -0.06, "y2": 0, "thickness": 1.0})
elements.append({"type": "line", "x1": 0.06, "y1": 0, "x2": 5.0, "y2": 0, "thickness": 1.0})
elements.append({"type": "line", "x1": 0, "y1": -5.0, "x2": 0, "y2": -0.06, "thickness": 1.0})
elements.append({"type": "line", "x1": 0, "y1": 0.06, "x2": 0, "y2": 10.0, "thickness": 1.0})

# Floating center dot (diameter 0.06 mil)
elements.append({"type": "dot", "x": 0, "y": 0, "radius": 0.03, "open": False})

# Major hashes on horizontal stadia (every 1 mil out to +/-5)
for i in range(1, 6):
    elements.append({"type": "hash", "x":  i, "y": 0, "length": 0.4, "thickness": 1.5})
    elements.append({"type": "hash", "x": -i, "y": 0, "length": 0.4, "thickness": 1.5})

# Minor hashes on horizontal stadia (every 0.5 mil, not at major)
for half in [0.5, 1.5, 2.5, 3.5, 4.5]:
    elements.append({"type": "hash", "x":  half, "y": 0, "length": 0.2, "thickness": 1.0})
    elements.append({"type": "hash", "x": -half, "y": 0, "length": 0.2, "thickness": 1.0})

# Sub-hashes (every 0.2 mil within +/-2 mil), excluding 0.5/1.0/1.5/2.0
for x in [0.2, 0.4, 0.6, 0.8, 1.2, 1.4, 1.6, 1.8]:
    elements.append({"type": "hash", "x":  x, "y": 0, "length": 0.1, "thickness": 0.7})
    elements.append({"type": "hash", "x": -x, "y": 0, "length": 0.1, "thickness": 0.7})

# Numbered labels at major hash positions on horizontal stadia
for i in [1, 2, 3, 4, 5]:
    elements.append({"type": "number", "x":  i, "y": 0.7, "text": str(i), "fontSize": 0.4})
    elements.append({"type": "number", "x": -i, "y": 0.7, "text": str(i), "fontSize": 0.4})

# Major hashes on vertical stadia ABOVE center
for i in range(1, 6):
    elements.append({"type": "hash", "x": 0, "y": -i, "length": 0.4, "thickness": 1.5})

# Minor hashes ABOVE center
for half in [0.5, 1.5, 2.5, 3.5, 4.5]:
    elements.append({"type": "hash", "x": 0, "y": -half, "length": 0.2, "thickness": 1.0})

# Numbered labels above center
for i in [1, 2, 3, 4, 5]:
    elements.append({"type": "number", "x": 0.7, "y": -i, "text": str(i), "fontSize": 0.4})

# Christmas tree: rows 1..10, flaring widths
tree_widths = {1: 0.5, 2: 1.0, 3: 1.5, 4: 2.0, 5: 2.5,
               6: 3.0, 7: 3.5, 8: 4.0, 9: 4.0, 10: 4.0}
for y in range(1, 11):
    max_w = tree_widths[y]
    for x in [n * 0.5 for n in range(1, int(max_w * 2) + 1)]:
        elements.append({"type": "dot", "x":  x, "y": y, "radius": 0.04, "open": False})
        elements.append({"type": "dot", "x": -x, "y": y, "radius": 0.04, "open": False})
    elements.append({"type": "hash", "x": 0, "y": y, "length": 0.4, "thickness": 1.5})

# Numbered drops at major tree rows (every 2 mil down)
for y in [2, 4, 6, 8, 10]:
    elements.append({"type": "number", "x": -0.7, "y": y, "text": str(y), "fontSize": 0.4})

print(json.dumps(elements, indent=2))
