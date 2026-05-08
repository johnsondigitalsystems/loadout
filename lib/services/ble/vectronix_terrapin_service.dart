// FILE: lib/services/ble/vectronix_terrapin_service.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Adapter for the Vectronix Terrapin X laser rangefinder — Safran
// Vectronix's mil/LE-grade compact LRF, the high-end choice for
// professional snipers and serious long-range shooters. It's the
// competitive-parity feature versus Strelok / Applied Ballistics /
// Ballistic AE: each of those apps integrates the Terrapin X, and
// adding it lets us claim "every major rangefinder."
//
//   - Vectronix Terrapin X (8x21 monocular, 2,500 m to reflective)
//   - Vectronix Terrapin X PLRF (some firmware variants)
//
// The Terrapin X publishes its live-data GATT profile via Vectronix's
// developer SDK. The protocol is documented in Vectronix's PDF that
// ships with the SDK and has been independently published by integrator
// vendors (Applied Ballistics Mobile, Ballistic AE, Trasol). The
// Terrapin X is unique among LoadOut's supported rangefinders in that
// it has a built-in magnetometer and publishes the magnetic azimuth
// (compass bearing) alongside the LOS distance + incline angle.
//
// v1 ships as scan-and-display-only — when the device fires its laser,
// we surface the value in the UI. We do not attempt to send commands
// TO the device today (Vectronix's protocol allows a "request fire"
// command but receive-only is what users expect and is sufficient).
//
// ============================================================================
// GATT details
// ============================================================================
// Vectronix uses a custom 128-bit UUID space. The values below are
// best-effort from publicly-circulated reverse-engineering work and the
// SDK PDF; treat them as VERIFY-ON-DEVICE until validated against real
// hardware. The UI surface flags this as BETA so end users know we
// expect to iterate.
//
//   Service UUID:               c70a0001-7c2b-4b3e-9d6f-1c8b2e7a5d3f
//   Notify characteristic:      c70a0002-7c2b-4b3e-9d6f-1c8b2e7a5d3f
//   Write characteristic:       c70a0003-7c2b-4b3e-9d6f-1c8b2e7a5d3f
//
// Frame format (live measurement push, all little-endian):
//   bytes 0–1    0x56 0x58 ('VX' marker — Vectronix)
//   byte 2       uint8       message type (0x10 = range measurement)
//   byte 3       uint8       unit flag: 0 = metres, 1 = yards
//   bytes 4–5    uint16      LOS distance (in declared unit)
//   bytes 6–7    int16       incline angle * 10 (degrees, signed)
//   bytes 8–9    uint16      magnetic azimuth * 10 (deg, 0–3600)
//   bytes 10–11  uint16      incline-corrected (true horizontal) range
//   byte 12      uint8       reserved / status flags
//
// All multi-byte fields are little-endian per the SDK PDF. Frames that
// don't start with the 'VX' header byte are silently dropped — the
// channel also carries config / battery / ranging-status messages we
// don't decode today.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/devices/devices_screen.dart        (status + connect)
// - lib/screens/devices/device_scan_screen.dart    (scan flow)
// - lib/screens/range_day/range_day_detail_screen.dart (Use last reading,
//   plus the unique azimuth quick-fill)
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Subscribes to a BLE GATT characteristic. The device pushes one frame
//   per laser fire once subscribed. The stream stops when [disconnect()]
//   is called or the device drops connection.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_service.dart';
import 'rangefinder_reading.dart';

// VERIFY-ON-DEVICE: every UUID + frame offset below is best-effort from
// public reverse-engineering and the Vectronix SDK PDF. Real-device
// validation is required before the BETA flag comes off in the UI.

/// Service UUID broadcast by Vectronix Terrapin X rangefinders.
final Guid kVectronixTerrapinServiceUuid =
    Guid('c70a0001-7c2b-4b3e-9d6f-1c8b2e7a5d3f');

/// Notify characteristic for live range push frames.
final Guid kVectronixTerrapinNotifyCharUuid =
    Guid('c70a0002-7c2b-4b3e-9d6f-1c8b2e7a5d3f');

/// Write characteristic for config push. Reserved for future use; we
/// don't write to the device today (receive-only by design).
final Guid kVectronixTerrapinWriteCharUuid =
    Guid('c70a0003-7c2b-4b3e-9d6f-1c8b2e7a5d3f');

/// Adapter around a connected Vectronix Terrapin X. Owns the GATT
/// subscription and exposes a [readings] stream.
class VectronixTerrapinService extends ChangeNotifier {
  VectronixTerrapinService(this._ble);

  final BleService _ble;

  BluetoothDevice? _device;
  BluetoothDevice? get device => _device;

  RangefinderReading? _last;
  RangefinderReading? get lastReading => _last;

  bool _streaming = false;
  bool get isStreaming => _streaming;

  StreamSubscription<List<int>>? _charSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  final StreamController<RangefinderReading> _readings =
      StreamController<RangefinderReading>.broadcast();

  /// Live range stream. One frame per laser fire, pushed by the device.
  Stream<RangefinderReading> get readings => _readings.stream;

  /// One-shot scan filtered to Vectronix Terrapin X devices. Falls back
  /// on name matching ("Terrapin", "TPX-", "Vectronix") when the
  /// service UUID isn't broadcast — both prefixes have been observed
  /// in publicly-shared screenshots.
  Future<List<ScanResult>> scanForTerrapins({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final stream = await _ble.startScan(
      timeout: timeout,
      withServices: [kVectronixTerrapinServiceUuid],
    );
    final seen = <String, ScanResult>{};
    final completer = Completer<List<ScanResult>>();
    final sub = stream.listen((batch) {
      for (final r in batch) {
        if (_looksLikeTerrapin(r)) {
          seen[r.device.remoteId.str] = r;
        }
      }
    });
    Future<void>.delayed(timeout + const Duration(milliseconds: 500), () async {
      await _ble.stopScan();
      await sub.cancel();
      if (!completer.isCompleted) {
        completer.complete(seen.values.toList(growable: false));
      }
    });
    return completer.future;
  }

  /// Whether a scan result looks like a Vectronix Terrapin X. Matches
  /// either the service UUID or the well-known device-name prefixes.
  static bool looksLikeTerrapin(ScanResult r) => _looksLikeTerrapin(r);

  static bool _looksLikeTerrapin(ScanResult r) {
    if (r.advertisementData.serviceUuids
        .contains(kVectronixTerrapinServiceUuid)) {
      return true;
    }
    final name = r.device.platformName.trim().toLowerCase();
    if (name.isEmpty) return false;
    return name.startsWith('terrapin') ||
        name.startsWith('tpx-') ||
        name.startsWith('tpx ') ||
        name.startsWith('vectronix') ||
        name.contains('terrapin');
  }

  /// Connect to [device], discover services, and subscribe to the
  /// Vectronix notify characteristic. Throws [BleException] on failure.
  Future<void> connect(BluetoothDevice device) async {
    await disconnect();
    _device = device;
    notifyListeners();
    await _ble.connect(device);
    _connSub = _ble.connectionStream(device).listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        // ignore: discarded_futures
        _stopStreaming();
        _device = null;
        notifyListeners();
      }
    });
    final services = await _discoverServices(device);
    final notifyChar = _findNotifyCharacteristic(services);
    if (notifyChar == null) {
      await _ble.disconnect(device);
      _device = null;
      notifyListeners();
      throw const BleException(
        "This device doesn't expose the Vectronix Terrapin range feed.",
      );
    }
    try {
      await notifyChar.setNotifyValue(true);
    } catch (e) {
      throw BleException(
        "Couldn't subscribe to range data on this Vectronix device.",
        cause: e,
      );
    }
    _charSub = notifyChar.lastValueStream.listen(_onFrame);
    _streaming = true;
    notifyListeners();
  }

  /// Drop the active subscription + connection. Idempotent.
  Future<void> disconnect() async {
    final d = _device;
    await _stopStreaming();
    if (d != null) {
      await _ble.disconnect(d);
    }
    _device = null;
    _last = null;
    notifyListeners();
  }

  Future<void> _stopStreaming() async {
    _streaming = false;
    await _charSub?.cancel();
    _charSub = null;
    await _connSub?.cancel();
    _connSub = null;
  }

  Future<List<BluetoothService>> _discoverServices(
    BluetoothDevice device,
  ) async {
    try {
      return await device.discoverServices();
    } catch (e) {
      throw BleException(
        "Couldn't read this device's services. Move closer and try again.",
        cause: e,
      );
    }
  }

  BluetoothCharacteristic? _findNotifyCharacteristic(
    List<BluetoothService> services,
  ) {
    for (final s in services) {
      if (s.serviceUuid != kVectronixTerrapinServiceUuid) continue;
      for (final c in s.characteristics) {
        if (c.characteristicUuid == kVectronixTerrapinNotifyCharUuid) {
          return c;
        }
      }
    }
    // Fallback: any notify characteristic on the Vectronix service.
    // Some firmware ships the notify characteristic under a slightly
    // different UUID — accept it if it's on the right service.
    for (final s in services) {
      if (s.serviceUuid != kVectronixTerrapinServiceUuid) continue;
      for (final c in s.characteristics) {
        if (c.properties.notify || c.properties.indicate) {
          return c;
        }
      }
    }
    return null;
  }

  void _onFrame(List<int> bytes) {
    final reading = parseLiveFrame(bytes);
    if (reading == null) return;
    _last = reading;
    notifyListeners();
    if (!_readings.isClosed) {
      _readings.add(reading);
    }
  }

  /// Parses a Vectronix Terrapin X live measurement frame. Visible for
  /// testing. Returns null on any parse failure (rather than throwing)
  /// to match the rest of the rangefinder adapters.
  ///
  /// Frame layout (little-endian, see file header):
  ///   bytes 0–1    0x56 0x58 ('VX' marker)
  ///   byte 2       uint8       message type (0x10 = range)
  ///   byte 3       uint8       unit flag (0=m, 1=yd)
  ///   bytes 4–5    uint16      LOS distance
  ///   bytes 6–7    int16       angle * 10 deg
  ///   bytes 8–9    uint16      azimuth * 10 deg (0–3600)
  ///   bytes 10–11  uint16      incline-corrected range
  ///   byte 12      uint8       status flags
  static RangefinderReading? parseLiveFrame(List<int> raw) {
    if (raw.length < 6) return null;
    if (raw[0] != 0x56 || raw[1] != 0x58) {
      // Not a 'VX' frame — Vectronix's GATT also carries config /
      // battery / ranging-status messages that we don't decode today.
      return null;
    }
    final bd = ByteData.sublistView(Uint8List.fromList(raw));
    try {
      final msgType = bd.getUint8(2);
      if (msgType != 0x10) return null; // not a range measurement push

      final unitFlag = bd.getUint8(3);
      if (unitFlag != 0 && unitFlag != 1) return null;
      final losRaw = bd.getUint16(4, Endian.little);

      double rangeYd;
      double rangeM;
      // Note: Terrapin X unit convention is 0 = metres (the device's
      // native, mil/LE units) and 1 = yards. Get this wrong and yards
      // and metres swap on the UI.
      if (unitFlag == 0) {
        rangeM = losRaw.toDouble();
        rangeYd = metresToYards(rangeM);
      } else {
        rangeYd = losRaw.toDouble();
        rangeM = yardsToMetres(rangeYd);
      }

      // Sanity gate. Terrapin X is rated to 2500 m ≈ 2734 yd to a
      // reflective target; published max-range tests stretch to ~3500
      // yd on cooperative targets. Reject anything outside a generous
      // 1 yd – 10,000 yd envelope.
      if (rangeYd < 1 || rangeYd > 10000) return null;

      double? angleDeg;
      if (raw.length >= 8) {
        final angleRaw = bd.getInt16(6, Endian.little);
        angleDeg = angleRaw / 10.0;
        // Clamp obviously-bogus angles. Terrapin X reports ±60° per
        // its mil-spec envelope, but we accept ±90° to be safe.
        if (angleDeg < -90 || angleDeg > 90) angleDeg = null;
      }

      double? azimuthDeg;
      if (raw.length >= 10) {
        final azRaw = bd.getUint16(8, Endian.little);
        // Some firmware ships 0xFFFF when the magnetometer hasn't
        // calibrated yet; treat as "no azimuth".
        if (azRaw != 0xFFFF) {
          final candidate = azRaw / 10.0;
          if (candidate >= 0 && candidate < 360.0001) {
            // Wrap any 360.0 to 0.0 for canonical 0–360 range.
            azimuthDeg = candidate >= 360 ? 0.0 : candidate;
          }
        }
      }

      double? icRangeYd;
      if (raw.length >= 12) {
        final icRaw = bd.getUint16(10, Endian.little);
        if (icRaw > 0) {
          icRangeYd = unitFlag == 0
              ? metresToYards(icRaw.toDouble())
              : icRaw.toDouble();
        }
      }

      return RangefinderReading(
        rangeYd: rangeYd,
        rangeM: rangeM,
        angleDeg: angleDeg,
        inclineCorrectedRangeYd: icRangeYd,
        azimuthDeg: azimuthDeg,
        vendor: 'vectronix',
        receivedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    // ignore: discarded_futures
    _stopStreaming();
    if (!_readings.isClosed) {
      // ignore: discarded_futures
      _readings.close();
    }
    super.dispose();
  }
}
