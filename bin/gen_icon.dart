// LoadOut placeholder app icon generator (Dart edition).
//
// Generates two PNGs into assets/icon/:
//   - icon.png             1024x1024 master (solid background, edge-to-edge)
//   - icon_foreground.png  1024x1024 with transparent background, motif at
//                          ~60% scale (Android adaptive icon foreground;
//                          system fills the background separately)
//
// Design (placeholder):
//   Headstamp-inspired motif. Dark gunmetal background, brass-colored outer
//   ring + thinner inner stamp ring + bold geometric "LO" wordmark.
//   Restrained, no bullets/skulls/etc.
//
// The "LO" wordmark is drawn as pure primitives (rectangles + ring) instead
// of using a font. The image package's bitmap fonts blur badly when scaled
// to icon sizes, and it has no TrueType support. For a 2-letter placeholder
// glyph, hand-drawn primitives are crisper anyway.
//
// Re-run with:
//   dart pub run loadout:gen_icon
//
// Companion script tool/gen_icon.py exists for reference (the original
// design intent was Python+PIL with a real serif TTF), but this Dart port
// is what actually runs in the dev environment.

// CLI tool — `print` is the right output channel here. The `image` package is
// a dev_dependency used only by this build script, which the lint flags but
// is correct to import here.
// ignore_for_file: avoid_print, depend_on_referenced_packages

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const int canvas = 1024;

// Committed colors:
//   Background = charcoal gunmetal #1F2937
//   Foreground = warm brass        #C5A572
final bgColor = img.ColorRgb8(0x1F, 0x29, 0x37);
final fgColor = img.ColorRgb8(0xC5, 0xA5, 0x72);
final fgDim = img.ColorRgb8(0xA5, 0x8A, 0x5F);
final transparentRgba = img.ColorRgba8(0, 0, 0, 0);

/// Fill a circle with antialiasing using the package's primitive.
void disc(img.Image image, num cx, num cy, num r, img.Color color) {
  img.fillCircle(
    image,
    x: cx.round(),
    y: cy.round(),
    radius: r.round(),
    color: color,
    antialias: true,
  );
}

/// Draw an annulus (ring) directly by setting pixels. Each pixel's alpha is
/// derived from its signed distance to the centerline of the ring, giving a
/// soft anti-aliased edge that works on both opaque and transparent
/// canvases. We can't use disc-then-punch on an RGBA canvas because
/// fillCircle composites rather than replaces.
void ring(
  img.Image image, {
  required double cx,
  required double cy,
  required double radius,
  required double strokeWidth,
  required img.Color color,
}) {
  final outer = radius + strokeWidth / 2;
  final inner = radius - strokeWidth / 2;
  final cr = color.r.toInt();
  final cg = color.g.toInt();
  final cb = color.b.toInt();

  // Bounding box for the ring.
  final x0 = (cx - outer - 1).floor().clamp(0, image.width - 1);
  final x1 = (cx + outer + 1).ceil().clamp(0, image.width - 1);
  final y0 = (cy - outer - 1).floor().clamp(0, image.height - 1);
  final y1 = (cy + outer + 1).ceil().clamp(0, image.height - 1);

  for (var y = y0; y <= y1; y++) {
    final dy = y + 0.5 - cy;
    for (var x = x0; x <= x1; x++) {
      final dx = x + 0.5 - cx;
      final d = math.sqrt(dx * dx + dy * dy);
      // Alpha contribution = how much of the pixel is inside the ring.
      // For a ring, full alpha when inner < d < outer, with a 1px taper at
      // each edge.
      double a;
      if (d < inner - 0.5 || d > outer + 0.5) {
        continue;
      } else if (d > inner + 0.5 && d < outer - 0.5) {
        a = 1.0;
      } else if (d <= inner + 0.5) {
        a = (d - (inner - 0.5)).clamp(0.0, 1.0);
      } else {
        a = ((outer + 0.5) - d).clamp(0.0, 1.0);
      }
      _blendPixel(image, x, y, cr, cg, cb, a);
    }
  }
}

/// Composite one source pixel (RGB + alpha 0..1) onto [image] at (x, y),
/// preserving the channel count of the destination.
void _blendPixel(
  img.Image image,
  int x,
  int y,
  int sr,
  int sg,
  int sb,
  double srcA,
) {
  if (srcA <= 0) return;
  final p = image.getPixel(x, y);
  final dr = p.r.toInt();
  final dg = p.g.toInt();
  final db = p.b.toInt();
  final hasAlpha = image.numChannels == 4;
  final dAlpha = hasAlpha ? p.a / 255.0 : 1.0;

  // Standard "over" compositing.
  final outA = srcA + dAlpha * (1.0 - srcA);
  if (outA <= 0) return;
  final outR = (sr * srcA + dr * dAlpha * (1.0 - srcA)) / outA;
  final outG = (sg * srcA + dg * dAlpha * (1.0 - srcA)) / outA;
  final outB = (sb * srcA + db * dAlpha * (1.0 - srcA)) / outA;

  if (hasAlpha) {
    image.setPixelRgba(
      x,
      y,
      outR.round(),
      outG.round(),
      outB.round(),
      (outA * 255).round(),
    );
  } else {
    image.setPixelRgb(x, y, outR.round(), outG.round(), outB.round());
  }
}

/// Draw a filled rectangle (axis-aligned).
void rect(
  img.Image image, {
  required num x1,
  required num y1,
  required num x2,
  required num y2,
  required img.Color color,
}) {
  img.fillRect(
    image,
    x1: x1.round(),
    y1: y1.round(),
    x2: x2.round(),
    y2: y2.round(),
    color: color,
  );
}

/// Draw a chunky serif-ish "L" inside the rectangle (left, top, right,
/// bottom), in [color]. Hand-drawn geometry: a vertical stem with a serif
/// foot at the top, and a horizontal arm with a serif tip at the bottom-
/// right.
void drawL(
  img.Image image, {
  required double left,
  required double top,
  required double right,
  required double bottom,
  required img.Color color,
}) {
  final w = right - left;
  final h = bottom - top;

  // Vertical stem
  final stemW = w * 0.34;
  rect(
    image,
    x1: left,
    y1: top,
    x2: left + stemW,
    y2: bottom,
    color: color,
  );

  // Top serif (small overhang on both sides at top of stem)
  final topSerifH = h * 0.10;
  final topSerifOver = w * 0.13;
  rect(
    image,
    x1: left - topSerifOver,
    y1: top,
    x2: left + stemW + topSerifOver,
    y2: top + topSerifH,
    color: color,
  );

  // Bottom horizontal arm
  final armH = h * 0.22;
  rect(
    image,
    x1: left,
    y1: bottom - armH,
    x2: right,
    y2: bottom,
    color: color,
  );

  // Right tip serif (small upward foot at the end of the arm)
  final tipH = h * 0.12;
  final tipW = w * 0.06;
  rect(
    image,
    x1: right - tipW,
    y1: bottom - armH - tipH,
    x2: right,
    y2: bottom - armH,
    color: color,
  );
}

/// Draw an "O" centered on (cx, cy) as a thick ring of the given visual
/// height. Uses the direct-pixel ring helper (not disc-punch-disc) so it
/// works correctly on transparent canvases.
void drawO(
  img.Image image, {
  required double cx,
  required double cy,
  required double height,
  required img.Color color,
}) {
  final outerR = height / 2.0;
  final strokeW = outerR * 0.30;
  final centerR = outerR - strokeW / 2;

  ring(
    image,
    cx: cx,
    cy: cy,
    radius: centerR,
    strokeWidth: strokeW,
    color: color,
  );
}

/// Draw the LoadOut headstamp motif onto [image]. The motif is sized
/// relative to CANVAS; [scale] shrinks it (1.0 = full canvas, 0.6 = 60%
/// for adaptive foreground safe zone). Works on either an opaque canvas
/// (3-channel) or transparent canvas (4-channel).
void drawMotif(img.Image image, {required double scale}) {
  final cx = canvas / 2.0;
  final cy = canvas / 2.0;
  final motifRadius = (canvas / 2.0) * 0.86 * scale;

  final outerStroke = math.max(2.0, motifRadius * 0.045);
  final innerStroke = math.max(1.0, motifRadius * 0.020);

  // Outer ring (bold)
  ring(
    image,
    cx: cx,
    cy: cy,
    radius: motifRadius,
    strokeWidth: outerStroke,
    color: fgColor,
  );

  // Inner stamp ring (thin, slightly dimmer)
  final innerRingR = motifRadius * 0.78;
  ring(
    image,
    cx: cx,
    cy: cy,
    radius: innerRingR,
    strokeWidth: innerStroke,
    color: fgDim,
  );

  // "LO" wordmark sized to read clearly inside the inner ring.
  //
  // Layout: L on the left, O on the right, sharing a baseline. The L is
  // narrower than the O (typical serif proportion) so we size each glyph
  // separately. Total wordmark width = lWidth + spacing + oWidth, centered.
  final glyphHeight = innerRingR * 0.95;
  final lWidth = glyphHeight * 0.66;     // serif L is roughly 0.65-0.7 H
  final oWidth = glyphHeight;            // O is square (approximately)
  final spacing = glyphHeight * 0.09;
  final wordWidth = lWidth + spacing + oWidth;

  final wordLeft = cx - wordWidth / 2;
  final wordTop = cy - glyphHeight / 2;

  // L
  drawL(
    image,
    left: wordLeft,
    top: wordTop,
    right: wordLeft + lWidth,
    bottom: wordTop + glyphHeight,
    color: fgColor,
  );

  // O
  final oCx = wordLeft + lWidth + spacing + oWidth / 2;
  drawO(
    image,
    cx: oCx,
    cy: cy,
    height: glyphHeight,
    color: fgColor,
  );
}

Future<void> writePng(img.Image image, String path) async {
  final bytes = img.encodePng(image, level: 6);
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
  print('Wrote $path (${bytes.length} bytes)');
}

String hex(img.Color c) {
  String h(num v) => v.toInt().toRadixString(16).padLeft(2, '0').toUpperCase();
  return '#${h(c.r)}${h(c.g)}${h(c.b)}';
}

Future<void> main() async {
  // Master: solid dark background, full-scale motif. Opaque (numChannels: 3)
  // so iOS doesn't see any alpha channel.
  final master = img.Image(width: canvas, height: canvas, numChannels: 3);
  img.fill(master, color: bgColor);
  drawMotif(master, scale: 1.0);
  await writePng(master, 'assets/icon/icon.png');

  // Adaptive foreground: transparent canvas, motif at 60% scale. RGBA so we
  // get a real alpha channel.
  final fg = img.Image(width: canvas, height: canvas, numChannels: 4);
  img.fill(fg, color: transparentRgba);
  drawMotif(fg, scale: 0.60);
  await writePng(fg, 'assets/icon/icon_foreground.png');

  print('Background color: ${hex(bgColor)}');
  print('Foreground color: ${hex(fgColor)}');
  print('Glyphs: hand-drawn geometric "LO" wordmark (no font dependency).');
}
