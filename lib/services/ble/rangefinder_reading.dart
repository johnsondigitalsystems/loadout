// FILE: lib/services/ble/rangefinder_reading.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Shared types for every BLE rangefinder adapter LoadOut talks to. We have
// five brands today:
//
//   - Sig Sauer KILO BDX (Bluetooth Smart, BDX protocol)
//   - Bushnell Elite 1 Mile / Forge / Prime / Phantom 2 / Engage
//   - Vortex Razor HD 4000 (Fury HD AB ballistic version)
//   - Leica Geovid Pro
//   - Vectronix Terrapin X (mil/LE-grade laser rangefinder, magnetometer)
//
// Rather than each adapter inventing its own reading struct, every adapter
// emits a [RangefinderReading]. The Range Day distance picker reads the
// most recent reading from whichever adapter is currently connected and
// offers a "Use last reading" button to pull the value into the distance
// input.
//
// All distances are normalized to BOTH yards and metres at the adapter
// boundary — different devices report in different native units, but the
// UI doesn't want to think about it. Pick whichever the UI prefers.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/services/ble/sig_kilo_service.dart
// - lib/services/ble/bushnell_rangefinder_service.dart
// - lib/services/ble/vortex_rangefinder_service.dart
// - lib/services/ble/leica_geovid_service.dart
// - lib/services/ble/vectronix_terrapin_service.dart
// - lib/screens/devices/devices_screen.dart
// - lib/screens/range_day/range_day_detail_screen.dart

/// One snapshot of a range measurement from a Bluetooth rangefinder.
/// All units are converted at the adapter boundary so consumers don't
/// have to remember which device reports yards vs metres natively.
class RangefinderReading {
  const RangefinderReading({
    required this.rangeYd,
    required this.rangeM,
    required this.receivedAt,
    this.signalStrengthRssi,
    this.angleDeg,
    this.inclineCorrectedRangeYd,
    this.azimuthDeg,
    this.vendor,
  });

  /// Range to target, yards.
  final double rangeYd;

  /// Range to target, metres.
  final double rangeM;

  /// Wall-clock time the frame arrived.
  final DateTime receivedAt;

  /// Optional RSSI of the BLE link at the moment the frame was received,
  /// dBm (negative). Null if the platform didn't surface it.
  final int? signalStrengthRssi;

  /// Optional incline / decline angle reported by the unit, degrees.
  /// Positive = up, negative = down. Null when the device didn't include
  /// an angle field in the frame (e.g. non-ABS Bushnells).
  final double? angleDeg;

  /// Optional shoot-to (incline-corrected) range in yards, if the device
  /// computed it. The Sig BDX, Vortex Razor HD 4000, and Leica Geovid
  /// Pro all do; older Bushnells often don't.
  final double? inclineCorrectedRangeYd;

  /// Optional magnetic azimuth (compass bearing) the device pointed at
  /// when the laser fired, degrees clockwise from magnetic north,
  /// 0–360°. Only the Vectronix Terrapin X among the supported
  /// rangefinders has a built-in magnetometer that publishes this in the
  /// live frame; for the other adapters this is always null. Consumers
  /// (Range Day quick-fill) can use it to set the shot azimuth field in
  /// the same tap that fills the distance.
  final double? azimuthDeg;

  /// Optional vendor identifier (e.g. `'sig'`, `'bushnell'`, `'vortex'`,
  /// `'leica'`, `'vectronix'`). Allows downstream consumers to surface
  /// vendor-specific UI hints (e.g. "compass bearing also available")
  /// without keeping a separate reverse-lookup table. May be null on
  /// adapters that haven't been updated to set it.
  final String? vendor;

  /// True when the device included a usable angle field. Convenience for
  /// UIs that want to show an "ABS" badge.
  bool get hasIncline => angleDeg != null;

  /// True when the device included a usable magnetic-azimuth field.
  bool get hasAzimuth => azimuthDeg != null;
}

/// Small unit-conversion helpers used by every adapter. Centralized
/// here so the conversion is auditable in one place.
const double kYardsPerMetre = 1.09361;
const double kMetresPerYard = 0.9144;

/// Convert metres to yards.
double metresToYards(double m) => m * kYardsPerMetre;

/// Convert yards to metres.
double yardsToMetres(double yd) => yd * kMetresPerYard;
