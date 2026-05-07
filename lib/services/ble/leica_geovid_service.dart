// FILE: lib/services/ble/leica_geovid_service.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Adapter for the Leica Geovid Pro / Rangemaster line of laser
// rangefinder binoculars:
//
//   - Leica Geovid Pro 32 (8x32 / 10x32)
//   - Leica Geovid Pro 42 (8x42 / 10x42)
//   - Leica Geovid Pro AB+ (Applied Ballistics integration)
//   - Leica Rangemaster CRF Pro (some firmware revisions)
//
// Leica pairs these devices with their "Leica Ballistics" / "Leica
// Hunting" mobile apps; the BLE protocol is documented in fragments
// across Leica's developer pages and various reverse-engineering
// projects. We surface scan-and-display only for v1 — the user fires
// the laser, we display the range and (when present) the
// incline-corrected range.
//
// ============================================================================
// GATT details
// ============================================================================
// Leica Geovid Pro firmware uses a custom 128-bit UUID space. Variants
// exist between the AB+ (Applied Ballistics) and standard models:
//
//   Service UUID:               7c2b0001-bbe6-4d8b-8e4c-9f4f3c5d2a6e
//   Notify characteristic:      7c2b0002-bbe6-4d8b-8e4c-9f4f3c5d2a6e
//   Write characteristic:       7c2b0003-bbe6-4d8b-8e4c-9f4f3c5d2a6e
//
// Frame format (range push, little-endian):
//   bytes 0–1    0x4C 0x47   'LG' marker (Leica Geovid)
//   byte 2       uint8       message type (0x01 = range)
//   byte 3       uint8       unit flag: 0 = metres, 1 = yards
//   bytes 4–5    uint16      LOS range (in declared unit)
//   bytes 6–7    int16       angle * 10 (degrees)
//   bytes 8–9    uint16      incline-corrected range
//   byte 10      uint8       status flags
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/devices/devices_screen.dart        (status + connect)
// - lib/screens/devices/device_scan_screen.dart    (scan flow)
// - lib/screens/range_day/range_day_detail_screen.dart (Use last reading)
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Subscribes to a BLE GATT characteristic.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_service.dart';
import 'rangefinder_reading.dart';

// TODO(reverse-engineering): verify all Leica UUIDs and frame offsets
// against real hardware. The constants below are best-effort guesses
// from publicly-circulated reverse-engineering work; the official
// Leica Hunting app uses encrypted comms in some modes, and this
// adapter handles unencrypted range pushes only.

/// Service UUID broadcast by Leica Geovid Pro / Rangemaster CRF Pro.
final Guid kLeicaGeovidServiceUuid =
    Guid('7c2b0001-bbe6-4d8b-8e4c-9f4f3c5d2a6e');

/// Notify characteristic for range push frames.
final Guid kLeicaGeovidNotifyCharUuid =
    Guid('7c2b0002-bbe6-4d8b-8e4c-9f4f3c5d2a6e');

/// Write characteristic for config push. Reserved for future use.
final Guid kLeicaGeovidWriteCharUuid =
    Guid('7c2b0003-bbe6-4d8b-8e4c-9f4f3c5d2a6e');

/// Adapter around a connected Leica Geovid Pro / Rangemaster. Owns
/// the GATT subscription and exposes a [readings] stream.
class LeicaGeovidService extends ChangeNotifier {
  LeicaGeovidService(this._ble);

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

  Stream<RangefinderReading> get readings => _readings.stream;

  /// One-shot scan filtered to Leica Geovid / Rangemaster devices.
  /// Falls back on name matching ("Leica", "Geovid", "Rangemaster")
  /// when the service UUID isn't broadcast.
  Future<List<ScanResult>> scanForLeica({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final stream = await _ble.startScan(
      timeout: timeout,
      withServices: [kLeicaGeovidServiceUuid],
    );
    final seen = <String, ScanResult>{};
    final completer = Completer<List<ScanResult>>();
    final sub = stream.listen((batch) {
      for (final r in batch) {
        if (_looksLikeLeica(r)) {
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

  static bool looksLikeLeica(ScanResult r) => _looksLikeLeica(r);

  static bool _looksLikeLeica(ScanResult r) {
    if (r.advertisementData.serviceUuids.contains(kLeicaGeovidServiceUuid)) {
      return true;
    }
    final name = r.device.platformName.trim().toLowerCase();
    return name.startsWith('leica') ||
        name.startsWith('geovid') ||
        name.contains('rangemaster') ||
        name.contains('crf');
  }

  /// Connect to [device], discover services, and subscribe to the range
  /// notify characteristic. Throws [BleException] on failure.
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
        "This device doesn't expose the Leica Geovid range feed.",
      );
    }
    try {
      await notifyChar.setNotifyValue(true);
    } catch (e) {
      throw BleException(
        "Couldn't subscribe to range data on this Leica device.",
        cause: e,
      );
    }
    _charSub = notifyChar.lastValueStream.listen(_onFrame);
    _streaming = true;
    notifyListeners();
  }

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
      if (s.serviceUuid != kLeicaGeovidServiceUuid) continue;
      for (final c in s.characteristics) {
        if (c.characteristicUuid == kLeicaGeovidNotifyCharUuid) {
          return c;
        }
      }
    }
    // Fallback: any notify characteristic on the Leica service.
    for (final s in services) {
      if (s.serviceUuid != kLeicaGeovidServiceUuid) continue;
      for (final c in s.characteristics) {
        if (c.properties.notify || c.properties.indicate) {
          return c;
        }
      }
    }
    return null;
  }

  void _onFrame(List<int> bytes) {
    final reading = parseLeicaFrame(bytes);
    if (reading == null) return;
    _last = reading;
    notifyListeners();
    if (!_readings.isClosed) {
      _readings.add(reading);
    }
  }

  /// Parses a Leica Geovid range push frame. Visible for testing.
  /// Returns null on any parse failure.
  ///
  /// Frame layout (little-endian):
  ///   bytes 0–1    0x4C 0x47   'LG' marker
  ///   byte 2       uint8       message type (0x01 = range)
  ///   byte 3       uint8       unit flag (0=m, 1=yd)
  ///   bytes 4–5    uint16      LOS range
  ///   bytes 6–7    int16       angle * 10 deg
  ///   bytes 8–9    uint16      incline-corrected range
  ///   byte 10      uint8       status flags
  static RangefinderReading? parseLeicaFrame(List<int> raw) {
    if (raw.length < 6) return null;
    if (raw[0] != 0x4C || raw[1] != 0x47) {
      // Not an 'LG' frame — Leica's GATT also carries config / battery
      // / status messages. Skip.
      return null;
    }
    final bd = ByteData.sublistView(Uint8List.fromList(raw));
    try {
      final msgType = bd.getUint8(2);
      if (msgType != 0x01) return null; // not a range push

      final unitFlag = bd.getUint8(3);
      if (unitFlag != 0 && unitFlag != 1) return null;
      final losRaw = bd.getUint16(4, Endian.little);

      double rangeYd;
      double rangeM;
      // Note: Leica's unit convention is INVERSE of Sig/Vortex — 0 = m,
      // 1 = yd. Get this wrong and yards/metres flip on the UI.
      if (unitFlag == 0) {
        rangeM = losRaw.toDouble();
        rangeYd = metresToYards(rangeM);
      } else {
        rangeYd = losRaw.toDouble();
        rangeM = yardsToMetres(rangeYd);
      }

      double? angleDeg;
      if (raw.length >= 8) {
        final angleRaw = bd.getInt16(6, Endian.little);
        angleDeg = angleRaw / 10.0;
        if (angleDeg < -90 || angleDeg > 90) angleDeg = null;
      }

      double? icRangeYd;
      if (raw.length >= 10) {
        final icRaw = bd.getUint16(8, Endian.little);
        if (icRaw > 0) {
          icRangeYd = unitFlag == 0
              ? metresToYards(icRaw.toDouble())
              : icRaw.toDouble();
        }
      }

      // Sanity gate. Geovid Pro: typical 2700 yd advertised, 3000+ on
      // some models. 4000 is a generous upper bound.
      if (rangeYd < 1 || rangeYd > 4500) return null;

      return RangefinderReading(
        rangeYd: rangeYd,
        rangeM: rangeM,
        angleDeg: angleDeg,
        inclineCorrectedRangeYd: icRangeYd,
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
