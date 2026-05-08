// FILE: test/drag_functions_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Coverage tests for `lib/services/ballistics/drag_functions.dart` and the
// adjacent `custom_drag.dart`. The existing test suites
// (`ballistics_test.dart`, `precision_test.dart`,
// `hornady_4dof_curve_test.dart`) check a handful of G1 / G7 muzzle Cd
// values plus some deep monotonicity properties; this file fills the
// remainder:
//
//   * Cd lookup against published Sierra / McCoy / Litz reference values
//     at Mach 1.0, 1.5, 2.0, 3.0 for the two most-used tables (G1 / G7);
//   * non-negative Cd across the full supported Mach range;
//   * out-of-range clamping behaviour (Mach < 0 and Mach > 5);
//   * `tabulatedRange` extents for every drag family;
//   * `dragRetardation` clamping at negative Mach;
//   * custom-curve parsing and PCHIP interpolation between samples;
//   * edge cases: empty curve, single-point curve, duplicate-Mach entries.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Drag retrieval is the inner loop of the solver: every RK45 substep
// reads from one of these tables. A regression here would shift every
// trajectory in the app silently, with the bias dependent on the bullet
// velocity profile — hard to debug from an end-to-end mismatch test.
// Pinning the math at known reference values means a future refactor of
// the PCHIP interpolation, of the table data, or of the clamping rule
// breaks here with a clear failure message.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * The G-tables ship with high-precision sample values that match
//     McCoy / Sierra publications. Tests use the SAMPLES at exact Mach
//     values where the table has explicit entries — no interpolation
//     uncertainty. This means a precision regression at e.g. Mach 1.5
//     in the table data shows up here, while interpolation regressions
//     in between samples land in `precision_test.dart`'s monotonicity
//     check.
//
//   * `dragCoefficient` clamps at the table edges. Some shooting calculators
//     return NaN past the table; ours clamps. We pin the clamping
//     behaviour explicitly so a future "throw on overflow" change is
//     a visible API change, not a silent surprise.
//
//   * `CustomDragCurve.fromPoints` rejects negative or non-finite Cd
//     values. The tests exercise this so a future "be lenient" change
//     trips an explicit assertion failure.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   - `flutter test` suite.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/services/ballistics/custom_drag.dart';
import 'package:loadout/services/ballistics/drag_functions.dart';

void main() {
  group('G1 drag table — published reference samples', () {
    // Reference values are the McCoy "Modern Exterior Ballistics"
    // table 8.1 entries, identical to the Sierra reloading manual /
    // AccurateShooter standard table. We sample at exact table-row
    // Mach numbers so PCHIP interpolation reproduces the table value
    // to a tight tolerance.
    test('Mach 1.0 → Cd ≈ 0.4805', () {
      expect(dragCoefficient(DragModel.g1, 1.0), closeTo(0.4805, 1e-3));
    });

    test('Mach 1.5 → Cd ≈ 0.6573 (post-peak descent)', () {
      expect(dragCoefficient(DragModel.g1, 1.5), closeTo(0.6573, 1e-3));
    });

    test('Mach 2.0 → Cd ≈ 0.5934', () {
      expect(dragCoefficient(DragModel.g1, 2.0), closeTo(0.5934, 1e-3));
    });

    test('Mach 3.0 → Cd ≈ 0.5133', () {
      expect(dragCoefficient(DragModel.g1, 3.0), closeTo(0.5133, 1e-3));
    });

    test('Cd peaks near Mach 1.4 (transonic)', () {
      // The G1 standard projectile peaks at Mach 1.4 with Cd ≈ 0.6625.
      final peak = dragCoefficient(DragModel.g1, 1.4);
      final preTransonic = dragCoefficient(DragModel.g1, 0.5);
      // Peak is more than 3× the subsonic plateau.
      expect(peak / preTransonic, greaterThan(3.0));
      expect(peak, closeTo(0.6625, 1e-3));
    });
  });

  group('G7 drag table — published reference samples', () {
    // Reference: McCoy table 8.7 / Litz "Applied Ballistics" appendix.
    test('Mach 1.0 → Cd ≈ 0.3803', () {
      expect(dragCoefficient(DragModel.g7, 1.0), closeTo(0.3803, 1e-3));
    });

    test('Mach 1.5 → Cd ≈ 0.3440', () {
      expect(dragCoefficient(DragModel.g7, 1.5), closeTo(0.3440, 1e-3));
    });

    test('Mach 2.0 → Cd ≈ 0.2980', () {
      expect(dragCoefficient(DragModel.g7, 2.0), closeTo(0.2980, 1e-3));
    });

    test('Mach 3.0 → Cd ≈ 0.2424', () {
      expect(dragCoefficient(DragModel.g7, 3.0), closeTo(0.2424, 1e-3));
    });
  });

  group('Drag tables — non-negativity and tabulated extent', () {
    test('Cd is non-negative across the supported Mach range for every model',
        () {
      // 100 sample points from Mach 0 to Mach 5; never negative for any
      // family. (A bug that read past a table's last sample and produced
      // a negative wrapped value would land here.)
      for (final model in DragModel.values) {
        for (var i = 0; i <= 100; i++) {
          final mach = i * 0.05; // 0.0 .. 5.0
          final cd = dragCoefficient(model, mach);
          expect(cd.isFinite, isTrue,
              reason: 'Cd is finite at Mach $mach for $model');
          expect(cd, greaterThanOrEqualTo(0.0),
              reason: 'Cd >= 0 at Mach $mach for $model');
        }
      }
    });

    test('tabulatedRange spans Mach 0 → Mach 5 for every model', () {
      for (final model in DragModel.values) {
        final r = tabulatedRange(model);
        expect(r.low, closeTo(0.0, 1e-9),
            reason: 'low extent for $model');
        expect(r.high, closeTo(5.0, 1e-9),
            reason: 'high extent for $model');
      }
    });
  });

  group('Drag tables — out-of-range clamping', () {
    test('Mach < 0 returns the Mach=0 value (clamps low)', () {
      // The integrator should never feed a negative Mach (speed is
      // sqrt-of-squares), but the lookup must not blow up if it does.
      final atZero = dragCoefficient(DragModel.g1, 0.0);
      final atNeg = dragCoefficient(DragModel.g1, -0.5);
      expect(atNeg, equals(atZero));
    });

    test('Mach > 5 clamps to the Mach=5 value (no extrapolation)', () {
      final atFive = dragCoefficient(DragModel.g1, 5.0);
      final atTen = dragCoefficient(DragModel.g1, 10.0);
      expect(atTen, equals(atFive));
    });

    test('dragRetardation clamps Mach < 0 to Mach 0', () {
      // dragRetardation explicitly takes max(0, mach) before lookup;
      // verify the clamp is intact.
      final atZero = dragRetardation(model: DragModel.g7, mach: 0.0);
      final atNeg =
          dragRetardation(model: DragModel.g7, mach: -3.0);
      expect(atNeg, equals(atZero));
    });
  });

  group('Custom drag curve — interpolation', () {
    test('two-point curve interpolates linearly between samples', () {
      // PCHIP between two samples degenerates to a linear segment
      // (the cubic basis is exact on a straight line). Verify the
      // mid-point reads as the average.
      final curve = CustomDragCurve.fromPoints(
        id: 'two_point',
        displayName: 'two_point',
        points: const [
          MachCd(mach: 1.0, cd: 0.30),
          MachCd(mach: 2.0, cd: 0.20),
        ],
      );
      expect(curve.dragCoefficient(1.0), closeTo(0.30, 1e-9));
      expect(curve.dragCoefficient(2.0), closeTo(0.20, 1e-9));
      // Midpoint should be the average of the two sample values
      // because the PCHIP cubic with end slopes set to the centre
      // secant collapses to linear on a 2-sample table.
      expect(curve.dragCoefficient(1.5), closeTo(0.25, 1e-9));
    });

    test('multi-point curve clamps below first and above last sample', () {
      // Custom curves clamp at table extents — same convention as the
      // built-in G-tables.
      final curve = CustomDragCurve.fromPoints(
        id: 'tri_point',
        displayName: 'tri_point',
        points: const [
          MachCd(mach: 0.5, cd: 0.40),
          MachCd(mach: 1.0, cd: 0.50),
          MachCd(mach: 2.0, cd: 0.30),
        ],
      );
      // Below first sample → clamp to first.
      expect(curve.dragCoefficient(0.0), closeTo(0.40, 1e-9));
      // Above last sample → clamp to last.
      expect(curve.dragCoefficient(5.0), closeTo(0.30, 1e-9));
    });

    test('out-of-order input is sorted by Mach during construction', () {
      // The factory must defensively sort, so a JSON input that ships
      // unsorted does not break the binary search.
      final curve = CustomDragCurve.fromPoints(
        id: 'unsorted',
        displayName: 'unsorted',
        points: const [
          MachCd(mach: 2.0, cd: 0.20),
          MachCd(mach: 0.5, cd: 0.40),
          MachCd(mach: 1.0, cd: 0.30),
        ],
      );
      final r = curve.tabulatedRange();
      expect(r.low, closeTo(0.5, 1e-9));
      expect(r.high, closeTo(2.0, 1e-9));
      // Sample at the middle entry should still match its raw value.
      expect(curve.dragCoefficient(1.0), closeTo(0.30, 1e-9));
    });
  });

  group('Custom drag curve — edge cases', () {
    test('empty point list constructs but always returns Cd=0', () {
      // The current implementation accepts an empty list (the iteration
      // skips because there's nothing to validate) and returns 0 from
      // every lookup — solver guards against zero-density-like states
      // via the 100 fps subsonic-stop rule.
      final curve = CustomDragCurve.fromPoints(
        id: 'empty',
        displayName: 'empty',
        points: const [],
      );
      expect(curve.dragCoefficient(0.0), 0.0);
      expect(curve.dragCoefficient(1.0), 0.0);
      expect(curve.dragCoefficient(5.0), 0.0);
      // tabulatedRange reports a degenerate (0, 0) span.
      final r = curve.tabulatedRange();
      expect(r.low, 0.0);
      expect(r.high, 0.0);
    });

    test('single-point curve returns that point for every Mach', () {
      final curve = CustomDragCurve.fromPoints(
        id: 'single',
        displayName: 'single',
        points: const [
          MachCd(mach: 1.5, cd: 0.42),
        ],
      );
      expect(curve.dragCoefficient(0.5), closeTo(0.42, 1e-9));
      expect(curve.dragCoefficient(1.5), closeTo(0.42, 1e-9));
      expect(curve.dragCoefficient(3.0), closeTo(0.42, 1e-9));
    });

    test('duplicate Mach entries do not divide by zero', () {
      // Construction sorts by Mach; if two entries share a Mach they
      // land adjacent and the PCHIP `h` value goes to zero. Should
      // return the first sample's Cd, not NaN.
      final curve = CustomDragCurve.fromPoints(
        id: 'dup',
        displayName: 'dup',
        points: const [
          MachCd(mach: 0.5, cd: 0.30),
          MachCd(mach: 1.0, cd: 0.40),
          MachCd(mach: 1.0, cd: 0.41),
          MachCd(mach: 2.0, cd: 0.20),
        ],
      );
      // Sample at Mach 1.0 — the implementation returns one of the
      // two duplicate values; either is acceptable as long as it's
      // finite and within the [0.40, 0.41] interval.
      final cd = curve.dragCoefficient(1.0);
      expect(cd.isFinite, isTrue);
      expect(cd, greaterThanOrEqualTo(0.40));
      expect(cd, lessThanOrEqualTo(0.41));
    });

    test('rejects non-positive Cd at construction', () {
      // The factory throws ArgumentError for any non-positive or
      // non-finite Cd, matching the constructor contract.
      expect(
        () => CustomDragCurve.fromPoints(
          id: 'bad',
          displayName: 'bad',
          points: const [
            MachCd(mach: 1.0, cd: 0.0),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => CustomDragCurve.fromPoints(
          id: 'bad2',
          displayName: 'bad2',
          points: const [
            MachCd(mach: 1.0, cd: -0.10),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
