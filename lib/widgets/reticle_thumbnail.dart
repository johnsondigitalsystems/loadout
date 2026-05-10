// FILE: lib/widgets/reticle_thumbnail.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Tiny "iconographic" reticle thumbnail intended for dense list rows in
// the reticle picker. Renders a generic crosshair shape with two short
// hash marks on each axis — NOT the full reticle definition. Roughly
// 32×32 px when paired with [ReticleThumbnail.size].
//
// Why a stripped-down generic glyph instead of the real reticle? At
// 32×32 the elaborate subtension trees of modern precision-rifle
// reticles (Tremor3, MIL-XT, EBR-7C) become an unreadable smear of
// pixels — visually noisy without conveying any information about
// which reticle the row represents (the row's text label and the
// "Preview" button do that). Replacing the smear with a clean glyph
// keeps the row scannable and lets the reticle's name carry the
// identification load.
//
// Public API:
//
// ```dart
// ReticleThumbnail(
//   size: 32,           // optional, default 32
//   color: theme.colorScheme.primary,
// )
// ```
//
// The thumbnail is intentionally NOT specific to a particular
// [ReticleDefinition]. Every reticle row in the picker shares the
// same glyph; the distinguishing detail is in the row's name +
// family + unit subtitle, plus the optional full-screen preview.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Earlier the picker called the full [ReticleRenderer] at 64×64 to
// produce per-row previews. The previews were too small to evaluate
// (hash marks blurred together) and visually noisy (every row had a
// different blob). Replacing them with this generic thumbnail trims
// list-rendering cost (we paint a 4-line glyph instead of the full
// element loop for every visible row) AND simplifies the row
// hierarchy — the user sees "this row is a reticle" via the icon and
// reads the name to identify which one. Tapping the dedicated
// "Preview" trailing icon then opens the high-fidelity full-screen
// version.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// Resist the urge to "improve" this widget by per-reticle rendering
// at small sizes — that's the design we already abandoned. The
// row's name + unit + family carries the identity; this glyph
// carries the affordance ("this row is a reticle, tap the preview
// to see it"). A custom-drawn 32px reticle defeats both purposes.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `lib/widgets/reticle_picker.dart` — the picker's list rows.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None.

import 'package:flutter/material.dart';

/// A small generic reticle glyph (cross + 2 hash marks per axis) for
/// dense list-row thumbnails. Not specific to any particular reticle
/// definition.
class ReticleThumbnail extends StatelessWidget {
  const ReticleThumbnail({
    super.key,
    this.size = 32,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurfaceVariant;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ReticleThumbnailPainter(color: c),
        size: Size(size, size),
      ),
    );
  }
}

class _ReticleThumbnailPainter extends CustomPainter {
  _ReticleThumbnailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    // Stroke widths scale with size so a 16 px thumb still paints
    // hairline-thin rather than a fat blob.
    final strokeMain = (size.shortestSide * 0.06).clamp(0.8, 2.0);
    final strokeHash = (size.shortestSide * 0.05).clamp(0.6, 1.6);

    final mainPaint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = strokeMain;
    final hashPaint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = strokeHash;

    // Main cross — leaves a tiny gap in the center so the eye reads
    // it as a crosshair rather than a plus glyph.
    final centerGap = size.shortestSide * 0.06;
    final crossLen = size.shortestSide * 0.42;

    // Horizontal arms.
    canvas.drawLine(
      Offset(cx - crossLen, cy),
      Offset(cx - centerGap, cy),
      mainPaint,
    );
    canvas.drawLine(
      Offset(cx + centerGap, cy),
      Offset(cx + crossLen, cy),
      mainPaint,
    );
    // Vertical arms.
    canvas.drawLine(
      Offset(cx, cy - crossLen),
      Offset(cx, cy - centerGap),
      mainPaint,
    );
    canvas.drawLine(
      Offset(cx, cy + centerGap),
      Offset(cx, cy + crossLen),
      mainPaint,
    );

    // Two hash marks per axis at 1/3 and 2/3 of the arm length so the
    // thumbnail conveys "ranging reticle" without a 200-element
    // tree.
    final hashLen = size.shortestSide * 0.07;
    void hash(double dxFromCenter, double dyFromCenter,
        {required bool vertical}) {
      final p = Offset(cx + dxFromCenter, cy + dyFromCenter);
      if (vertical) {
        canvas.drawLine(
          p.translate(0, -hashLen / 2),
          p.translate(0, hashLen / 2),
          hashPaint,
        );
      } else {
        canvas.drawLine(
          p.translate(-hashLen / 2, 0),
          p.translate(hashLen / 2, 0),
          hashPaint,
        );
      }
    }

    final hashAt1 = crossLen * 0.45;
    final hashAt2 = crossLen * 0.85;
    // Horizontal axis hash marks (vertical ticks crossing the
    // horizontal arm).
    hash(-hashAt1, 0, vertical: true);
    hash(hashAt1, 0, vertical: true);
    hash(-hashAt2, 0, vertical: true);
    hash(hashAt2, 0, vertical: true);
    // Vertical axis hash marks (horizontal ticks crossing the
    // vertical arm).
    hash(0, -hashAt1, vertical: false);
    hash(0, hashAt1, vertical: false);
    hash(0, -hashAt2, vertical: false);
    hash(0, hashAt2, vertical: false);

    // Tiny center dot.
    canvas.drawCircle(
      Offset(cx, cy),
      (size.shortestSide * 0.04).clamp(0.6, 2.0),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _ReticleThumbnailPainter old) {
    return old.color != color;
  }
}
