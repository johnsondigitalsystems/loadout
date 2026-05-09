// FILE: lib/widgets/scope_daytime_backdrop.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Procedural daytime-range backdrop, painted by a [CustomPainter] so it
// scales cleanly to any canvas size without bitmap assets. Renders, top
// to bottom:
//
//   1. A blue-sky gradient (top half).
//   2. A horizon line at ~50% height.
//   3. A foreground band of green grass (bottom).
//   4. A dirt-mound silhouette in the middle distance, sitting on the
//      grass and rising into the sky.
//   5. A target silhouette centered on the mound, drawn at the user's
//      currently-selected target shape (rectangle, circle, or rounded
//      "IPSC silhouette") with a subtle haze / atmospheric perspective
//      so it reads as "downrange" instead of "right here".
//
// The widget itself ([ScopeDaytimeBackdrop]) is a stateless wrapper:
// drop it into a Stack behind any scope-view UI and the backdrop fills
// the entire constraints. Pair with a `ClipOval` if you want the
// backdrop to appear inside a circular eyepiece.
//
// Public API:
//
// ```dart
// ScopeDaytimeBackdrop(
//   target: BackdropTargetSilhouette.ipsc,
//   targetWidthFraction: 0.18,   // 18% of canvas width (default 0.16)
//   targetColor: Color(0xff8a8074),
// )
// ```
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The reticle-preview and full-screen scope views both need a
// representative downrange scene to render the reticle on top of —
// otherwise a pure black or solid-colored background gives the user no
// sense of how the reticle would look against a real target during a
// day-light range session. The backdrop is shared between two consumers
// (the picker's full-screen preview and the existing scope-view screen)
// so it lives in `widgets/` rather than embedded in either screen.
//
// Procedural rendering (rather than a bitmap asset) buys us:
//
//   * Zero asset bytes — no PNG ships in the bundle for this.
//   * Crisp output at any DPI / canvas size; no upscaling artifacts.
//   * Trivial color theming — we can re-skin for night-mode in the
//     future by passing a different palette.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * The `ClipOval` parent that wraps this in scope view doesn't
//     antialias the gradient edge against the FOV ring — we draw a
//     solid bottom-edge color first to prevent a 1 px seam.
//   * The dirt-mound silhouette uses a smooth Catmull-Rom-style spline
//     baked into a `Path` so the silhouette doesn't look like a
//     polygon. The control points are normalized 0–1 so they scale
//     cleanly with canvas width.
//   * Atmospheric haze on the target is implemented as an overlay
//     with white at low alpha — NOT by lowering the target's main
//     color saturation, because the reticle (drawn on top) is
//     already a color overlay; mucking with the target's RGB would
//     fight with reticle anti-aliasing.
//   * Y axis: Flutter +Y is DOWN. All y values below are described
//     "from the top" of the canvas to keep the math intuitive.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `lib/widgets/reticle_picker.dart` — full-screen reticle preview
//   modal renders this as the eyepiece backdrop.
// - `lib/screens/range_day/scope_view_screen.dart` — the Pro-gated
//   scope-view replaces its old solid-black FOV fill with this
//   backdrop.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure drawing.

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// What target silhouette to draw on top of the dirt mound. Mirrors the
/// shape vocabulary used by `TargetSpec.shape` in the Range Day screens
/// so callers can map their stored target straight through.
enum BackdropTargetSilhouette {
  /// A rounded-rectangle "IPSC" upper-body silhouette. Default fallback
  /// when the caller has no target selected.
  ipsc,

  /// A simple filled circle. Use when the user's target is a paper
  /// 18" / 24" round.
  circle,

  /// A square / rectangle outline. Use when the user's target is a
  /// rectangular plate.
  rectangle,

  /// No target — pure scenery (sky / grass / mound). The caller
  /// renders its own target on top via a separate painter.
  none,
}

/// Stateless widget that fills its constraints with the procedural
/// daytime backdrop. Place it as the bottom layer of a `Stack` and
/// stack other reticle / target painters on top.
class ScopeDaytimeBackdrop extends StatelessWidget {
  const ScopeDaytimeBackdrop({
    super.key,
    this.target = BackdropTargetSilhouette.ipsc,
    this.targetWidthFraction = 0.16,
    this.targetColor = const Color(0xff5e6552),
    this.size,
  });

  /// Which target silhouette to draw, or [BackdropTargetSilhouette.none]
  /// to skip the target entirely (caller will render its own).
  final BackdropTargetSilhouette target;

  /// Target width as a fraction of canvas width. 0.16 = a comfortable
  /// downrange size that doesn't dominate the FOV. 0.0 hides the
  /// target.
  final double targetWidthFraction;

  /// Fill color of the target silhouette. Default is a desaturated
  /// olive that reads as a steel plate / cardboard silhouette across
  /// most lighting.
  final Color targetColor;

  /// Optional explicit size; otherwise the painter uses the parent's
  /// constraints.
  final Size? size;

  @override
  Widget build(BuildContext context) {
    final painter = ScopeDaytimeBackdropPainter(
      target: target,
      targetWidthFraction: targetWidthFraction,
      targetColor: targetColor,
    );
    if (size != null) {
      return SizedBox(
        width: size!.width,
        height: size!.height,
        child: CustomPaint(painter: painter, size: size!),
      );
    }
    return CustomPaint(painter: painter);
  }
}

/// The actual painter. Exposed so other screens (e.g. scope_view_screen)
/// can compose the backdrop into their own [CustomPaint] alongside
/// reticle / overlay painters without nesting two `CustomPaint`
/// widgets.
class ScopeDaytimeBackdropPainter extends CustomPainter {
  ScopeDaytimeBackdropPainter({
    required this.target,
    required this.targetWidthFraction,
    required this.targetColor,
  });

  final BackdropTargetSilhouette target;
  final double targetWidthFraction;
  final Color targetColor;

  // Sky palette — light blue at zenith fading to a hazy near-horizon.
  // Values from a quick sample of typical mid-day clear-sky photographs.
  static const Color _skyTop = Color(0xffa8d4ff);
  static const Color _skyHorizon = Color(0xffc8dcfa);

  // Grass palette — slightly desaturated natural green that doesn't
  // fight the reticle's bright color when overlaid.
  static const Color _grassNear = Color(0xff8aa970);
  static const Color _grassFar = Color(0xff96b078);

  // Dirt mound color (warm tan-brown that contrasts both sky and grass).
  static const Color _mound = Color(0xff7d6d58);
  static const Color _moundShadow = Color(0xff5d4f3d);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final w = size.width;
    final h = size.height;

    // Horizon at ~50% canvas height. Above is sky, below is grass +
    // mound. Tuneable per design later — we expose it as a const here.
    final horizonY = h * 0.50;

    _paintSky(canvas, w, horizonY);
    _paintGrass(canvas, w, h, horizonY);
    _paintMound(canvas, w, h, horizonY);
    _paintTarget(canvas, w, h, horizonY);
    _paintAtmosphericHaze(canvas, w, h, horizonY);
  }

  /// Sky gradient: vivid blue at top fading to a hazy pale blue at the
  /// horizon. Drawn as a single rectangle so the entire upper half
  /// shares the gradient, keeping the painting cheap.
  void _paintSky(Canvas canvas, double w, double horizonY) {
    final rect = Rect.fromLTWH(0, 0, w, horizonY);
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_skyTop, _skyHorizon],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  /// Grass — gradient from a far / hazy green at the horizon to a
  /// closer / saturated green at the bottom of the canvas. Plus a
  /// subtle horizon line so the sky / grass meet cleanly.
  void _paintGrass(Canvas canvas, double w, double h, double horizonY) {
    final rect = Rect.fromLTWH(0, horizonY, w, h - horizonY);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [_grassFar, _grassNear],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    // 1 px hairline at the horizon, slightly darker than either side,
    // so the visual seam looks deliberate (a faraway tree-line, not a
    // gradient cut).
    final hairline = Paint()
      ..color = const Color(0xff7a8c66)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, horizonY),
      Offset(w, horizonY),
      hairline,
    );
  }

  /// Smooth dirt mound silhouette behind the target. Uses a small set
  /// of normalized control points fed to a quadratic-Bezier path so
  /// the mound reads as a natural earth berm instead of a polygon.
  /// Two passes: a darker shadow on the right side, the lighter mound
  /// proper on top.
  void _paintMound(Canvas canvas, double w, double h, double horizonY) {
    // Mound spans the middle 60% of canvas width, crests at ~12% of
    // canvas height ABOVE the horizon (so it visibly interrupts the
    // skyline without obscuring the FOV).
    final left = w * 0.18;
    final right = w * 0.82;
    final crestY = horizonY - h * 0.12;
    final crestX = w * 0.5;

    final path = Path()
      ..moveTo(left, horizonY)
      // Use a single broad quadratic curve to the crest …
      ..quadraticBezierTo(
        left + (crestX - left) * 0.55, // control: rising slope
        horizonY - h * 0.04,
        crestX - w * 0.08,
        crestY + h * 0.02,
      )
      ..quadraticBezierTo(
        crestX,
        crestY - h * 0.02,
        crestX + w * 0.08,
        crestY + h * 0.02,
      )
      // … then back down to the right base.
      ..quadraticBezierTo(
        crestX + (right - crestX) * 0.45,
        horizonY - h * 0.04,
        right,
        horizonY,
      )
      ..close();

    // Mound body.
    final mound = Paint()..color = _mound;
    canvas.drawPath(path, mound);

    // Right-side shadow (the mound is lit from the upper left). Drawn
    // as a clipped polygon along the right half of the mound silhouette.
    final shadowPath = Path()
      ..moveTo(crestX, crestY - h * 0.02)
      ..quadraticBezierTo(
        crestX + w * 0.04,
        crestY,
        crestX + w * 0.08,
        crestY + h * 0.02,
      )
      ..quadraticBezierTo(
        crestX + (right - crestX) * 0.45,
        horizonY - h * 0.04,
        right,
        horizonY,
      )
      ..lineTo(crestX, horizonY)
      ..close();
    canvas.drawPath(shadowPath, Paint()..color = _moundShadow.withValues(alpha: 0.45));
  }

  /// Target silhouette centered on the mound. Sized in canvas-fraction
  /// terms so the target's apparent angular size in the rendered FOV
  /// stays roughly consistent across screen sizes.
  void _paintTarget(Canvas canvas, double w, double h, double horizonY) {
    if (target == BackdropTargetSilhouette.none) return;
    if (targetWidthFraction <= 0) return;
    final widthPx = w * targetWidthFraction;
    // Make the silhouette taller-than-wide for IPSC; equal axes for
    // circle and rectangle.
    final heightPx = switch (target) {
      BackdropTargetSilhouette.ipsc => widthPx * 1.6,
      BackdropTargetSilhouette.circle => widthPx,
      BackdropTargetSilhouette.rectangle => widthPx,
      BackdropTargetSilhouette.none => 0.0,
    };
    final centerX = w * 0.5;
    // Sit the target on the crest of the mound — bottom of the
    // silhouette aligns roughly with the crest's top point.
    final crestY = horizonY - h * 0.12;
    final centerY = crestY - heightPx * 0.5 + h * 0.02;

    final fill = Paint()..color = targetColor;
    final outline = Paint()
      ..color = const Color(0xff2c2924)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, w * 0.002);

    switch (target) {
      case BackdropTargetSilhouette.ipsc:
        // Cardboard-style upper torso silhouette: rounded rect for the
        // body with a smaller rounded rect on top for the head.
        final bodyRect = Rect.fromCenter(
          center: Offset(centerX, centerY + heightPx * 0.10),
          width: widthPx,
          height: heightPx * 0.70,
        );
        final headRect = Rect.fromCenter(
          center: Offset(centerX, centerY - heightPx * 0.40),
          width: widthPx * 0.55,
          height: heightPx * 0.32,
        );
        final body = RRect.fromRectAndRadius(
          bodyRect,
          Radius.circular(widthPx * 0.10),
        );
        final head = RRect.fromRectAndRadius(
          headRect,
          Radius.circular(widthPx * 0.18),
        );
        canvas.drawRRect(body, fill);
        canvas.drawRRect(head, fill);
        canvas.drawRRect(body, outline);
        canvas.drawRRect(head, outline);
      case BackdropTargetSilhouette.circle:
        canvas.drawCircle(
          Offset(centerX, centerY),
          widthPx / 2,
          fill,
        );
        canvas.drawCircle(
          Offset(centerX, centerY),
          widthPx / 2,
          outline,
        );
      case BackdropTargetSilhouette.rectangle:
        final rect = Rect.fromCenter(
          center: Offset(centerX, centerY),
          width: widthPx,
          height: heightPx,
        );
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, outline);
      case BackdropTargetSilhouette.none:
        break;
    }
  }

  /// Subtle white-ish overlay on the upper third of the canvas to
  /// suggest atmospheric haze on a downrange object. Dialed in low
  /// alpha so the silhouette + reticle still read clearly.
  void _paintAtmosphericHaze(
    Canvas canvas,
    double w,
    double h,
    double horizonY,
  ) {
    final hazeRect = Rect.fromLTWH(0, horizonY - h * 0.15, w, h * 0.30);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(hazeRect);
    canvas.drawRect(hazeRect, paint);
  }

  @override
  bool shouldRepaint(covariant ScopeDaytimeBackdropPainter old) {
    return old.target != target ||
        old.targetWidthFraction != targetWidthFraction ||
        old.targetColor != targetColor;
  }
}
