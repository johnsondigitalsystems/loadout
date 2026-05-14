// FILE: test/scene_composition_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Regression tests for the Range Day Realistic scene-composition layout
// in `lib/screens/range_day/widgets/target_plot.dart`. Specifically
// `RealisticLayout.compute(...)` — the value-type factory that maps a
// canvas size + target inches → pixel rectangles for the active target,
// the post (single-target mode), and the rack cross-bar / child rects
// (rack mode).
//
// The brief's §6.2.1 prescribes the load-bearing band coefficients:
//
//   Sky region   : 0      → 0.78 H
//   Grass region : 0.78 H → H
//   Target       : 0.12 H → 0.55 H (varies by aspect)
//   Post         : target_bottom → 0.85 H, width 0.025 W
//   Mound        : 0.82 H → 0.92 H, width 0.18 W
//
// These tests fix those numbers so a future "clean-up" pass that
// nudges the horizon back to 0.62 (the legacy reticle-picker
// preference) trips the suite and surfaces the violation immediately.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// `RealisticLayout` is the single source of truth for where every
// realistic-mode scene element sits inside the scope view. The
// backdrop painter, the post painter, the cross-bar / chains
// painter, and the active-target painter all read from one
// `RealisticLayout` instance — drift between them is the kind of
// bug that produced the original head-clipping IPSC defect
// (D-010). Covering the layout math directly lets us assert the
// invariants without spinning up a full widget paint.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure value-type construction.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loadout/screens/range_day/widgets/target_plot.dart';

void main() {
  group('RealisticLayout.compute — single target band coefficients', () {
    test('post bottom sits at 0.85 H (planted in the foreground berm)', () {
      // Canonical 600 × 800 canvas (3:4 portrait scope view).
      final layout = RealisticLayout.compute(
        outerSize: const Size(600, 800),
        targetWidthIn: 18.0,
        targetHeightIn: 30.0, // IPSC USPSA full-size
        rackChildren: null,
        activeRackChildIndex: null,
      );
      // Mound spans 0.82–0.92 H; post bottom 0.85 H is inside the
      // mound (the bottom 0.03 H of the post is hidden behind the
      // berm).
      expect(layout.poleBottom, closeTo(800 * 0.85, 0.5),
          reason: 'post bottom should sit at 0.85 H per §6.2.1');
    });

    test('target bottom sits at 0.55 H (above the mound)', () {
      final layout = RealisticLayout.compute(
        outerSize: const Size(600, 800),
        targetWidthIn: 18.0,
        targetHeightIn: 30.0,
        rackChildren: null,
        activeRackChildIndex: null,
      );
      expect(layout.activeChildRect.bottom, closeTo(800 * 0.55, 0.5),
          reason: 'target bottom should sit at 0.55 H per §6.2.1');
    });

    test('post extends from target_bottom to post_bottom', () {
      final layout = RealisticLayout.compute(
        outerSize: const Size(600, 800),
        targetWidthIn: 18.0,
        targetHeightIn: 30.0,
        rackChildren: null,
        activeRackChildIndex: null,
      );
      expect(layout.poleTop, closeTo(layout.activeChildRect.bottom, 0.5),
          reason: 'post top should meet target bottom');
      expect(layout.poleBottom - layout.poleTop, greaterThan(0),
          reason: 'post must have positive height');
    });

    test('post centred on canvas (single-target mode)', () {
      final layout = RealisticLayout.compute(
        outerSize: const Size(600, 800),
        targetWidthIn: 18.0,
        targetHeightIn: 30.0,
        rackChildren: null,
        activeRackChildIndex: null,
      );
      expect(layout.poleX, closeTo(300, 0.5),
          reason: 'post should be centred horizontally on the canvas');
    });

    test('target horizontally centred on canvas', () {
      final layout = RealisticLayout.compute(
        outerSize: const Size(600, 800),
        targetWidthIn: 18.0,
        targetHeightIn: 30.0,
        rackChildren: null,
        activeRackChildIndex: null,
      );
      expect(layout.activeChildRect.center.dx, closeTo(300, 0.5),
          reason: 'target should be horizontally centred above the post');
    });
  });

  group('RealisticLayout.compute — headroom invariant', () {
    test('target top stays ≥ 0.12 H for very-tall targets', () {
      // A pathological 1:100 aspect target (extremely tall). Without
      // the headroom cap, target height would push target_top to
      // negative Y. The headroom cap scales the target down so
      // target_top stays at or below the 0.12 H ceiling.
      final layout = RealisticLayout.compute(
        outerSize: const Size(600, 800),
        targetWidthIn: 1.0,
        targetHeightIn: 100.0,
        rackChildren: null,
        activeRackChildIndex: null,
      );
      // 0.12 * 800 = 96. Allow 1 px epsilon for floating-point cap.
      expect(layout.activeChildRect.top, greaterThanOrEqualTo(96 - 1.0),
          reason: 'target top must stay at or below 0.12 H ceiling');
    });

    test('headroom cap preserves aspect ratio', () {
      // Same 1:100 aspect — the cap scales BOTH width and height
      // proportionally, never just one.
      const widthIn = 1.0;
      const heightIn = 100.0;
      final layout = RealisticLayout.compute(
        outerSize: const Size(600, 800),
        targetWidthIn: widthIn,
        targetHeightIn: heightIn,
        rackChildren: null,
        activeRackChildIndex: null,
      );
      final renderedAspect =
          layout.activeChildRect.width / layout.activeChildRect.height;
      const naturalAspect = widthIn / heightIn;
      expect(renderedAspect, closeTo(naturalAspect, 0.001),
          reason: 'headroom cap must preserve aspect (no squash)');
    });

    test('short target sits unconstrained at 0.55 H bottom', () {
      // A very short / wide target (12:4 = 3.0 aspect). target_height
      // is small, so the headroom cap is a no-op and target_bottom
      // sits at exactly 0.55 H.
      final layout = RealisticLayout.compute(
        outerSize: const Size(600, 800),
        targetWidthIn: 12.0,
        targetHeightIn: 4.0,
        rackChildren: null,
        activeRackChildIndex: null,
      );
      expect(layout.activeChildRect.bottom, closeTo(800 * 0.55, 0.5),
          reason: 'short target should sit at 0.55 H bottom');
      expect(layout.activeChildRect.top, greaterThan(800 * 0.12),
          reason: 'short target has plenty of headroom');
    });
  });

  group('RealisticLayout.compute — scope ring geometry', () {
    test('scope ring fills 88% of the shorter dimension', () {
      // Square 600 × 600 — short side is 600, radius should be 0.44 ×
      // 600 = 264.
      final layout = RealisticLayout.compute(
        outerSize: const Size(600, 600),
        targetWidthIn: 18.0,
        targetHeightIn: 30.0,
        rackChildren: null,
        activeRackChildIndex: null,
      );
      expect(layout.scopeRadius, closeTo(600 * 0.44, 0.5));
      // Centred.
      expect(layout.scopeCenter.dx, closeTo(300, 0.5));
      expect(layout.scopeCenter.dy, closeTo(300, 0.5));
    });

    test('portrait canvas: ring radius governed by shorter (width)', () {
      // 400 × 800 portrait. Shorter side is width = 400; radius =
      // 0.44 × 400 = 176.
      final layout = RealisticLayout.compute(
        outerSize: const Size(400, 800),
        targetWidthIn: 18.0,
        targetHeightIn: 30.0,
        rackChildren: null,
        activeRackChildIndex: null,
      );
      expect(layout.scopeRadius, closeTo(400 * 0.44, 0.5));
    });
  });

  group('RealisticLayout.compute — degenerate inputs soft-fail', () {
    test('zero-width canvas still returns a usable layout', () {
      // Edge case: canvas hasn't been measured yet (size 0×0).
      // `compute` clamps each axis to ≥ 1 px so it never divides by
      // zero or returns NaN.
      final layout = RealisticLayout.compute(
        outerSize: const Size(0, 0),
        targetWidthIn: 18.0,
        targetHeightIn: 30.0,
        rackChildren: null,
        activeRackChildIndex: null,
      );
      expect(layout.scopeRadius, greaterThan(0),
          reason: 'scope radius must be positive');
      expect(layout.activeChildRect.width.isFinite, isTrue);
      expect(layout.activeChildRect.height.isFinite, isTrue);
      expect(layout.poleBottom.isFinite, isTrue);
    });

    test('zero target dimensions clamp to 1 inch each', () {
      // Caller passed 0×0 inches — compute clamps both to 1.0 so
      // the target still has positive pixel size.
      final layout = RealisticLayout.compute(
        outerSize: const Size(600, 800),
        targetWidthIn: 0.0,
        targetHeightIn: 0.0,
        rackChildren: null,
        activeRackChildIndex: null,
      );
      expect(layout.activeChildRect.width, greaterThan(0));
      expect(layout.activeChildRect.height, greaterThan(0));
    });
  });

  group('RealisticLayout.compute — rack mode geometry', () {
    test('cross-bar Y at 0.20 H', () {
      final layout = RealisticLayout.compute(
        outerSize: const Size(600, 800),
        targetWidthIn: 6.0,
        targetHeightIn: 6.0,
        rackChildren: [
          const RackChildSpec(
            widthIn: 6.0,
            heightIn: 6.0,
            category: 'circle',
            offsetXFromCenterIn: -12,
          ),
          const RackChildSpec(
            widthIn: 6.0,
            heightIn: 6.0,
            category: 'circle',
            offsetXFromCenterIn: 0,
          ),
          const RackChildSpec(
            widthIn: 6.0,
            heightIn: 6.0,
            category: 'circle',
            offsetXFromCenterIn: 12,
          ),
        ],
        activeRackChildIndex: 1,
      );
      expect(layout.isRack, isTrue);
      expect(layout.crossBarY, closeTo(800 * 0.20, 0.5));
      expect(layout.childRects.length, 3);
      expect(layout.activeChildIndex, 1);
    });

    test('rack children fit within ~70% of canvas width', () {
      // 5-target rack with 4-inch spacing — total span 20 inches.
      // pxPerInch should size the rack to ~70% of the 600 px canvas
      // (420 px), so pxPerInch ≈ 21.
      final layout = RealisticLayout.compute(
        outerSize: const Size(600, 800),
        targetWidthIn: 4.0,
        targetHeightIn: 4.0,
        rackChildren: [
          for (var i = -2; i <= 2; i++)
            RackChildSpec(
              widthIn: 4.0,
              heightIn: 4.0,
              category: 'circle',
              offsetXFromCenterIn: i * 4.0,
            ),
        ],
        activeRackChildIndex: 2,
      );
      double leftMost = double.infinity;
      double rightMost = double.negativeInfinity;
      for (final r in layout.childRects) {
        if (r.left < leftMost) leftMost = r.left;
        if (r.right > rightMost) rightMost = r.right;
      }
      final renderedRackWidth = rightMost - leftMost;
      expect(renderedRackWidth, lessThanOrEqualTo(600 * 0.70 + 1.0),
          reason: 'rack should fit within ~70 % of canvas width');
      expect(renderedRackWidth, greaterThan(600 * 0.30),
          reason: 'rack should not be over-shrunk');
    });
  });
}
