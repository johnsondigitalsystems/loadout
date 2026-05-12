// FILE: lib/widgets/reticle_renderer.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Stateless widget that draws a [ReticleDefinition] onto a Flutter canvas.
// The reticle's drawable elements are defined in
// `lib/data/reticle_library.dart`; this widget interprets them, scales
// them to the available widget size, optionally re-anchors the reticle
// to a non-center "aim point" pixel, and paints them with a
// [CustomPainter].
//
// The widget is the visual half of two pieces of work:
//
//   * `ReticleDefinition` (data) — JSON-decoded subtension, holdover and
//     hash mark layout. Lives in `lib/data/reticle_library.dart`.
//   * `ReticleRenderer` (UI) — this file. Translates a definition into
//     a CustomPainter and renders it.
//
// We're stateless: the parent widget owns the picked reticle, the aim
// point pixel, the color, the scale, etc. All we do is paint.
//
// ============================================================================
// COORDINATE CONVENTION
// ============================================================================
// Reticle elements are stored in the reticle's *native unit* (mil, MOA,
// ipsc, bdc). At render time we convert to widget pixels using:
//
//   pixelsPerUnit = (size.shortestSide * 0.45) / maxExtentUnits * scale
//
// where `maxExtentUnits` is the reticle's half-extent (so 1.0 unit at
// scale 1.0 in a 280×280 canvas works out to ~12.6 px). The center of
// the reticle is `aimPoint` if provided, otherwise the canvas center.
// Reticle Y axis: +1 = up (positive native units = up). Flutter canvas:
// +Y = down. So we flip Y when we map element coordinates to pixels.
//
// ============================================================================
// HOLD-OVER HIGHLIGHTING
// ============================================================================
// When the caller passes a [FiringHoldOver], we paint a filled circle on
// the reticle at the projected (elevationMil, windageMil) coordinate.
// The hold-over is always provided in MIL — we convert internally to the
// reticle's native unit before plotting so the circle lands on whatever
// hash mark a real shooter would use as their hold. Sign convention:
//   * elevationMil > 0  → hold UP (impact below LoS at the range)
//   * windageMil   > 0  → hold RIGHT (wind pushes from the right; the
//                                     shooter holds into the wind)

import 'package:flutter/material.dart';

import '../data/reticle_library.dart';

/// Firing-solution dial that the renderer projects onto the reticle as a
/// hold-over highlight. Both fields are in milliradians; the renderer
/// converts to the reticle's native unit before plotting so a MOA reticle
/// gets the highlight on the right MOA hash.
///
/// Sign convention is "what the shooter is holding for", not the bullet's
/// raw drop / drift:
///   * `elevationMil` positive — hold UP (compensates for bullet drop).
///   * `windageMil`   positive — hold RIGHT (compensates for left-to-right wind).
///
/// Range Day passes the live firing solution into this object after
/// converting the solver's drop / wind drift inches to mils at the active
/// range via [bu.inchesToMilAtYards].
class FiringHoldOver {
  const FiringHoldOver({
    required this.elevationMil,
    required this.windageMil,
  });

  final double elevationMil;
  final double windageMil;

  bool get isZero => elevationMil.abs() < 1e-6 && windageMil.abs() < 1e-6;
}

class ReticleRenderer extends StatelessWidget {
  const ReticleRenderer({
    super.key,
    required this.reticle,
    required this.displayUnit,
    this.scale = 1.0,
    this.color,
    this.aimPoint,
    this.size = const Size(280, 280),
    this.showUnitOverlay = true,
    this.holdOver,
    this.holdOverHighlightColor,
    this.lowLightMode = false,
  });

  /// The reticle definition to render.
  final ReticleDefinition reticle;

  /// 'mil' or 'moa' — only changes the labels on FloatingNumber elements.
  /// The reticle geometry stays in native units.
  final String displayUnit;

  /// Multiplier applied to the auto-fit scale. 1.0 = the reticle's
  /// half-extent fills 45% of the shortest widget side.
  final double scale;

  /// Override stroke color. Defaults to BLACK — etched-glass
  /// reticles render as black hash lines on the bright daytime
  /// backdrop. The brass theme primary made the marks blend into
  /// sky and grass; black reads cleanly against every backdrop and
  /// matches what the user actually sees through their scope.
  final Color? color;

  /// Pixel offset (relative to the widget) where the reticle center
  /// should sit. Null = centered.
  final Offset? aimPoint;

  /// Canvas size. The widget can be embedded in any constraint — we
  /// honour the explicit size first and fall back to the parent's
  /// constraints if the parent gives us a finite box.
  final Size size;

  /// Whether to paint the corner unit overlay ("MIL @ FFP"). Disabled
  /// by callers that render small thumbnails (e.g. the picker preview)
  /// where the label would crowd the reticle.
  final bool showUnitOverlay;

  /// When non-null, paint a hold-over highlight at the matching hash on
  /// the reticle. The renderer projects (elevationMil, windageMil) into
  /// the reticle's native units and draws a small filled circle there
  /// — visually telling the shooter "this is the dial / hold the firing
  /// solution is asking for".
  final FiringHoldOver? holdOver;

  /// Override the hold-over highlight color. Defaults to the theme's
  /// secondary at 0.85 alpha so it stands apart from the reticle line
  /// color (which uses primary by default).
  final Color? holdOverHighlightColor;

  /// When `true`, every element whose [ReticleElement.illuminatedColorHex]
  /// is non-null renders in its authored color (simulating a real
  /// scope's illuminated reticle at dusk). Elements without an
  /// illumination color stay on the default [color] — still visible
  /// but understated, which matches what a shooter actually sees
  /// through their scope in low light. Defaults to `false`; flipped
  /// to `true` by the Range Day Realistic "Low Light" AppBar toggle.
  /// See `range_day_realistic_rewrite_v23.md` §6A.2.
  final bool lowLightMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Default reticle stroke is BLACK app-wide — see the `color`
    // field doc for rationale.
    final lineColor = color ?? Colors.black;
    final highlight = holdOverHighlightColor ??
        theme.colorScheme.secondary.withValues(alpha: 0.85);
    return SizedBox(
      width: size.width,
      height: size.height,
      child: CustomPaint(
        size: size,
        painter: _ReticlePainter(
          reticle: reticle,
          displayUnit: displayUnit,
          scale: scale,
          lineColor: lineColor,
          aimPoint: aimPoint,
          showUnitOverlay: showUnitOverlay,
          holdOver: holdOver,
          holdOverHighlightColor: highlight,
          lowLightMode: lowLightMode,
        ),
      ),
    );
  }
}

/// Adaptive level-of-detail gate per v2.3 brief §6A.1. Returns true when
/// [element] is large enough at the current [pxPerUnit] scale to be
/// visually meaningful — sub-pixel elements get skipped so that
/// low-magnification renders don't drown in noise from sub-hashes that
/// can't possibly be visible.
///
/// Thresholds (per brief §6A.1):
///   * Crosshair / line: always render (load-bearing structural elements)
///   * Hash: skip when `lengthUnits * pxPerUnit < 1.5` (visible tick = 1.5 px)
///   * Dot (centre + holdover): skip when `radiusUnits * pxPerUnit < 0.5`
///     (diameter ≥ 1 px to be visible)
///   * Floating number / label: skip when `fontSizeUnits * pxPerUnit < 6.0`
///     (below readable text minimum)
///
/// Called once per element from `_ReticlePainter.paint`. The performance
/// cost of the gate is negligible compared to the alternative of drawing
/// a few hundred sub-pixel elements per frame at 1x LPVO. Public for
/// unit-test access — `test/reticle_lod_test.dart` exercises every
/// element-type branch against a representative pxPerUnit range.
bool shouldRenderReticleElement(ReticleElement element, double pxPerUnit) {
  switch (element) {
    case CrosshairLine():
      return true;
    case HashMark():
      return element.lengthUnits * pxPerUnit >= 1.5;
    case CenterDot():
      return element.radiusUnits * pxPerUnit >= 0.5;
    case HoldoverDot():
      return element.radiusUnits * pxPerUnit >= 0.5;
    case FloatingNumber():
      return element.fontSizeUnits * pxPerUnit >= 6.0;
  }
}

class _ReticlePainter extends CustomPainter {
  _ReticlePainter({
    required this.reticle,
    required this.displayUnit,
    required this.scale,
    required this.lineColor,
    required this.aimPoint,
    required this.showUnitOverlay,
    required this.holdOver,
    required this.holdOverHighlightColor,
    required this.lowLightMode,
  });

  final ReticleDefinition reticle;
  final String displayUnit;
  final double scale;
  final Color lineColor;
  final Offset? aimPoint;
  final bool showUnitOverlay;
  final FiringHoldOver? holdOver;
  final Color holdOverHighlightColor;
  final bool lowLightMode;

  /// Resolve the stroke / fill color for one element. When [lowLightMode]
  /// is true AND the element publishes a non-null
  /// [ReticleElement.illuminatedColorHex], we parse that hex into a
  /// fully-opaque [Color] and return it (simulating an illuminated
  /// reticle at dusk). Otherwise we return [lineColor] unchanged.
  ///
  /// Hex parsing is tolerant: accepts `'#RRGGBB'`, `'RRGGBB'`,
  /// `'#AARRGGBB'`, or `'AARRGGBB'`. Any malformed value falls back
  /// to [lineColor] silently — a broken seed entry should never crash
  /// the painter.
  Color _resolveElementColor(ReticleElement el) {
    if (!lowLightMode) return lineColor;
    final hex = el.illuminatedColorHex;
    if (hex == null) return lineColor;
    var raw = hex.startsWith('#') ? hex.substring(1) : hex;
    if (raw.length == 6) raw = 'FF$raw';
    if (raw.length != 8) return lineColor;
    final v = int.tryParse(raw, radix: 16);
    if (v == null) return lineColor;
    return Color(v);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (reticle.maxExtentUnits <= 0) return;
    // Pixels per native unit (mil/MOA). 0.45 leaves a comfortable margin
    // around the visible reticle on a square canvas.
    final pxPerUnit =
        (size.shortestSide * 0.45) / reticle.maxExtentUnits * scale;
    final centre = aimPoint ?? Offset(size.width / 2, size.height / 2);

    Offset toPx(double xUnits, double yUnits) {
      // Native +Y is up; Flutter canvas +Y is down — so flip the Y term.
      return Offset(
        centre.dx + xUnits * pxPerUnit,
        centre.dy - yUnits * pxPerUnit,
      );
    }

    // Stroke + fill Paints are reused across every element — their
    // .color is reassigned per element via [_resolveElementColor] so
    // a single illuminated dot can render red without forcing every
    // other element to allocate its own Paint. Default color is
    // [lineColor]; the per-element color is set just before each draw
    // call below.
    final stroke = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    final fill = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    for (final el in reticle.elements) {
      // §6A.1 adaptive LOD gate. Skip sub-pixel elements at low
      // magnification so a reticle that looks correct at 5x doesn't
      // smear into visual noise at 1x LPVO. Crosshairs always render
      // (load-bearing); hashes / dots / numbers gate on pxPerUnit
      // thresholds documented above the function.
      if (!shouldRenderReticleElement(el, pxPerUnit)) continue;
      // §6A.2 illumination: when the parent has flipped lowLightMode
      // on AND this element carries an authored illuminated color,
      // [_resolveElementColor] returns that color; otherwise it
      // returns [lineColor]. Reassign both shared paints so the
      // element's stroke + fill render in the right shade.
      final elColor = _resolveElementColor(el);
      stroke.color = elColor;
      fill.color = elColor;
      switch (el) {
        case CrosshairLine():
          stroke.strokeWidth = (el.thicknessMil * pxPerUnit).clamp(0.6, 6.0);
          canvas.drawLine(
            toPx(el.startX, el.startY),
            toPx(el.endX, el.endY),
            stroke,
          );
        case HashMark():
          stroke.strokeWidth =
              (el.thicknessUnits * pxPerUnit).clamp(0.4, 4.0);
          final half = el.lengthUnits / 2;
          if (el.axis == HashAxis.horizontal) {
            // Tick stands vertically across the horizontal axis.
            canvas.drawLine(
              toPx(el.x, el.y - half),
              toPx(el.x, el.y + half),
              stroke,
            );
          } else {
            // Tick lies horizontally across the vertical axis.
            canvas.drawLine(
              toPx(el.x - half, el.y),
              toPx(el.x + half, el.y),
              stroke,
            );
          }
        case CenterDot():
          final r = (el.radiusUnits * pxPerUnit).clamp(0.6, 8.0);
          if (el.open) {
            stroke.strokeWidth = (r * 0.25).clamp(0.5, 2.0);
            canvas.drawCircle(toPx(el.x, el.y), r, stroke);
          } else {
            canvas.drawCircle(toPx(el.x, el.y), r, fill);
          }
        case HoldoverDot():
          final r = (el.radiusUnits * pxPerUnit).clamp(0.6, 8.0);
          canvas.drawCircle(toPx(el.x, el.y), r, fill);
        case FloatingNumber():
          // Convert label only if display unit differs from native unit.
          final native = reticle.nativeUnit;
          final asMoa = displayUnit.toLowerCase() == 'moa';
          final asMil = displayUnit.toLowerCase() == 'mil';
          final shouldConvert =
              (asMoa && native == ReticleNativeUnit.mil) ||
                  (asMil && native == ReticleNativeUnit.moa);
          final asDouble = double.tryParse(el.text);
          final label = (shouldConvert && asDouble != null)
              ? convertReticleUnit(
                  value: asDouble,
                  from: native,
                  to: asMoa
                      ? ReticleNativeUnit.moa
                      : ReticleNativeUnit.mil,
                ).toStringAsFixed(0)
              : el.text;
          final fs = (el.fontSizeUnits * pxPerUnit).clamp(8.0, 24.0);
          final tp = TextPainter(
            text: TextSpan(
              text: label,
              style: TextStyle(
                color: elColor,
                fontSize: fs,
                fontWeight: FontWeight.w500,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final pt = toPx(el.x, el.y);
          tp.paint(canvas, pt - Offset(tp.width / 2, tp.height / 2));
      }
    }

    // Aim-point indicator. Draws a small open ring around the reticle's
    // (0, 0) when the caller passed an explicit aim point that differs
    // noticeably from the geometric center. Lets the user see where the
    // crosshair is sitting on the target plot in Range Day.
    if (aimPoint != null) {
      final geomCenter = Offset(size.width / 2, size.height / 2);
      if ((aimPoint! - geomCenter).distance > 1.0) {
        canvas.drawCircle(
          aimPoint!,
          4.0,
          Paint()
            ..color = lineColor.withValues(alpha: 0.6)
            ..strokeWidth = 1.0
            ..style = PaintingStyle.stroke,
        );
      }
    }

    // Hold-over highlight. The renderer is given the firing solution as
    // (elevationMil, windageMil) — we convert into the reticle's native
    // unit, project to pixel space using the same `pxPerUnit` factor as
    // the elements, and paint a small filled circle there. The shooter
    // sees the matching hash on the reticle "lit up".
    final ho = holdOver;
    if (ho != null) {
      // mil → reticle native unit. For mil reticles this is identity;
      // for MOA reticles we multiply by 3.43775; for IPSC / BDC we treat
      // it as mil-equivalent (those reticles don't have a true angular
      // sub-tension so the highlight ends up plotted at the mil position
      // — best we can do without per-reticle calibration data).
      final milToNative = switch (reticle.nativeUnit) {
        ReticleNativeUnit.mil => 1.0,
        ReticleNativeUnit.moa => milToMoa,
        ReticleNativeUnit.ipsc => 1.0,
        ReticleNativeUnit.bdc => 1.0,
      };
      // Reticle convention: +y up = "hold up" in shooter terms, +x right
      // = "hold right". `elevationMil > 0` means the user holds higher,
      // i.e. the highlight goes ABOVE center (positive native y), which
      // matches the existing reticle layout where holdover hashes sit on
      // the +y axis below the center crosshair when the bullet drops.
      //
      // Wait — the upper half of a precision reticle is the cleared half
      // and the LOWER half (negative y) is where holdover hashes sit (so
      // the crosshair stays clear at ranges where you hold above). To
      // match that, hold-up in elevation corresponds to plotting on the
      // -y side of the reticle (canvas-up, since we flip Y in toPx).
      // That makes the highlight land on the holdover marks the shooter
      // would actually use.
      final holdNativeY = -ho.elevationMil * milToNative;
      final holdNativeX = ho.windageMil * milToNative;
      final pt = toPx(holdNativeX, holdNativeY);
      final r = (size.shortestSide * 0.018).clamp(4.0, 6.5);
      // Soft halo first, then the crisp filled core.
      canvas.drawCircle(
        pt,
        r + 2.5,
        Paint()..color = holdOverHighlightColor.withValues(alpha: 0.25),
      );
      canvas.drawCircle(
        pt,
        r,
        Paint()..color = holdOverHighlightColor,
      );
      // Thin white outline so the dot reads against any reticle color.
      canvas.drawCircle(
        pt,
        r,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    if (showUnitOverlay) {
      _drawUnitOverlay(canvas, size);
    }
  }

  void _drawUnitOverlay(Canvas canvas, Size size) {
    // Skip the overlay if the canvas is too small to fit it without
    // overlapping the reticle.
    if (size.shortestSide < 90) return;
    final unitLabel = displayUnit.toUpperCase();
    final planeLabel = switch (reticle.type) {
      ReticleType.firstFocalPlane => 'FFP',
      ReticleType.secondFocalPlane => 'SFP',
      ReticleType.fixed => 'FIXED',
    };
    final tp = TextPainter(
      text: TextSpan(
        text: '$unitLabel @ $planeLabel',
        style: TextStyle(
          color: lineColor.withValues(alpha: 0.7),
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(8, 6));
  }

  @override
  bool shouldRepaint(covariant _ReticlePainter old) {
    return old.reticle.id != reticle.id ||
        old.displayUnit != displayUnit ||
        old.scale != scale ||
        old.lineColor != lineColor ||
        old.aimPoint != aimPoint ||
        old.showUnitOverlay != showUnitOverlay ||
        old.holdOver?.elevationMil != holdOver?.elevationMil ||
        old.holdOver?.windageMil != holdOver?.windageMil ||
        old.holdOverHighlightColor != holdOverHighlightColor ||
        old.lowLightMode != lowLightMode;
  }
}

/// Small caption label shown directly under reticle previews. The exact
/// copy is driven by the reticle's `subtensionOrigin`, per §7.7 of the
/// Range Day v2.3 dual-track IP posture (CLAUDE.md § 30). Three templates:
///
///   * `'original'`       → "LoadOut Original" with
///                          "Engineered for your scope's subtensions".
///   * `'public_domain'`  → "Public Domain Reticle" with
///                          "Traditional duplex / hash / dot pattern;
///                          not subject to trademark or copyright".
///   * `'published_spec'` → "Calibrated to [Manufacturer] [Reticle Name]"
///                          (substituted from the reticle's
///                          `calibrationProvenance` blob) with
///                          "Subtensions calibrated to the published
///                          manufacturer specification. Not a
///                          reproduction. Verify against your scope's
///                          specification sheet for precision use."
///
/// The "Not a reproduction" framing on `published_spec` rows is legally
/// load-bearing: it telegraphs that LoadOut is shipping interoperability
/// data (a calibrated subtension dictionary on LoadOut-original artwork),
/// not a copy of the manufacturer's trademarked reticle. Horus Vision /
/// HVRT Corp has historically litigated over reticle reproduction; this
/// honest framing is the right posture and the exact wording must NOT
/// be paraphrased — match the user-approved §7.7 spec verbatim.
///
/// Every preview surface in the picker / preview flow renders this
/// caption so users understand the tool is not claiming to be the
/// manufacturer's reticle. The label is intentionally NOT painted by
/// [ReticleRenderer] itself — Range Day live-shooting surfaces
/// (target plot, scope view) embed the renderer and would treat an
/// always-on caption as noise during the aim/fire workflow. Reach for
/// this widget on any new picker / preview surface.
///
/// The caption uses the theme's [TextTheme.bodySmall] colored with
/// [ColorScheme.onSurfaceVariant] so it sits visually under the preview
/// without competing with it. Wrapped in a [Tooltip] carrying the
/// per-origin tagline.
///
/// `align` controls horizontal alignment — defaults to centered so the
/// label looks right under a centered preview (the picker field tile,
/// the full-screen FOV). Pass [TextAlign.start] when the preview is
/// itself left-aligned (e.g. the picker's list rows).
///
/// `inverse` flips the color to a high-contrast white tint for use over
/// dark backdrops (the full-screen preview's black scaffold).
///
/// `subtensionOrigin` and `calibrationProvenance` together select the
/// template. Both are nullable for back-compat: legacy callers that
/// haven't been migrated yet pass nothing and the widget falls back to
/// the historical fixed string ("LoadOut Original — Interoperability
/// Calibration") so existing surfaces never go blank during a partial
/// rollout. New surfaces should always pass the active reticle's
/// `subtensionOrigin`.
class ReticleInteroperabilityLabel extends StatelessWidget {
  const ReticleInteroperabilityLabel({
    super.key,
    this.align = TextAlign.center,
    this.inverse = false,
    this.subtensionOrigin,
    this.calibrationProvenance,
  });

  final TextAlign align;
  final bool inverse;

  /// IP-posture discriminator. Accepts the three documented values
  /// (`'original'`, `'public_domain'`, `'published_spec'`); any other
  /// string falls back to the `'original'` template so we can never
  /// render an empty caption. Null means "legacy call site" — the
  /// widget renders the historical fixed string for back-compat.
  final String? subtensionOrigin;

  /// Internal-only provenance dictionary for `'published_spec'` rows.
  /// Keys: `manufacturer`, `reticle_name`. Either may be absent or
  /// empty; in that case the disclaimer falls back to a generic
  /// "Calibrated to manufacturer specification" without naming.
  final Map<String, dynamic>? calibrationProvenance;

  // Legacy back-compat strings — rendered when no `subtensionOrigin`
  // is provided. Phased out as call sites migrate to the per-origin
  // templates; keep until every consumer of this widget is updated.
  static const String _legacyLabel =
      'LoadOut Original — Interoperability Calibration';
  static const String _legacyTooltip =
      'LoadOut original artwork, calibrated to match real-world scope '
      'subtensions for accuracy. The reticle name and design are '
      'LoadOut-original.';

  // §7.7 per-origin templates. EXACT copy approved by the project lead;
  // do not paraphrase or "polish" these strings.
  static const String _originalLabel = 'LoadOut Original';
  static const String _originalTooltip =
      "Engineered for your scope's subtensions";

  static const String _publicDomainLabel = 'Public Domain Reticle';
  static const String _publicDomainTooltip =
      'Traditional duplex / hash / dot pattern; not subject to '
      'trademark or copyright';

  static const String _publishedSpecGenericLabel =
      'Calibrated to manufacturer specification';
  static const String _publishedSpecTooltip =
      'Subtensions calibrated to the published manufacturer '
      'specification. Not a reproduction. Verify against your '
      "scope's specification sheet for precision use.";

  /// Resolve the visible caption + tooltip for the configured origin.
  /// Returns a (label, tooltip) pair. Public so widget tests can
  /// inspect the resolution without having to render the widget.
  static ({String label, String tooltip}) resolveTemplate({
    required String? subtensionOrigin,
    required Map<String, dynamic>? calibrationProvenance,
  }) {
    if (subtensionOrigin == null) {
      return (label: _legacyLabel, tooltip: _legacyTooltip);
    }
    switch (subtensionOrigin) {
      case 'public_domain':
        return (label: _publicDomainLabel, tooltip: _publicDomainTooltip);
      case 'published_spec':
        // Pull manufacturer + reticle name out of the provenance blob.
        // Treat empty strings as missing — never render a label with a
        // dangling "Calibrated to  " gap.
        String? manufacturer;
        String? reticleName;
        try {
          final m = calibrationProvenance?['manufacturer'];
          if (m is String && m.trim().isNotEmpty) {
            manufacturer = m.trim();
          }
          final n = calibrationProvenance?['reticle_name'];
          if (n is String && n.trim().isNotEmpty) {
            reticleName = n.trim();
          }
        } catch (_) {
          // If the blob is malformed (wrong type, throws on read), fall
          // through to the generic label below.
          manufacturer = null;
          reticleName = null;
        }
        if (manufacturer != null && reticleName != null) {
          return (
            label: 'Calibrated to $manufacturer $reticleName',
            tooltip: _publishedSpecTooltip,
          );
        }
        // Fall back to a generic, name-free label when the provenance
        // is missing or malformed. The tooltip stays the same so the
        // user still sees the legally important "Not a reproduction"
        // framing.
        return (
          label: _publishedSpecGenericLabel,
          tooltip: _publishedSpecTooltip,
        );
      case 'original':
      default:
        return (label: _originalLabel, tooltip: _originalTooltip);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = inverse
        ? Colors.white.withValues(alpha: 0.75)
        : theme.colorScheme.onSurfaceVariant;
    final resolved = resolveTemplate(
      subtensionOrigin: subtensionOrigin,
      calibrationProvenance: calibrationProvenance,
    );
    return Tooltip(
      message: resolved.tooltip,
      child: Text(
        resolved.label,
        textAlign: align,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
