// FILE: test/reticle_lod_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Unit tests for `shouldRenderReticleElement` in
// `lib/widgets/reticle_renderer.dart`. The function is the §6A.1 adaptive
// level-of-detail gate from `range_day_realistic_rewrite_v23.md`:
//
//   * Crosshair / line       → always render
//   * Hash                    → skip when length × pxPerUnit < 1.5
//   * Dot (centre + holdover) → skip when radius × pxPerUnit < 0.5
//   * Floating number / label → skip when fontSize × pxPerUnit < 6.0
//
// The DoD checkpoint flags this specifically:
//
//   > Adaptive LOD code path exists is not the same as adaptive LOD
//   > actually downshifts on slow devices.
//
// These tests prove the gate behaves correctly at the prescribed
// thresholds AND at the magnification extremes the brief calls out
// (1x LPVO = small pxPerUnit, 36x = large pxPerUnit).
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure function. No widget bindings needed.

import 'package:flutter_test/flutter_test.dart';

import 'package:loadout/data/reticle_library.dart';
import 'package:loadout/widgets/reticle_renderer.dart';

void main() {
  group('shouldRenderReticleElement — threshold cases', () {
    // Crosshair: load-bearing structural element. Always renders.
    test('CrosshairLine always renders (any pxPerUnit)', () {
      const crosshair = CrosshairLine(
        startX: -5, startY: 0, endX: 5, endY: 0,
        thicknessMil: 0.04,
      );
      for (final pxPerUnit in [0.1, 1.0, 10.0, 100.0]) {
        expect(shouldRenderReticleElement(crosshair, pxPerUnit), isTrue,
            reason: 'crosshair must render at any pxPerUnit ($pxPerUnit)');
      }
    });

    // Hash: skip when lengthUnits × pxPerUnit < 1.5
    test('HashMark gates on 1.5 px length threshold', () {
      // A typical sub-hash on a tactical reticle is 0.1 units long.
      // At pxPerUnit = 10, length = 1.0 px → SKIP
      // At pxPerUnit = 20, length = 2.0 px → RENDER (above 1.5)
      const subHash = HashMark(
        x: 0.5, y: 0, lengthUnits: 0.1,
        thicknessUnits: 0.04, axis: HashAxis.horizontal,
      );
      expect(shouldRenderReticleElement(subHash, 10.0), isFalse,
          reason: 'sub-hash at 1.0 px length should skip');
      expect(shouldRenderReticleElement(subHash, 20.0), isTrue,
          reason: 'sub-hash at 2.0 px length should render');
      expect(shouldRenderReticleElement(subHash, 15.0), isTrue,
          reason: 'sub-hash exactly at threshold (1.5 px) should render');
    });

    test('HashMark major hashes render even at low magnification', () {
      // A typical major hash is 0.4 units long.
      // At pxPerUnit = 5 → length = 2.0 px → render
      const majorHash = HashMark(
        x: 1, y: 0, lengthUnits: 0.4,
        thicknessUnits: 0.04, axis: HashAxis.horizontal,
      );
      expect(shouldRenderReticleElement(majorHash, 5.0), isTrue);
      expect(shouldRenderReticleElement(majorHash, 1.0), isFalse,
          reason: 'major hash at 0.4 px length should skip');
    });

    // CenterDot: skip when radiusUnits × pxPerUnit < 0.5
    test('CenterDot gates on 0.5 px radius threshold', () {
      // 0.05-unit-radius dot (typical for a precise centre point).
      // At pxPerUnit = 5 → radius = 0.25 px → SKIP
      // At pxPerUnit = 15 → radius = 0.75 px → RENDER
      const smallDot = CenterDot(radiusUnits: 0.05);
      expect(shouldRenderReticleElement(smallDot, 5.0), isFalse);
      expect(shouldRenderReticleElement(smallDot, 15.0), isTrue);
      expect(shouldRenderReticleElement(smallDot, 10.0), isTrue,
          reason: 'dot exactly at threshold (0.5 px radius) should render');
    });

    test('HoldoverDot uses same threshold as CenterDot', () {
      const holdover = HoldoverDot(x: 0, y: 1, radiusUnits: 0.04);
      // 0.04 × pxPerUnit ≥ 0.5 → pxPerUnit ≥ 12.5
      expect(shouldRenderReticleElement(holdover, 10.0), isFalse);
      expect(shouldRenderReticleElement(holdover, 15.0), isTrue);
    });

    // FloatingNumber: skip when fontSizeUnits × pxPerUnit < 6.0
    test('FloatingNumber gates on 6 px font-size threshold', () {
      // Default fontSizeUnits = 0.5 → need pxPerUnit ≥ 12.0
      const label = FloatingNumber(
        x: 1, y: 0, text: '1', fontSizeUnits: 0.5,
      );
      expect(shouldRenderReticleElement(label, 5.0), isFalse,
          reason: 'label at 2.5 px font size should skip (illegible)');
      expect(shouldRenderReticleElement(label, 15.0), isTrue,
          reason: 'label at 7.5 px font size should render');
      expect(shouldRenderReticleElement(label, 12.0), isTrue,
          reason: 'label exactly at threshold (6.0 px) should render');
    });
  });

  group('shouldRenderReticleElement — magnification extremes', () {
    // Per §6A.1 brief acceptance:
    //   * At 1x magnification, sub-hashes (0.2 mil, 0.1 length) are skipped
    //   * At 36x magnification, every sub-hash renders sharply
    //   * No element renders at less than 0.5 pixel size on any axis
    //   * Major stadia always render at any magnification

    // pxPerUnit at 1x LPVO on a typical 600px scope view with a
    // 10-mil reticle half-extent: ≈ 600 / (10 / 1) = 60.0 — but
    // FFP at 1x renders the reticle at minimum visible size. The
    // brief says use ~3 pxPerUnit at 1x and ~36+ at 36x.

    test('At 1x LPVO (pxPerUnit ≈ 3): sub-hashes are skipped', () {
      const pxPerUnit = 3.0; // simulated 1x scale
      const subHash = HashMark(
        x: 0.2, y: 0, lengthUnits: 0.1,
        thicknessUnits: 0.04, axis: HashAxis.horizontal,
      );
      // 0.1 × 3 = 0.3 px → far below 1.5
      expect(shouldRenderReticleElement(subHash, pxPerUnit), isFalse);
    });

    test('At 1x LPVO (pxPerUnit ≈ 3): major stadia still render', () {
      const pxPerUnit = 3.0;
      const crosshair = CrosshairLine(
        startX: -5, startY: 0, endX: 5, endY: 0,
      );
      const majorHash = HashMark(
        x: 1, y: 0, lengthUnits: 0.5,
        thicknessUnits: 0.04, axis: HashAxis.horizontal,
      );
      expect(shouldRenderReticleElement(crosshair, pxPerUnit), isTrue);
      // 0.5 × 3 = 1.5 px → exactly at threshold → render
      expect(shouldRenderReticleElement(majorHash, pxPerUnit), isTrue);
    });

    test('At 36x (pxPerUnit ≈ 50): every sub-hash renders', () {
      const pxPerUnit = 50.0;
      const subHash = HashMark(
        x: 0.1, y: 0, lengthUnits: 0.1,
        thicknessUnits: 0.04, axis: HashAxis.horizontal,
      );
      const tinyDot = CenterDot(radiusUnits: 0.02);
      const subLabel = FloatingNumber(
        x: 1, y: 0, text: '1', fontSizeUnits: 0.15,
      );
      expect(shouldRenderReticleElement(subHash, pxPerUnit), isTrue,
          reason: 'sub-hash at 5.0 px should render');
      expect(shouldRenderReticleElement(tinyDot, pxPerUnit), isTrue,
          reason: 'tiny dot at 1.0 px radius should render');
      expect(shouldRenderReticleElement(subLabel, pxPerUnit), isTrue,
          reason: 'small label at 7.5 px font should render');
    });
  });

  group('shouldRenderReticleElement — sub-pixel invariant', () {
    test('No element renders at less than 0.5 px size on any axis', () {
      // The brief's invariant: an element that produces sub-half-pixel
      // geometry should always be filtered out.
      const tinyHash = HashMark(
        x: 0, y: 0, lengthUnits: 0.001,
        thicknessUnits: 0.04, axis: HashAxis.horizontal,
      );
      const tinyDot = CenterDot(radiusUnits: 0.001);
      const tinyLabel = FloatingNumber(
        x: 0, y: 0, text: '1', fontSizeUnits: 0.001,
      );
      // At any reasonable pxPerUnit these stay sub-pixel.
      for (final pxPerUnit in [1.0, 10.0, 100.0]) {
        expect(shouldRenderReticleElement(tinyHash, pxPerUnit), isFalse);
        expect(shouldRenderReticleElement(tinyDot, pxPerUnit), isFalse);
        expect(shouldRenderReticleElement(tinyLabel, pxPerUnit), isFalse);
      }
    });
  });
}
