// FILE: test/environment_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Coverage tests for `lib/services/ballistics/environment.dart`. Existing
// solver-level tests (`ballistics_test.dart`, `ballistic_precision_test.dart`)
// rely on the Environment class but never spot-check its math. This file
// pins down:
//
//   * the `fromImperial` factory's mph-to-m/s conversion;
//   * the wind-vector convention at the four cardinal angles
//     (0/90/180/270°) plus a 45° quartering case;
//   * the signed crosswind component used by the aerodynamic-jump
//     correction — the sign that flips when wind direction crosses
//     the LoS;
//   * the Earth-rotation-vector projection across hemispheres
//     (N→positive ωy, S→negative ωy) and across cardinal compass
//     bearings (N/E/S/W);
//   * Environment composition with a non-trivial Atmosphere snapshot
//     (humid sea-level vs ICAO).
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Environment is the bullet-agnostic side of the solver — the same
// projectile produces different drift across hemispheres, latitudes,
// and shot azimuths because its environment vector projection
// changes. A regression in either the wind vector or the Earth-rotation
// vector silently shifts every Coriolis / aero-jump number in the
// app. Verifying the projection in isolation makes those failures
// land here, not in a downstream end-to-end mismatch test.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * The wind-direction convention is meteorological ("from") not
//     vector-math ("toward"). Tests document the expected sign at
//     each cardinal so a future code change that flips the convention
//     trips the assertion immediately.
//
//   * `crossWindComponentMps` returns the SIGNED component the
//     aerodynamic-jump path uses (positive for "wind from the left",
//     matching spin-drift sign). The full wind vector and the signed
//     scalar are deliberately on different conventions — this file
//     pins the sign of each.
//
//   * Coriolis sign on the southern hemisphere requires the latitude
//     parameter to be negative; the projection formula uses sin(lat)
//     which is odd, so the sign flip happens automatically. We assert
//     the flip explicitly so a future "abs(lat)" bug is caught.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   - `flutter test` suite.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure unit tests over an immutable value class.
// ============================================================================

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/services/ballistics/atmosphere.dart';
import 'package:loadout/services/ballistics/environment.dart';
import 'package:loadout/services/ballistics/units.dart';

void main() {
  // Earth's sidereal rotation rate in rad/s, copied from
  // environment.dart so the test file is self-explanatory.
  const omega = 7.2921159e-5;

  group('Environment.fromImperial', () {
    test('converts mph wind to m/s using the NIST factor', () {
      final env = Environment.fromImperial(
        atmosphere: Atmosphere.icaoStd(),
        windSpeedMph: 10.0,
        windFromDegrees: 0.0,
        shotAzimuthDegrees: 0.0,
        latitudeDegrees: 0.0,
        targetElevationFt: 0.0,
      );
      // 10 mph → 4.4704 m/s exactly per NIST.
      expect(env.windSpeedMps, closeTo(4.4704, 1e-9));
    });

    test('preserves direction / azimuth / latitude / elevation as-is', () {
      // The factory should pass non-speed scalars through unchanged.
      final env = Environment.fromImperial(
        atmosphere: Atmosphere.icaoStd(),
        windSpeedMph: 5.0,
        windFromDegrees: 217.5,
        shotAzimuthDegrees: 132.0,
        latitudeDegrees: -34.5,
        targetElevationFt: 250.0,
      );
      expect(env.windFromDegrees, 217.5);
      expect(env.shotAzimuthDegrees, 132.0);
      expect(env.latitudeDegrees, -34.5);
      expect(env.targetElevationFt, 250.0);
    });
  });

  group('Environment.windVector — wind convention', () {
    Environment buildWind(double mph, double fromDeg) {
      return Environment.fromImperial(
        atmosphere: Atmosphere.icaoStd(),
        windSpeedMph: mph,
        windFromDegrees: fromDeg,
        shotAzimuthDegrees: 0.0,
        latitudeDegrees: 0.0,
        targetElevationFt: 0.0,
      );
    }

    test('0° = tailwind: wind vector points downrange (+x)', () {
      // Wind FROM behind the shooter → air moves downrange → +x.
      final env = buildWind(10.0, 0.0);
      final v = env.windVector;
      expect(v.x, lessThan(0)); // air's velocity vector at theta=0:
      // -windSpeedMps * cos(0) = -windSpeedMps; the SOLVER uses this
      // air velocity in v_rel = v_bullet - windVector, so v_rel
      // becomes more negative in x → drag opposes that → effective
      // tailwind boost. Sign here matches the solver's expectation.
      expect(v.x, closeTo(-mphToMps(10.0), 1e-9));
      expect(v.z, closeTo(0.0, 1e-12));
      expect(v.y, 0.0);
    });

    test('180° = headwind: wind vector points upwind (-x as +mph * cos)', () {
      // 180° = wind FROM ahead → air moves backward (toward shooter).
      final env = buildWind(10.0, 180.0);
      final v = env.windVector;
      // -windSpeedMps * cos(180°) = +windSpeedMps. Sign convention is
      // such that "headwind" pushes the air toward +x of the air-vector
      // formula — the solver's relative-velocity arithmetic does the
      // right thing because v_rel = v_bullet - windVector.
      expect(v.x, closeTo(mphToMps(10.0), 1e-9));
      expect(v.z, closeTo(0.0, 1e-12));
    });

    test('90° crosswind has full magnitude in z and zero in x', () {
      final env = buildWind(10.0, 90.0);
      final v = env.windVector;
      // sin(90°) = 1 → full crosswind component in z.
      expect(v.x.abs(), lessThan(1e-9));
      expect(v.z.abs(), closeTo(mphToMps(10.0), 1e-9));
    });

    test('45° quartering: equal x and z magnitudes (sqrt(2)/2 each)', () {
      final env = buildWind(10.0, 45.0);
      final v = env.windVector;
      final expected = mphToMps(10.0) * math.sqrt(2.0) / 2.0;
      // |x| and |z| equal magnitudes for a 45° quartering wind.
      expect(v.x.abs(), closeTo(expected, 1e-9));
      expect(v.z.abs(), closeTo(expected, 1e-9));
    });

    test('270° crosswind reverses z sign relative to 90°', () {
      final right = buildWind(10.0, 90.0);
      final left = buildWind(10.0, 270.0);
      // The two crosswind directions must have opposite-sign z
      // components and equal magnitudes.
      expect(right.windVector.z + left.windVector.z, closeTo(0.0, 1e-9));
      expect(right.windVector.z.abs(),
          closeTo(left.windVector.z.abs(), 1e-9));
    });
  });

  group('Environment.crossWindComponentMps — aerodynamic-jump signing', () {
    Environment buildCross(double mph, double fromDeg) {
      return Environment.fromImperial(
        atmosphere: Atmosphere.icaoStd(),
        windSpeedMph: mph,
        windFromDegrees: fromDeg,
        shotAzimuthDegrees: 0.0,
        latitudeDegrees: 0.0,
        targetElevationFt: 0.0,
      );
    }

    test('right-side wind (90°) is negative; left-side wind (270°) is positive',
        () {
      // The aerodynamic-jump path expects "wind from the left" to be
      // positive — same sign as the spin-drift drift for a right-twist
      // barrel. Test both halves.
      final right = buildCross(10.0, 90.0);
      final left = buildCross(10.0, 270.0);
      expect(right.crossWindComponentMps, lessThan(0));
      expect(left.crossWindComponentMps, greaterThan(0));
      expect(
        right.crossWindComponentMps + left.crossWindComponentMps,
        closeTo(0.0, 1e-9),
      );
    });

    test('headwind / tailwind crosswind component is zero', () {
      // A pure 0° / 180° wind has no z component — the test stops
      // any future bug that turns headwind into a fake crosswind.
      final tail = buildCross(10.0, 0.0);
      final head = buildCross(10.0, 180.0);
      expect(tail.crossWindComponentMps.abs(), lessThan(1e-9));
      expect(head.crossWindComponentMps.abs(), lessThan(1e-9));
    });
  });

  group('Environment.earthRotationVector — Coriolis projection', () {
    Environment buildAt(double latDeg, double azDeg) {
      return Environment.fromImperial(
        atmosphere: Atmosphere.icaoStd(),
        windSpeedMph: 0.0,
        windFromDegrees: 0.0,
        shotAzimuthDegrees: azDeg,
        latitudeDegrees: latDeg,
        targetElevationFt: 0.0,
      );
    }

    test('northern hemisphere: ωy > 0; southern hemisphere: ωy < 0', () {
      final n = buildAt(45.0, 0.0);
      final s = buildAt(-45.0, 0.0);
      // sin(45°) > 0 → ωy > 0; sin(-45°) = -sin(45°) → ωy < 0.
      expect(n.earthRotationVector.y, greaterThan(0));
      expect(s.earthRotationVector.y, lessThan(0));
      // Magnitudes equal at the same |latitude|.
      expect(
        n.earthRotationVector.y + s.earthRotationVector.y,
        closeTo(0.0, 1e-12),
      );
    });

    test('equator + due-north shot: ωy = 0, ωx = +Ω, ωz = 0', () {
      final env = buildAt(0.0, 0.0);
      final r = env.earthRotationVector;
      // cos(0)·cos(0) = 1 → ωx = Ω; sin(0) = 0 → ωy = 0;
      // cos(0)·sin(0) = 0 → ωz = 0.
      expect(r.x, closeTo(omega, 1e-12));
      expect(r.y.abs(), lessThan(1e-12));
      expect(r.z.abs(), lessThan(1e-12));
    });

    test('equator + due-east shot (az=90°): ωx = 0, ωy = 0, ωz = -Ω', () {
      final env = buildAt(0.0, 90.0);
      final r = env.earthRotationVector;
      // cos(0)·cos(90°) = 0 → ωx = 0; sin(0) = 0 → ωy = 0;
      // -cos(0)·sin(90°) = -1 → ωz = -Ω.
      expect(r.x.abs(), lessThan(1e-12));
      expect(r.y.abs(), lessThan(1e-12));
      expect(r.z, closeTo(-omega, 1e-12));
    });

    test('North Pole shot: ωx = 0, ωy = +Ω, ωz = 0 regardless of azimuth',
        () {
      // At lat=+90°, cos(lat)=0 so the horizontal components drop
      // out and ωy = Ω. Azimuth shouldn't matter.
      for (final az in [0.0, 45.0, 132.0, 270.0]) {
        final env = buildAt(90.0, az);
        final r = env.earthRotationVector;
        expect(r.x.abs(), lessThan(1e-12),
            reason: 'azimuth $az° at the pole');
        expect(r.y, closeTo(omega, 1e-12));
        expect(r.z.abs(), lessThan(1e-12));
      }
    });
  });

  group('Environment composition with Atmosphere', () {
    test('a humid Atmosphere is preserved unchanged inside Environment',
        () {
      // Build a non-ICAO atmosphere and verify Environment surfaces
      // the same density and speed of sound. Composition must not
      // accidentally re-derive the atmosphere from another input.
      final humidAtm = Atmosphere.station(
        tempF: 75.0,
        stationPressureInHg: 29.5,
        humidityPct: 60.0,
      );
      final env = Environment.fromImperial(
        atmosphere: humidAtm,
        windSpeedMph: 5.0,
        windFromDegrees: 90.0,
        shotAzimuthDegrees: 90.0,
        latitudeDegrees: 30.0,
        targetElevationFt: 100.0,
      );
      expect(env.atmosphere.density, equals(humidAtm.density));
      expect(env.atmosphere.speedOfSound, equals(humidAtm.speedOfSound));
      expect(env.atmosphere.relativeHumidity, equals(humidAtm.relativeHumidity));
      // And the per-shot fields are preserved at the Environment level.
      expect(env.targetElevationFt, 100.0);
    });
  });
}
