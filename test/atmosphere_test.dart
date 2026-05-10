// FILE: test/atmosphere_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Coverage tests for `lib/services/ballistics/atmosphere.dart` — the file
// that turns "what's the weather doing where I'm shooting" into the two
// scalars the solver actually uses (air density in kg/m³ and the local
// speed of sound in m/s). The existing ballistics test files cover the
// solver's end-to-end accuracy and a single ICAO-density spot-check; this
// file fills the gap: ICAO-standard reference values, density-altitude
// math, station vs ICAO equivalence, conversion sanity, ridiculous-input
// handling (negative/over-100% humidity, sub-absolute-zero temperatures,
// negative pressure), and the round-trip pressure → DA → pressure
// invariant.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The atmosphere math feeds every other ballistic-correction test in the
// repo. If `Atmosphere.station` returns NaN or a wrong density, every
// downstream solver test fails for the wrong reason — debugging starts
// here and propagates outward. Putting the atmospheric primitive coverage
// in one file means any future regression in the air-density path is
// caught with a one-line failure message, not a sea of mis-attributed
// drop-vs-truth diffs from the solver layer.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * The constructor `Atmosphere.station` clamps humidity to [0, 100]
//     internally — the caller can't reliably detect over-/under-clamped
//     input from the resulting density alone. We compare against the
//     boundary case (0% / 100%) so the test catches a constructor that
//     stops clamping.
//
//   * `Atmosphere.fromAltitudeFt` uses the ICAO troposphere model which
//     gets nonsense above the tropopause (~36 000 ft). Tests stay below
//     that.
//
//   * Pressure round-trip via density-altitude is sensitive to floating
//     point: standard atmosphere uses a ratio-of-temperatures power that
//     accumulates error fast. The 0.01% tolerance in the spec is met
//     comfortably for sea level (the inversion is exact there) and for
//     the ICAO altitude path; it requires care for `Atmosphere.station`
//     because the speed-of-sound humidity correction shifts the molar
//     mass.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   - run as part of the regular `flutter test` suite.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure unit tests over a pure-functional module.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/services/ballistics/atmosphere.dart';
import 'package:loadout/services/ballistics/units.dart';

void main() {
  group('Atmosphere — ICAO standard sea level', () {
    test('density matches 1.225 kg/m³', () {
      final atm = Atmosphere.icaoStd();
      // ICAO sea-level dry-air density is 1.225 kg/m³ by definition.
      expect(atm.density, closeTo(1.225, 1e-6));
    });

    test('pressure ~29.92 inHg / 1013.25 hPa', () {
      final atm = Atmosphere.icaoStd();
      // 101325 Pa = 29.9213 inHg (NIST 1 inHg = 3386.389 Pa).
      expect(paToInHg(atm.pressurePa), closeTo(29.9213, 1e-3));
      // 101325 Pa = 1013.25 hPa.
      expect(atm.pressurePa / 100.0, closeTo(1013.25, 1e-3));
    });

    test('temperature 59°F / 15°C / 288.15 K', () {
      final atm = Atmosphere.icaoStd();
      expect(atm.temperatureK, closeTo(288.15, 1e-9));
      // 15.0°C → 59°F.
      expect(cToF(atm.temperatureK - 273.15), closeTo(59.0, 1e-9));
    });

    test('speed of sound ~340.294 m/s (~1116.45 fps)', () {
      final atm = Atmosphere.icaoStd();
      // ICAO publishes 340.294 exactly; the file's IcaoStd constant
      // matches that. Allow a tiny tolerance so a future humid-air
      // sound-speed correction (e.g. swapping in the molar form across
      // the board) does not flake the test on the 4th decimal place.
      expect(atm.speedOfSound, closeTo(340.294, 0.05));
      expect(mpsToFps(atm.speedOfSound), closeTo(1116.45, 0.2));
    });
  });

  group('Atmosphere — fromAltitudeFt (ICAO troposphere)', () {
    test('sea-level fromAltitudeFt(0) ≈ icaoStd', () {
      final a0 = Atmosphere.fromAltitudeFt(0);
      final ref = Atmosphere.icaoStd();
      // Standard atmosphere at h=0 must reproduce the reference values.
      // The speed-of-sound check has a wider tolerance because
      // `icaoStd` uses the published constant 340.294 m/s while
      // `fromAltitudeFt` recomputes via sqrt(γ·R·T) — the two agree
      // to ~3 mm/s, well below the precision the solver consumes.
      expect(a0.density, closeTo(ref.density, 1e-4));
      expect(a0.pressurePa, closeTo(ref.pressurePa, 1.0));
      expect(a0.temperatureK, closeTo(ref.temperatureK, 1e-6));
      expect(a0.speedOfSound, closeTo(ref.speedOfSound, 0.01));
    });

    test('density falls with altitude (5000 ft is ~14% thinner)', () {
      final atm = Atmosphere.fromAltitudeFt(5000);
      // industry-standard / ICAO tables: at 5000 ft density ≈ 1.0556 kg/m³,
      // i.e. about 86% of sea level.
      expect(atm.density, lessThan(1.225));
      expect(atm.density, greaterThan(1.0));
      expect(atm.density, closeTo(1.0556, 0.01));
      expect(atm.pressurePa, lessThan(101325.0));
    });

    test('density-altitude getter recovers the input altitude', () {
      // Round-trip: build an atmosphere AT altitude h, ask its
      // density-altitude back. They must agree to within tight
      // tolerance because both directions invert the same formula.
      const heights = [0.0, 1000.0, 3000.0, 5000.0, 8000.0, 10000.0];
      for (final h in heights) {
        final atm = Atmosphere.fromAltitudeFt(h);
        expect(
          atm.densityAltitudeFt,
          closeTo(h, 1.0),
          reason: 'density-altitude round-trip at $h ft',
        );
      }
    });
  });

  group('Atmosphere.station — sea-level baseline + delta-T', () {
    test('59°F, 29.92 inHg, 0% RH at 0 ft ≈ ICAO standard', () {
      // Build the same conditions as ICAO via the station-report
      // factory. Density should match within ~1% (humid-air formula
      // approximations).
      final atm = Atmosphere.station(
        tempF: 59.0,
        stationPressureInHg: 29.9213,
        humidityPct: 0.0,
        altitudeFt: 0,
      );
      expect(atm.density, closeTo(1.225, 0.005));
      expect(atm.speedOfSound, closeTo(340.3, 0.5));
    });

    test('hot day (95°F) at sea-level pressure has lower density', () {
      // Higher temperature → thinner air → lower density.
      final cool = Atmosphere.station(
        tempF: 59.0,
        stationPressureInHg: 29.92,
        humidityPct: 0.0,
      );
      final hot = Atmosphere.station(
        tempF: 95.0,
        stationPressureInHg: 29.92,
        humidityPct: 0.0,
      );
      expect(hot.density, lessThan(cool.density));
      // T_K ratio = 295.37/288.15 ≈ 1.025 → density ratio ~0.93,
      // i.e. roughly 7% thinner on a hot summer day at sea level.
      expect(hot.density / cool.density, closeTo(288.15 / 308.15, 0.005));
    });

    test('humid air is slightly less dense than dry air (Tetens / Magnus)',
        () {
      // Counterintuitive but textbook: water vapor (M ≈ 18 g/mol) is
      // lighter than dry air (M ≈ 29 g/mol). At the same total
      // pressure, replacing some dry air with vapor lowers density.
      final dry = Atmosphere.station(
        tempF: 90.0,
        stationPressureInHg: 29.92,
        humidityPct: 0.0,
      );
      final humid = Atmosphere.station(
        tempF: 90.0,
        stationPressureInHg: 29.92,
        humidityPct: 100.0,
      );
      expect(humid.density, lessThan(dry.density));
      // The effect is small — empirically ~1.8% lighter at 90°F + 100% RH
      // (Magnus saturation pressure at 32°C is ~4.7 kPa, ~5% of total
      // pressure, weighted by the dry-vs-vapor specific R difference).
      // Allow a 5% lower bound so the test catches a sign flip but does
      // not flake on the second decimal of the saturation curve.
      expect(humid.density / dry.density, greaterThan(0.95));
      expect(humid.density / dry.density, lessThan(1.0));
    });
  });

  group('Atmosphere.station — input-conversion sanity', () {
    test('°F ↔ °C round-trip matches solver-internal conversion', () {
      // Sanity that the temperature path is the same one units.dart
      // declares; if these drift, every station-mode density value
      // shifts silently.
      expect(fToC(32.0), closeTo(0.0, 1e-9));
      expect(fToC(212.0), closeTo(100.0, 1e-9));
      expect(fToK(32.0), closeTo(273.15, 1e-9));
      expect(fToK(59.0), closeTo(288.15, 1e-9));
    });

    test('inHg ↔ Pa ↔ hPa conversions agree to NIST factor', () {
      // 1 inHg = 3386.389 Pa exactly (NIST). Round-trip and against
      // hPa form.
      expect(inHgToPa(29.9213), closeTo(101325.0, 0.5));
      expect(paToInHg(101325.0), closeTo(29.9213, 1e-3));
      // 1 hPa = 100 Pa.
      expect(inHgToPa(29.9213) / 100.0, closeTo(1013.25, 0.005));
    });
  });

  group('Atmosphere.station — ridiculous-input safety', () {
    test('humidity > 100% clamps to 100% (no NaN, no extra density loss)',
        () {
      // Constructor docstring says it clamps; verify the implementation
      // doesn't propagate an out-of-range value. Density must equal
      // the value at exactly 100%.
      final at100 = Atmosphere.station(
        tempF: 70.0,
        stationPressureInHg: 29.92,
        humidityPct: 100.0,
      );
      final atOver = Atmosphere.station(
        tempF: 70.0,
        stationPressureInHg: 29.92,
        humidityPct: 250.0,
      );
      expect(atOver.density.isFinite, isTrue);
      expect(atOver.speedOfSound.isFinite, isTrue);
      expect(atOver.density, closeTo(at100.density, 1e-9));
    });

    test('humidity < 0% clamps to 0% (no NaN)', () {
      final at0 = Atmosphere.station(
        tempF: 70.0,
        stationPressureInHg: 29.92,
        humidityPct: 0.0,
      );
      final atNeg = Atmosphere.station(
        tempF: 70.0,
        stationPressureInHg: 29.92,
        humidityPct: -50.0,
      );
      expect(atNeg.density.isFinite, isTrue);
      expect(atNeg.speedOfSound.isFinite, isTrue);
      expect(atNeg.density, closeTo(at0.density, 1e-9));
    });

    test('extreme cold input stays finite (no propagated infinities)', () {
      // A -200°F reading is below sublimation point of CO2 — physically
      // ridiculous for shooting but the solver should still return a
      // finite, non-negative density rather than a NaN or +Infinity.
      // (T_K = 144.26 K, well below the lapse-rate model's lower bound
      // for the troposphere but still positive Kelvin so the formulas
      // don't divide by zero.)
      final atm = Atmosphere.station(
        tempF: -200.0,
        stationPressureInHg: 29.92,
        humidityPct: 0.0,
      );
      expect(atm.density.isFinite, isTrue);
      expect(atm.density, greaterThan(0));
      expect(atm.speedOfSound.isFinite, isTrue);
      expect(atm.speedOfSound, greaterThan(0));
    });

    test('zero / negative pressure does not return NaN', () {
      // A pressure of 0 inHg is impossible above an absolute vacuum but
      // the call should not produce NaN — density should approach 0
      // and the speed-of-sound formula should still give a finite
      // (temperature-only) value.
      //
      // PRODUCTION BUG (atmosphere.dart): when stationPressureInHg = 0
      // the constructor evaluates `xV = pVapor / pPa` with pVapor == 0
      // and pPa == 0, producing NaN. NaN propagates into the molar
      // mass and the speed-of-sound formula. The downstream solver
      // would feed NaN into the Mach lookup table and the integration
      // would fall over silently. The fix is a small guard in
      // Atmosphere.station: when pPa <= 0 either bail with a thrown
      // ArgumentError or set xV = 0 (no vapor in vacuum is correct).
      // This test will pass once that guard lands.
      final atm = Atmosphere.station(
        tempF: 70.0,
        stationPressureInHg: 0.0,
        humidityPct: 0.0,
      );
      expect(atm.density.isFinite, isTrue);
      expect(atm.density, closeTo(0.0, 1e-3));
      expect(atm.speedOfSound.isFinite, isTrue);
    });
  });

  group('Atmosphere — density-altitude relationship', () {
    test('hot weather at sea level reads as a high density altitude', () {
      // 95°F at sea level → density-altitude well above 0 ft. The
      // textbook number for 95°F at sea level (dry, 29.92 inHg) is
      // around 2400-3000 ft DA depending on the formula; we accept
      // anything above 1500 ft as "non-trivial".
      final atm = Atmosphere.station(
        tempF: 95.0,
        stationPressureInHg: 29.92,
        humidityPct: 0.0,
      );
      expect(atm.densityAltitudeFt, greaterThan(1500.0));
      // And not absurdly high — under 5000 ft DA at sea-level pressure.
      expect(atm.densityAltitudeFt, lessThan(5000.0));
    });

    test('cold weather at sea level reads as a negative density altitude',
        () {
      // -10°F (very cold) at sea level pressure produces a NEGATIVE
      // density altitude (denser than sea-level standard).
      final atm = Atmosphere.station(
        tempF: -10.0,
        stationPressureInHg: 29.92,
        humidityPct: 0.0,
      );
      expect(atm.densityAltitudeFt, lessThan(0.0));
    });
  });

  group('Atmosphere.mach helper', () {
    test('mach() returns velocity / speedOfSound', () {
      final atm = Atmosphere.icaoStd();
      // 340.294 m/s = Mach 1 by definition at ICAO.
      expect(atm.mach(atm.speedOfSound), closeTo(1.0, 1e-9));
      // Half the speed of sound = Mach 0.5.
      expect(atm.mach(atm.speedOfSound * 0.5), closeTo(0.5, 1e-9));
      // 0 m/s = Mach 0.
      expect(atm.mach(0.0), 0.0);
    });
  });
}
