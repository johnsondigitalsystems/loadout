// FILE: lib/widgets/reticle_full_screen_view.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Full-screen reticle preview modal. Shows a single [ReticleDefinition]
// inside a circular eyepiece-style FOV, rendered on top of the
// procedural daytime range backdrop ([ScopeDaytimeBackdrop]) so the
// user can see how the reticle would actually look against a target
// during a daylight range session.
//
// Public API:
//
// ```dart
// showReticleFullScreenPreview(
//   context,
//   reticle: someReticleDefinition,
//   reticleLabel: 'Vortex EBR-7C MRAD',
// );
// ```
//
// Tap anywhere to dismiss. Single-purpose: pretty preview, no edit /
// pick / save behavior. The picker invokes this from a dedicated
// "Preview" trailing icon on each row to keep visual clutter out of
// the dropdown list itself.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The picker dropdown shows tiny 40 px thumbnails — small enough to
// scan but too small to evaluate a reticle's tree-style holdovers,
// floating numbers, or hash spacing. The user needs a "show me this
// at full size before I commit" gesture. Putting the full-size
// preview behind a dedicated trailing icon (instead of expanding the
// list-row thumbnail) keeps the row scannable AND lets users actually
// inspect the reticle when they want to.
//
// This is intentionally NOT the Pro `ScopeViewScreen` (which is a far
// more complex Pro-gated tool — magnification slider, range slider,
// click-count math, animated mover, hit-prob badge). The full-screen
// preview is free, single-frame, no controls. It exists so the picker
// flow doesn't need a Pro upsell to evaluate a reticle.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * The reticle's color must contrast both the bright sky AND the
//     darker grass / mound. Pure black wins against the sky but
//     disappears in the mound's shadow; pure white wins against the
//     grass but blows out against the haze. We use a high-contrast
//     dark-with-thin-white-stroke compromise so the reticle reads on
//     every part of the backdrop without any compositing tricks.
//   * Center the FOV both vertically and horizontally regardless of
//     SafeArea inset; the modal is shown via `showDialog` so the
//     `Center` + `LayoutBuilder` pattern keeps it stable across
//     keyboard / notch / dynamic-island geometry.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `lib/widgets/reticle_picker.dart` — the picker's full-screen
//   "Preview" trailing icon launches this via
//   [showReticleFullScreenPreview].
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure UI. Pops itself when the user taps to dismiss.

import 'package:flutter/material.dart';

import '../data/reticle_library.dart';
import 'reticle_renderer.dart';
import 'scope_daytime_backdrop.dart';

// `ReticleInteroperabilityLabel` lives in `reticle_renderer.dart`; the
// import above brings it into scope here.

/// Open the full-screen reticle preview modal. Returns when the user
/// dismisses it (no result — the preview is read-only).
Future<void> showReticleFullScreenPreview(
  BuildContext context, {
  required ReticleDefinition reticle,
  required String reticleLabel,
  BackdropTargetSilhouette target = BackdropTargetSilhouette.ipsc,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black87,
    builder: (ctx) => _ReticleFullScreenView(
      reticle: reticle,
      reticleLabel: reticleLabel,
      target: target,
    ),
  );
}

class _ReticleFullScreenView extends StatelessWidget {
  const _ReticleFullScreenView({
    required this.reticle,
    required this.reticleLabel,
    required this.target,
  });

  final ReticleDefinition reticle;
  final String reticleLabel;
  final BackdropTargetSilhouette target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Full-screen tap-to-dismiss layer behind everything.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: Container(color: Colors.black),
              ),
            ),
            // Top label.
            Positioned(
              left: 0,
              right: 0,
              top: 16,
              child: Text(
                reticleLabel,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Centered FOV — fits the smaller of width / height.
            // The interoperability caption sits directly underneath
            // the FOV inside a Column so it follows the preview as
            // it scales with screen size, rather than floating at a
            // fixed bottom offset where it could overlap the dismiss
            // hint on short screens. CLAUDE.md § 30 liability
            // checklist requires the caption on every preview
            // surface; the inverse color flag swaps the muted
            // onSurfaceVariant tint for a high-contrast white tint
            // so the label reads on the modal's black scaffold.
            Center(
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final maxSide = constraints.biggest.shortestSide;
                  final fovSide = maxSide * 0.85;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: fovSide,
                        height: fovSide,
                        child: ClipOval(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ScopeDaytimeBackdrop(
                                target: target,
                                // Larger target than the default 16% so the
                                // preview emphasizes "how the reticle sits on
                                // a target" rather than the scenery.
                                targetWidthFraction: 0.22,
                              ),
                              // Reticle rendered on top of the backdrop.
                              // Use a dark line color (brand-safe black with
                              // a thin highlight) so it reads on both sky
                              // and grass.
                              Center(
                                child: ReticleRenderer(
                                  reticle: reticle,
                                  displayUnit:
                                      reticle.nativeUnit == ReticleNativeUnit.moa
                                          ? 'moa'
                                          : 'mil',
                                  size: Size(fovSide, fovSide),
                                  showUnitOverlay: false,
                                  color: const Color(0xff111111),
                                ),
                              ),
                              // Eyepiece ring + soft black bezel so the
                              // backdrop doesn't bleed past the FOV edge.
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _EyepieceRingPainter(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Interoperability caption — directly under the
                      // FOV per CLAUDE.md § 30. Width-bounded to the
                      // preview so it wraps cleanly on narrow phones
                      // rather than running edge-to-edge.
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: fovSide),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: ReticleInteroperabilityLabel(
                            align: TextAlign.center,
                            inverse: true,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // Tap-to-dismiss hint at the bottom.
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Text(
                'Tap anywhere to dismiss',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin inner ring around the FOV edge so the preview reads as a
/// scope eyepiece, not just a circular crop.
class _EyepieceRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final radius = size.shortestSide / 2 - 2;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _EyepieceRingPainter old) => false;
}
