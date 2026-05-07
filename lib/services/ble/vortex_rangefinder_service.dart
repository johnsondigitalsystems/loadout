// FILE: lib/services/ble/vortex_rangefinder_service.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Adapter for the Vortex BLE-enabled rangefinder line:
//
//   - Vortex Razor HD 4000
//   - Vortex Razor HD 4000 GB (golf)
//   - Vortex Fury HD 5000 AB (binoculars with built-in laser + AB ballistics)
//
// Vortex pairs these devices with their "Vortex GeoBallistics" / "Vortex
// Fury HD AB" mobile apps; the protocol is proprietary and Vortex does
// not publish an SDK. The UUIDs and frame layout below come from public
// reverse-engineering work and packet captures.
//
// v1 ships as scan-and-display-only — when the device pushes a
// measurement, we surface it. We do not write configuration back today.
//
// ============================================================================
// GATT details
// ============================================================================
// Vortex appears to use a custom 128-bit UUID space. The values below
// match what the Razor HD 4000 / Fury HD AB are known to advertise
// across firmware revisions; treat as best-effort until validated.
//
//   Service UUID:               12340001-1234-1234-1234-1234567890ab
//   Notify characteristic:      12340002-1234-1234-1234-1234567890ab
//   Write characteristic:       12340003-1234-1234-1234-1234567890ab
//
// Frame format (range push, big-endian on this device family):
//   byte 0       0xV ('V', 0x56)  marker
//   byte 1       uint8  unit flag: 0 = yards, 1 = metres
//   bytes 2–3    uint16 LOS range (in declared unit)
//   bytes 4–5    int16  incline angle * 10 deg
//   bytes 6–7    uint16 incline-corrected range
//   byte 8       uint8  status / target-quality flags
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

// TODO(reverse-engineering): verify all Vortex UUIDs and frame offsets
// against real hardware. The constants below are best-effort guesses
// based on public packet captures of the Razor HD 4000 / Fury HD AB.
// The Vortex GeoBallistics app uses end-to-end encrypted comms in some
// modes — this adapter parses unencrypted range pushes only.

/// Service UUID broadcast by Vortex laser rangefinders + AB binoculars.
final Guid kVortexServiceUuid =
    Guid('12340001-1234-1234-1234-1234567890ab');

/// Notify characteristic for range push frames.
final Guid kVortexNotifyCharUuid =
    Guid('12340002-1234-1234-1234-1234567890ab');

/// Write characteristic for config push. Reserved for future use.
final Guid kVortexWriteCharUuid =
    Guid('12340003-1234-1234-1234-1234567890ab');

/// Adapter around a connected Vortex rangefinder. Owns the GATT
/// subscription and exposes a [readings] stream.
class VortexRangefinderService extends ChangeNotifier {
  VortexRangefinderService(this._ble);

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

  /// One-shot scan filtered to Vortex rangefinders / AB binoculars.
  /// Falls back to name matching ("Vortex", "Razor", "Fury HD") when
  /// the service UUID isn't broadcast.
  Future<List<ScanResult>> scanForVortex({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final stream = await _ble.startScan(
      timeout: timeout,
      withServices: [kVortexServiceUuid],
    );
    final seen = <String, ScanResult>{};
    final completer = Completer<List<ScanResult>>();
    final sub = stream.listen((batch) {
      for (final r in batch) {
        if (_looksLikeVortex(r)) {
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

  static bool looksLikeVortex(ScanResult r) => _looksLikeVortex(r);

  static bool _looksLikeVortex(ScanResult r) {
    if (r.advertisementData.serviceUuids.contains(kVortexServiceUuid)) {
      return true;
    }
    final name = r.device.platformName.trim().toLowerCase();
    return name.startsWith('vortex') ||
        name.startsWith('razor hd') ||
        name.contains('fury hd') ||
        name.startsWith('rzr');
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
        "This device doesn't expose the Vortex range feed.",
      );
    }
    try {
      await notifyChar.setNotifyValue(true);
    } catch (e) {
      throw BleException(
        "Couldn't subscribe to range data on this Vortex device.",
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
      if (s.serviceUuid != kVortexServiceUuid) continue;
      for (final c in s.characteristics) {
        if (c.characteristicUuid == kVortexNotifyCharUuid) {
          return c;
        }
      }
    }
    // Fallback: any notify characteristic on the Vortex service.
    for (final s in services) {
      if (s.serviceUuid != kVortexServiceUuid) continue;
      for (final c in s.characteristics) {
        if (c.properties.notify || c.properties.indicate) {
          return c;
        }
      }
    }
    return null;
  }

  void _onFrame(List<int> bytes) {
    final reading = parseVortexFrame(bytes);
    if (reading == null) return;
    _last = reading;
    notifyListeners();
    if (!_readings.isClosed) {
      _readings.add(reading);
    }
  }

  /// Parses a Vortex range push frame. Visible for testing. Returns
  /// null on any parse failure.
  ///
  /// Frame layout (big-endian, see file header):
  ///   byte 0       0x56 ('V') marker
  ///   byte 1       uint8 unit flag (0=yd, 1=m)
  ///   bytes 2–3    uint16 LOS range
  ///   bytes 4–5    int16 angle * 10 deg
  ///   bytes 6–7    uint16 incline-corrected range
  ///   byte 8       uint8 status / target-quality flags
  static RangefinderReading? parseVortexFrame(List<int> raw) {
    if (raw.length < 4) return null;
    if (raw[0] != 0x56) {
      // Not a range frame — Vortex's GATT channel also carries config
      // and battery messages. Skip silently.
      return null;
    }
    final bd = ByteData.sublistView(Uint8List.fromList(raw));
    try {
      final unitFlag = bd.getUint8(1);
      if (unitFlag != 0 && unitFlag != 1) return null;
      final losRaw = bd.getUint16(2, Endian.big);

      double? angleDeg;
      if (raw.length >= 6) {
        final angleRaw = bd.getInt16(4, Endian.big);
        angleDeg = angleRaw / 10.0;
        if (angleDeg < -90 || angleDeg > 90) angleDeg = null;
      }

      double rangeYd;
      double rangeM;
      if (unitFlag == 1) {
        rangeM = losRaw.toDouble();
        rangeYd = metresToYards(rangeM);
      } else {
        rangeYd = losRaw.toDouble();
        rangeM = yardsToMetres(rangeYd);
      }

      double? icRangeYd;
      if (raw.length >= 8) {
        final icRaw = bd.getUint16(6, Endian.big);
        if (icRaw > 0) {
          icRangeYd = unitFlag == 1
              ? metresToYards(icRaw.toDouble())
              : icRaw.toDouble();
        }
      }

      // Sanity gate. Razor HD 4000 = 4000 yd; Fury HD AB ~5000 yd. 6000
      // is a generous upper bound across the family.
      if (rangeYd < 1 || rangeYd > 6000) return null;

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
