// FILE: lib/services/sensors/magnetometer_service.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Wraps the OS magnetometer + accelerometer streams behind a
// `ChangeNotifier` and exposes a single live "compass heading" scalar in
// degrees [0, 360):
//
//   * 0   = magnetic / true north (depending on declination handling)
//   * 90  = east
//   * 180 = south
//   * 270 = west
//
// HOW IT'S COMPUTED. A magnetometer alone is not a compass — its raw
// reading is a 3-axis vector in *device* coordinates, not in the local
// horizontal plane. To turn that into a heading we tilt-compensate using
// the accelerometer (gravity-down vector) so a phone held face-up,
// face-down, or upright all report the same azimuth as the user
// intuitively expects. The classic Android "fuse" formula:
//
//     pitch = atan2(-A.x, sqrt(A.y² + A.z²))
//     roll  = atan2(A.y, A.z)
//     mx'   = M.x * cos(pitch) + M.z * sin(pitch)
//     my'   = M.x * sin(roll) * sin(pitch)
//             + M.y * cos(roll)
//             - M.z * sin(roll) * cos(pitch)
//     heading = atan2(-my', mx') * 180 / π        (degrees, [-180, 180])
//
// We then add 360 if negative to get [0, 360), apply the magnetic
// declination correction (true-north vs. magnetic-north) if a location
// is known, and smooth the result with a small exponential filter to
// remove the high-frequency jitter that a raw magnetometer reading
// always shows.
//
// TRUE-NORTH DECLINATION. The simplest correct answer requires a recent
// IGRF / WMM model — too heavy for this app. Instead we ship a tiny
// const region table covering the continental US and a few common
// shooter destinations (Africa, Australia, Europe). A caller that
// already knows its lat/lon can look up the declination at start-up
// and pass it in via [setDeclinationDegrees]; otherwise the readout
// stays magnetic-north and we annotate the UI accordingly. TODO: pull
// IGRF / WMM data from the device's geolocation if a GPS lock is
// already available.

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:sensors_plus/sensors_plus.dart';

/// Coarse magnetic declination table (degrees, positive = east) keyed
/// by a few-degree lat/lon bin. Only used as a "good enough" correction
/// for shooters who haven't supplied an exact value via a known IGRF /
/// WMM lookup. Values are 2025 epoch sampled from NOAA's NCEI online
/// calculator (https://www.ngdc.noaa.gov/geomag/calculators/magcalc.shtml)
/// at the bin centres; small errors (up to ~1°) are well below the
/// precision a phone magnetometer can deliver in any case.
///
/// To extend the table, add a `_DeclinationBin(latStart, lonStart,
/// latStartPlus10, lonStartPlus10, declDeg)` for any 10°×10° region
/// where the app is expected to be used.
const List<_DeclinationBin> _declinationTable = [
  // Continental US (lat 25–50°N, lon 65–125°W).
  _DeclinationBin(45, -125, 50, -115, 14.5), // Pacific Northwest
  _DeclinationBin(35, -125, 45, -115, 12.5), // California / Nevada
  _DeclinationBin(25, -125, 35, -115, 10.0), // SoCal / Baja
  _DeclinationBin(35, -115, 45, -105, 8.0), // Mountain West
  _DeclinationBin(25, -115, 35, -105, 6.5), // Texas / NM
  _DeclinationBin(35, -105, 45, -95, 3.0), // Plains
  _DeclinationBin(25, -105, 35, -95, 2.0), // South Plains
  _DeclinationBin(35, -95, 45, -85, -2.5), // Midwest
  _DeclinationBin(25, -95, 35, -85, -1.0), // Gulf
  _DeclinationBin(35, -85, 45, -75, -8.5), // Mid-Atlantic
  _DeclinationBin(25, -85, 35, -75, -6.0), // Southeast
  _DeclinationBin(35, -75, 50, -65, -14.5), // Northeast
  // Alaska / NW Canada (rough — the IGRF gradient is steep here).
  _DeclinationBin(55, -160, 70, -130, 17.0),
  // Hawaii (single bin).
  _DeclinationBin(15, -165, 25, -150, 10.0),
  // Western Europe.
  _DeclinationBin(40, -10, 60, 5, 0.5),
  _DeclinationBin(40, 5, 60, 20, 4.0),
  // Eastern Europe / Russia (shooter friendly bins).
  _DeclinationBin(40, 20, 60, 40, 7.5),
  // Australia (East / SE).
  _DeclinationBin(-45, 130, -25, 155, 11.5),
  // Africa (very coarse).
  _DeclinationBin(-35, 15, -15, 35, -25.0),
];

class _DeclinationBin {
  const _DeclinationBin(
    this.latStart,
    this.lonStart,
    this.latEnd,
    this.lonEnd,
    this.declDeg,
  );

  final double latStart;
  final double lonStart;
  final double latEnd;
  final double lonEnd;
  final double declDeg;

  bool contains(double lat, double lon) {
    return lat >= latStart && lat < latEnd && lon >= lonStart && lon < lonEnd;
  }
}

/// Look up a coarse magnetic declination (degrees east of true north)
/// for the given lat/lon. Returns null if no bin matches — the caller
/// should treat the heading as magnetic and annotate the UI.
double? lookupDeclinationDeg(double latitudeDeg, double longitudeDeg) {
  for (final bin in _declinationTable) {
    if (bin.contains(latitudeDeg, longitudeDeg)) return bin.declDeg;
  }
  return null;
}

/// Live compass-heading service. Fuses the magnetometer with the
/// accelerometer to compute a tilt-compensated heading in degrees.
///
/// Provided once via `Provider` in `lib/app.dart` and consumed by the
/// Range Day Setup card. Notifies on every smoothed sample.
///
/// Use [start] to begin sampling and [stop] to release the OS sensors.
/// Optionally call [setDeclinationDegrees] to switch the readout from
/// magnetic-north to true-north. If [setDeclinationFromLocation] is
/// invoked it derives the value from the const region table above.
class MagnetometerService extends ChangeNotifier {
  /// Smoothing coefficient for the EMA on the heading angle. The
  /// magnetometer is noisy enough that 0.10 still feels responsive.
  static const double _emaAlpha = 0.10;

  /// Sampling period — UI interval (~15 Hz) gives a smooth needle.
  static const Duration _samplingPeriod = SensorInterval.uiInterval;

  StreamSubscription<MagnetometerEvent>? _magSub;
  StreamSubscription<AccelerometerEvent>? _accSub;

  /// Latest accelerometer sample, used as the "down" reference for
  /// tilt compensation. Kept as nullable doubles so the very first
  /// frame doesn't divide by zero.
  double? _aX, _aY, _aZ;

  /// Smoothed heading in degrees [0, 360). Null until both streams
  /// have produced at least one sample.
  double? _smoothedDeg;

  /// Magnetic declination correction, degrees (positive = east).
  /// Subtracted from the magnetic heading to yield true heading.
  double _declinationDeg = 0.0;

  /// True if the user / location helper supplied a declination.
  /// When false, the readout is annotated as "magnetic" in the UI.
  bool _declinationKnown = false;

  bool _running = false;
  bool _available = true;

  /// Heading degrees, [0, 360). Includes declination correction if known.
  /// Null until the first fused sample arrives.
  double? get headingDegrees => _smoothedDeg;

  bool get isAvailable => _available;
  bool get isRunning => _running;

  /// Whether the readout is corrected to true north or still in
  /// magnetic north. Free-tier UI uses this to label the readout.
  bool get isTrueNorth => _declinationKnown;

  /// Currently active magnetic declination in degrees east. Useful
  /// for diagnostic UI; the [headingDegrees] getter already includes
  /// this correction.
  double get declinationDeg => _declinationDeg;

  /// Begin sampling. Idempotent. Returns false on platforms without
  /// magnetometer support (desktop, web).
  Future<bool> start() async {
    if (_running) return _available;
    if (kIsWeb) {
      _markUnavailable();
      return false;
    }
    if (!(Platform.isIOS || Platform.isAndroid)) {
      _markUnavailable();
      return false;
    }
    try {
      _accSub = accelerometerEventStream(samplingPeriod: _samplingPeriod)
          .listen(_handleAccelerometer, onError: _onStreamError);
      _magSub = magnetometerEventStream(samplingPeriod: _samplingPeriod)
          .listen(_handleMagnetometer, onError: _onStreamError);
      _running = true;
      _available = true;
      return true;
    } on MissingPluginException {
      _markUnavailable();
      return false;
    } catch (e) {
      debugPrint('MagnetometerService start failed: $e');
      _markUnavailable();
      return false;
    }
  }

  /// Set `_available = false` and notify listeners. Idempotent.
  void _markUnavailable() {
    if (!_available) return;
    _available = false;
    notifyListeners();
  }

  /// Stop sampling and release the OS sensors.
  Future<void> stop() async {
    await _magSub?.cancel();
    await _accSub?.cancel();
    _magSub = null;
    _accSub = null;
    _running = false;
  }

  /// Set the magnetic declination explicitly (degrees east of true
  /// north). Subsequent readings will be corrected to true heading.
  void setDeclinationDegrees(double deg) {
    if ((deg - _declinationDeg).abs() < 0.01 && _declinationKnown) return;
    _declinationDeg = deg;
    _declinationKnown = true;
    notifyListeners();
  }

  /// Look up a coarse declination from the built-in region table given
  /// the user's lat/lon, and apply it. Returns true if a bin matched
  /// and the declination was applied. Callers that already have a more
  /// accurate IGRF / WMM value should use [setDeclinationDegrees]
  /// instead.
  bool setDeclinationFromLocation(double latitudeDeg, double longitudeDeg) {
    final decl = lookupDeclinationDeg(latitudeDeg, longitudeDeg);
    if (decl == null) return false;
    setDeclinationDegrees(decl);
    return true;
  }

  /// Reset the declination so the readout returns to magnetic north.
  void clearDeclination() {
    if (!_declinationKnown && _declinationDeg == 0.0) return;
    _declinationDeg = 0.0;
    _declinationKnown = false;
    notifyListeners();
  }

  void _onStreamError(Object e, StackTrace _) {
    debugPrint('MagnetometerService stream error: $e');
    _markUnavailable();
  }

  void _handleAccelerometer(AccelerometerEvent e) {
    _aX = e.x;
    _aY = e.y;
    _aZ = e.z;
    // No notify — a heading update fires only when a magnetometer
    // sample comes in.
  }

  void _handleMagnetometer(MagnetometerEvent e) {
    final ax = _aX, ay = _aY, az = _aZ;
    if (ax == null || ay == null || az == null) {
      // Wait for the first accelerometer sample.
      return;
    }

    // Tilt compensation. See header for the formula derivation.
    final pitch = math.atan2(-ax, math.sqrt(ay * ay + az * az));
    final roll = math.atan2(ay, az);
    final cosPitch = math.cos(pitch);
    final sinPitch = math.sin(pitch);
    final cosRoll = math.cos(roll);
    final sinRoll = math.sin(roll);

    final mxPrime = e.x * cosPitch + e.z * sinPitch;
    final myPrime = e.x * sinRoll * sinPitch +
        e.y * cosRoll -
        e.z * sinRoll * cosPitch;

    var headingRad = math.atan2(-myPrime, mxPrime);
    var headingDeg = headingRad * 180.0 / math.pi;
    // atan2 returns (-180, 180]. Convert to [0, 360).
    if (headingDeg < 0) headingDeg += 360.0;
    // Apply declination (positive east = subtract from magnetic to
    // get true heading? — east declination means TRUE north is to the
    // WEST of magnetic, so true = magnetic + declination).
    headingDeg += _declinationDeg;
    if (headingDeg < 0) headingDeg += 360.0;
    if (headingDeg >= 360) headingDeg -= 360.0;

    final prev = _smoothedDeg;
    if (prev == null) {
      _smoothedDeg = headingDeg;
    } else {
      // Naive EMA fails across the 0/360 wraparound (interpolating from
      // 359° to 1° produces 180° instead of 0°). Project both into a
      // unit-circle representation, blend, then re-project.
      final prevRad = prev * math.pi / 180.0;
      final newRad = headingDeg * math.pi / 180.0;
      final sx = (1 - _emaAlpha) * math.cos(prevRad) +
          _emaAlpha * math.cos(newRad);
      final sy = (1 - _emaAlpha) * math.sin(prevRad) +
          _emaAlpha * math.sin(newRad);
      var blended = math.atan2(sy, sx) * 180.0 / math.pi;
      if (blended < 0) blended += 360.0;
      _smoothedDeg = blended;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    // ignore: discarded_futures
    _magSub?.cancel();
    // ignore: discarded_futures
    _accSub?.cancel();
    super.dispose();
  }
}
