// FILE: test/projectile_pejsa_form_factor_test.dart
//
// Regression tests for the new Litz-aware projectile getters:
//   * `Projectile.pejsaStability(...)` — Pejsa Sg with the same
//     velocity correction as Miller, expected within ~5–10% of
//     Miller for typical match bullets.
//   * `Projectile.formFactorI7` — G7 form factor i7 = SD / BC_G7.
//
// Test fixtures:
//   * 6.5 mm 140 gr Hornady ELD-Match, 1:8 twist, MV 2710 fps. The
//     canonical "standard recipe" used elsewhere in the project's
//     ballistics tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/services/ballistics/drag_functions.dart';
import 'package:loadout/services/ballistics/projectile.dart';

void main() {
  group('Pejsa stability', () {
    test('6.5 CM 140 ELD-M with 1:8 twist at 2710 fps produces a stable Sg',
        () {
      final p = Projectile(
        diameterIn: 0.264,
        weightGr: 140,
        bc: 0.298,
        dragModel: DragModel.g7,
        lengthIn: 1.355,
        twistInches: 8,
      );
      final pejsa = p.pejsaStability(2710);
      expect(pejsa, isNotNull);
      // Expected ~1.7–1.85 — same order of magnitude as Miller (1.75
      // for this load) and well above the 1.4 marginal-stability
      // threshold.
      expect(pejsa!, greaterThan(1.4));
      expect(pejsa, lessThan(2.1));
    });

    test('Pejsa and Miller agree to within 10% for the 6.5 CM 140 ELD-M',
        () {
      final p = Projectile(
        diameterIn: 0.264,
        weightGr: 140,
        bc: 0.298,
        dragModel: DragModel.g7,
        lengthIn: 1.355,
        twistInches: 8,
      );
      final miller = p.millerStability(2710);
      final pejsa = p.pejsaStability(2710);
      expect(miller, isNotNull);
      expect(pejsa, isNotNull);
      final diff = (miller! - pejsa!).abs() / miller;
      expect(diff, lessThan(0.10),
          reason:
              'Pejsa ($pejsa) and Miller ($miller) should agree within 10% '
              'for typical match bullets — got ${(diff * 100).toStringAsFixed(2)}%.');
    });

    test('Pejsa returns null when length or twist is missing', () {
      final noLength = Projectile(
        diameterIn: 0.264,
        weightGr: 140,
        bc: 0.298,
        dragModel: DragModel.g7,
        twistInches: 8,
      );
      expect(noLength.pejsaStability(2710), isNull);

      final noTwist = Projectile(
        diameterIn: 0.264,
        weightGr: 140,
        bc: 0.298,
        dragModel: DragModel.g7,
        lengthIn: 1.355,
      );
      expect(noTwist.pejsaStability(2710), isNull);
    });

    test('Pejsa returns null on degenerate inputs (zero twist)', () {
      final p = Projectile(
        diameterIn: 0.264,
        weightGr: 140,
        bc: 0.298,
        dragModel: DragModel.g7,
        lengthIn: 1.355,
        twistInches: 0,
      );
      expect(p.pejsaStability(2710), isNull);
    });

    test('Pejsa scales with muzzle velocity via the same correction as Miller',
        () {
      final p = Projectile(
        diameterIn: 0.264,
        weightGr: 140,
        bc: 0.298,
        dragModel: DragModel.g7,
        lengthIn: 1.355,
        twistInches: 8,
      );
      final atRefMv = p.pejsaStability(2800)!;
      final atSlower = p.pejsaStability(2400)!;
      // Faster MV → higher spin rate → higher Sg.
      expect(atRefMv, greaterThan(atSlower));
    });
  });

  group('Form factor i7', () {
    test('6.5 CM 140 gr ELD-M with G7 BC 0.326 → i7 ≈ 0.881', () {
      final p = Projectile(
        diameterIn: 0.264,
        weightGr: 140,
        bc: 0.326,
        dragModel: DragModel.g7,
      );
      // SD = 140/7000 / 0.264² ≈ 0.287
      // i7 = 0.287 / 0.326 ≈ 0.881
      expect(p.formFactorI7, closeTo(0.881, 0.005));
    });

    test('i7 returns NaN when the projectile uses a G1 BC, not G7', () {
      final p = Projectile(
        diameterIn: 0.308,
        weightGr: 175,
        bc: 0.475,
        dragModel: DragModel.g1,
      );
      expect(p.formFactorI7.isNaN, isTrue,
          reason:
              'i7 is defined against the G7 reference; computing it from a '
              'G1 BC would silently produce a wrong number, so we return NaN.');
    });

    test('i7 returns NaN when weight or diameter is zero or negative', () {
      final zeroWeight = Projectile(
        diameterIn: 0.264,
        weightGr: 0,
        bc: 0.326,
        dragModel: DragModel.g7,
      );
      expect(zeroWeight.formFactorI7.isNaN, isTrue);

      final zeroDiameter = Projectile(
        diameterIn: 0,
        weightGr: 140,
        bc: 0.326,
        dragModel: DragModel.g7,
      );
      expect(zeroDiameter.formFactorI7.isNaN, isTrue);
    });

    test('i7 below 1.0 marks an efficient bullet (less drag than G7 reference)',
        () {
      final efficient = Projectile(
        diameterIn: 0.264,
        weightGr: 140,
        bc: 0.326,
        dragModel: DragModel.g7,
      );
      expect(efficient.formFactorI7, lessThan(1.0));
    });

    test('i7 above 1.0 marks a less-efficient bullet (more drag than G7)', () {
      // Hypothetical: short 30 cal hunting bullet with low G7 BC.
      final inefficient = Projectile(
        diameterIn: 0.308,
        weightGr: 150,
        bc: 0.180,
        dragModel: DragModel.g7,
      );
      // SD = 150/7000 / 0.308² ≈ 0.226, i7 = 0.226 / 0.180 ≈ 1.255
      expect(inefficient.formFactorI7, greaterThan(1.0));
      expect(inefficient.formFactorI7, closeTo(1.255, 0.01));
    });
  });
}
