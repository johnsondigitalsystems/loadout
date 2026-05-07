#!/usr/bin/env python3
"""
LoadOut placeholder app icon generator.

Generates two PNGs into assets/icon/:
  - icon.png             1024x1024 master (solid background, edge-to-edge)
  - icon_foreground.png  1024x1024 with transparent background, motif at ~60%
                         scale (Android adaptive icon foreground; system fills
                         the background separately)

Design (placeholder):
  Headstamp-inspired motif. Dark gunmetal background, brass-colored outer ring
  and a serif "LO" wordmark in the center. Restrained, no bullets/skulls/etc.

Re-run any time with:
  python3 tool/gen_icon.py
"""

import os
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
except ImportError:
    sys.stderr.write(
        "Pillow (PIL) is required.\n"
        "Install with: pip3 install --user --break-system-packages pillow\n"
    )
    raise

# ---------- Configuration -----------------------------------------------------

CANVAS = 1024  # px
PROJECT_ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = PROJECT_ROOT / "assets" / "icon"

# Committed colors:
#   Background = charcoal gunmetal
#   Foreground = warm brass
BG_COLOR = (31, 41, 55, 255)        # #1F2937
FG_COLOR = (197, 165, 114, 255)     # #C5A572
FG_DIM = (165, 138, 95, 255)        # darker brass for inner stamp ring

# Font candidates, in priority order. PIL falls back if none are found.
FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf",
    "/System/Library/Fonts/Supplemental/Georgia Bold.ttf",
    "/System/Library/Fonts/Supplemental/Times New Roman.ttf",
    "/System/Library/Fonts/Supplemental/Georgia.ttf",
    "/System/Library/Fonts/Times.ttc",
    "/System/Library/Fonts/Georgia.ttf",
    "/Library/Fonts/Times New Roman Bold.ttf",
    "/Library/Fonts/Georgia Bold.ttf",
]

WORDMARK = "LO"


# ---------- Helpers -----------------------------------------------------------

def find_font(size: int) -> tuple[ImageFont.FreeTypeFont | ImageFont.ImageFont, str]:
    """Return (font, path) for the first font candidate that loads."""
    for path in FONT_CANDIDATES:
        if os.path.isfile(path):
            try:
                return ImageFont.truetype(path, size=size), path
            except Exception:
                continue
    # Last-ditch fallback. Looks bad but lets the script complete.
    return ImageFont.load_default(), "<PIL default>"


def draw_motif(img: Image.Image, scale: float = 1.0) -> None:
    """
    Draw the headstamp motif onto img. The motif is sized relative to CANVAS;
    `scale` shrinks it (1.0 = full canvas, 0.6 = 60% for adaptive foreground).

    Motif: outer brass ring + thin inner ring (stamping shoulder) + bold serif
    "LO" wordmark centered.
    """
    cx = cy = CANVAS / 2
    motif_radius = (CANVAS / 2) * 0.86 * scale  # leave a little air at the edge

    draw = ImageDraw.Draw(img)

    # Outer ring stroke width scales with the motif.
    outer_stroke = max(2, int(motif_radius * 0.045))
    inner_stroke = max(1, int(motif_radius * 0.018))

    # Outer ring
    bbox_outer = (
        cx - motif_radius,
        cy - motif_radius,
        cx + motif_radius,
        cy + motif_radius,
    )
    draw.ellipse(bbox_outer, outline=FG_COLOR, width=outer_stroke)

    # Inner concentric ring (the "stamp shoulder")
    inner_radius = motif_radius * 0.78
    bbox_inner = (
        cx - inner_radius,
        cy - inner_radius,
        cx + inner_radius,
        cy + inner_radius,
    )
    draw.ellipse(bbox_inner, outline=FG_DIM, width=inner_stroke)

    # Wordmark
    # We size the font so the rendered text fits comfortably inside the inner
    # ring. Start big and shrink until it fits.
    target_text_height = inner_radius * 1.05  # bold and prominent
    font_size = int(target_text_height)
    while font_size > 10:
        font, font_path = find_font(font_size)
        bbox = draw.textbbox((0, 0), WORDMARK, font=font)
        w = bbox[2] - bbox[0]
        h = bbox[3] - bbox[1]
        # Limit width to ~1.35 * inner radius so it never crowds the ring.
        if w <= inner_radius * 1.45 and h <= inner_radius * 1.10:
            break
        font_size -= 8
    else:
        font, font_path = find_font(60)
        bbox = draw.textbbox((0, 0), WORDMARK, font=font)
        w = bbox[2] - bbox[0]
        h = bbox[3] - bbox[1]

    # Center the text. Account for the bbox offset (PIL textbbox can have a
    # non-zero top/left for many fonts).
    text_x = cx - (w / 2) - bbox[0]
    text_y = cy - (h / 2) - bbox[1]
    draw.text((text_x, text_y), WORDMARK, font=font, fill=FG_COLOR)

    # Stash font path on the image for the caller (best-effort report).
    img.info["__font_path"] = font_path


# ---------- Outputs -----------------------------------------------------------

def render_master() -> Path:
    """1024x1024 PNG, opaque dark background, motif at full scale."""
    img = Image.new("RGBA", (CANVAS, CANVAS), BG_COLOR)
    draw_motif(img, scale=1.0)
    out = OUT_DIR / "icon.png"
    # Flatten to RGB so iOS doesn't see any alpha channel.
    img.convert("RGB").save(out, format="PNG", optimize=True)
    return out


def render_adaptive_foreground() -> Path:
    """1024x1024 PNG, transparent background, motif at 60% scale (safe zone)."""
    img = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw_motif(img, scale=0.60)
    out = OUT_DIR / "icon_foreground.png"
    img.save(out, format="PNG", optimize=True)
    return out


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    master = render_master()
    fg = render_adaptive_foreground()

    # Tiny report to stdout.
    sample_font, font_path = find_font(200)
    print(f"Wrote {master} ({master.stat().st_size} bytes)")
    print(f"Wrote {fg}     ({fg.stat().st_size} bytes)")
    print(f"Background color: #{BG_COLOR[0]:02X}{BG_COLOR[1]:02X}{BG_COLOR[2]:02X}")
    print(f"Foreground color: #{FG_COLOR[0]:02X}{FG_COLOR[1]:02X}{FG_COLOR[2]:02X}")
    print(f"Font: {font_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
