// FILE: lib/services/ble/bushnell_rangefinder_service.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Adapter for the Bushnell BLE-enabled rangefinder line:
//
//   - Bushnell Elite 1 Mile CONX
//   - Bushnell Forge 1500 / 1700 / 2000 (BLE variants)
//   - Bushnell Prime 1300 / 1700 (BLE variants)
//   - Bushnell Phantom 2 (golf, also exposes range over BLE)
//   - Bushnell Engage / Engage X
//
// Bushnell's BLE protocol is proprietary and undocumented — the company
// does not publish an SDK. The UUIDs and frame layout below come from
// publicly-circulated reverse-engineering work (golf-rangefinder and
// hunting-rangefinder hobby projects, packet captures from the Bushnell
// Connect / Bushnell Golf apps). Treat every constant in this file as
// best-effort until a real device validates it.
//
// v1 ships as scan-and-display-only — when the device pushes a
// measurement, we parse it and surface the value in the UI. We do not
// attempt to write configuration back to the device today.
//
// ============================================================================
// GATT details
// ============================================================================
// Bushnell appears to use a custom 128-bit UUID space. Different product
// generations report slightly different layouts; we accept any of the
// known variants and parse what we recognize.
//
//   Service UUID candidate A:   0000fff0-0000-1000-8000-00805f9b34fb
//   Notify char candidate A:    0000fff4-0000-1000-8000-00805f9b34fb
//   Write char candidate A:     0000fff3-0000-1000-8000-00805f9b34fb
//
//   Service UUID candidate B:   6e400001-b5a3-f393-e0a9-e50e24dcca9e
//   (Some Bushnells reuse Nordic UART-style UUIDs; the parser below
//   tolerates either family.)
//
// Frame format (range push, all little-endian):
//   byte 0       0x42   'B' marker
//   byte 1       uint8  unit flag: 0 = yards, 1 = metres
//   bytes 2–3    uint16 line-of-sight range (in declared unit)
//   byte 4       uint8  optional incline / status (varies by model)
//   bytes 5..n   reserved
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
// - Subscribes to a BLE GATT characteristic. The device pushes one frame
//   per laser fire once subscribed.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_service.dart';
import 'rangefinder_reading.dart';

// TODO(reverse-engineering): verify all Bushnell UUIDs against real
// hardware. The candidate-A family below is the most commonly observed
// in public packet captures, but Bushnell has shipped several generations
// across the Forge, Prime, and Engage lines that may use different
// transports.

/// Primary BLE service UUID seen in Bushnell rangefinder advertising
/// packets. The 0xFFF0 short-form UUID expanded to a full 128-bit GATT
/// UUID using the standard Bluetooth SIG base.
final Guid kBushnellPrimaryServiceUuid =
    Guid('0000fff0-0000-1000-8000-00805f9b34fb');

/// Notify characteristic for range push frames on the candidate-A
/// family of Bushnells.
final Guid kBushnellNotifyCharUuid =
    Guid('0000fff4-0000-1000-8000-00805f9b34fb');

/// Write characteristic on the candidate-A family. We don't write today;
/// reserved for future config push.
final Guid kBushnellWriteCharUuid =
    Guid('0000fff3-0000-1000-8000-00805f9b34fb');

/// Secondary service UUID: some Bushnell firmware reuses Nordic UART
/// UUIDs for their range push channel. We accept either when probing.
final Guid kBushnellSecondaryServiceUuid =
    Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e');

/// Adapter around a connected Bushnell rangefinder. Owns the GATT
/// subscription and exposes a [readings] stream.
class BushnellRangefinderService extends ChangeNotifier {
  BushnellRangefinderService(this._ble);

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

  /// One-shot scan filtered to Bushnell rangefinders. Bushnell's
  /// advertising packets are inconsistent across product lines, so we
  /// fall back on name matching ("Bushnell", "Forge", "Prime",
  /// "Phantom", "Engage", "Elite") for devices that don't include a
  /// service UUID in their broadcast packet.
  Future<List<ScanResult>> scanForBushnells({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final stream = await _ble.startScan(
      timeout: timeout,
      // Pre-filter to the candidate-A service UUID. Some Bushnells use
      // the secondary UUID, so we additionally fall back on name
      // matching after the scan returns.
      withServices: [kBushnellPrimaryServiceUuid],
    );
    final seen = <String, ScanResult>{};
    final completer = Completer<List<ScanResult>>();
    final sub = stream.listen((batch) {
      for (final r in batch) {
        if (_looksLikeBushnell(r)) {
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

  static bool looksLikeBushnell(ScanResult r) => _looksLikeBushnell(r);

  static bool _looksLikeBushnell(ScanResult r) {
    if (r.advertisementData.serviceUuids
        .contains(kBushnellPrimaryServiceUuid)) {
      return true;
    }
    if (r.advertisementData.serviceUuids
        .contains(kBushnellSecondaryServiceUuid)) {
      // Secondary-service hits also need a name check — Nordic UART is
      // shared with many devices.
      // fall through to name check
    }
    final name = r.device.platformName.trim().toLowerCase();
    if (name.isEmpty) return false;
    const bushnellMarkers = [
      'bushnell',
      'forge',
      'prime',
      'phantom',
      'engage',
      'elite',
    ];
    return bushnellMarkers.any(name.contains);
  }

  /// Connect to [device], discover services, and subscribe to the range
  /// notify characteristic. We try the candidate-A service UUID first;
  /// if not present, fall back to scanning every notify characteristic
  /// on the device for one whose data parses as a Bushnell frame.
  /// Throws [BleException] on failure.
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
        "This device doesn't expose a Bushnell range feed we recognize.",
      );
    }
    try {
      await notifyChar.setNotifyValue(true);
    } catch (e) {
      throw BleException(
        "Couldn't subscribe to range data on this Bushnell.",
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

  /// Find a notify characteristic on the candidate Bushnell services.
  /// Tries candidate-A (0xFFF0 family) first, then falls back on
  /// candidate-B (Nordic UART). Returns the first matching notify
  /// characteristic.
  BluetoothCharacteristic? _findNotifyCharacteristic(
    List<BluetoothService> services,
  ) {
    // First pass: exact UUID match on the primary candidate.
    for (final s in services) {
      if (s.serviceUuid != kBushnellPrimaryServiceUuid) continue;
      for (final c in s.characteristics) {
        if (c.characteristicUuid == kBushnellNotifyCharUuid) {
          return c;
        }
      }
    }
    // Second pass: secondary candidate (Nordic UART).
    for (final s in services) {
      if (s.serviceUuid != kBushnellSecondaryServiceUuid) continue;
      for (final c in s.characteristics) {
        if (c.properties.notify || c.properties.indicate) {
          return c;
        }
      }
    }
    // Third pass: any notify char on the candidate-A service that we
    // didn't catch above.
    for (final s in services) {
      if (s.serviceUuid != kBushnellPrimaryServiceUuid) continue;
      for (final c in s.characteristics) {
        if (c.properties.notify || c.properties.indicate) {
          return c;
        }
      }
    }
    return null;
  }

  void _onFrame(List<int> bytes) {
    final reading = parseBushnellFrame(bytes);
    if (reading == null) return;
    _last = reading;
    notifyListeners();
    if (!_readings.isClosed) {
      _readings.add(reading);
    }
  }

  /// Parses a Bushnell range push frame. Visible for testing. Returns
  /// null on any parse failure.
  ///
  /// Frame layout (best-known reverse-engineering):
  ///   byte 0       0x42   'B' marker
  ///   byte 1       uint8  unit flag (0=yd, 1=m)
  ///   bytes 2–3    uint16 LOS range (in declared unit)
  ///   byte 4       uint8  optional incline / status flags
  static RangefinderReading? parseBushnellFrame(List<int> raw) {
    if (raw.length < 4) return null;
    final bd = ByteData.sublistView(Uint8List.fromList(raw));
    try {
      // Some Bushnell models prefix the frame with 0x42 ('B'); others
      // start straight with the unit byte. Sniff for both.
      int offset = 0;
      if (raw[0] == 0x42 && raw.length >= 5) {
        offset = 1;
      }
      if (raw.length < offset + 3) return null;
      final unitFlag = bd.getUint8(offset);
      // Reject obviously-out-of-range unit flag values to avoid parsing
      // a frame that isn't a range push at all.
      if (unitFlag != 0 && unitFlag != 1) return null;
      final losRaw = bd.getUint16(offset + 1, Endian.little);
      double rangeYd;
      double rangeM;
      if (unitFlag == 1) {
        rangeM = losRaw.toDouble();
        rangeYd = metresToYards(rangeM);
      } else {
        rangeYd = losRaw.toDouble();
        rangeM = yardsToMetres(rangeYd);
      }

      // Older Bushnells don't include incline; leave angleDeg null.
      double? angleDeg;
      if (raw.length >= offset + 4) {
        final flags = bd.getUint8(offset + 3);
        // Some Forge / Engage X firmware packs a signed incline tick in
        // this byte (deg, signed 8-bit). 0xFF = "no incline". Use it if
        // it looks plausible.
        if (flags != 0xFF && flags != 0x00) {
          final signed = flags > 127 ? flags - 256 : flags;
          if (signed >= -60 && signed <= 60) {
            angleDeg = signed.toDouble();
          }
        }
      }

      // Sanity gate. Bushnell line: 5–1760 yd typical, Forge 2000 caps
      // at 2000 yd. 3500 yd is a generous upper bound.
      if (rangeYd < 1 || rangeYd > 3500) return null;

      return RangefinderReading(
        rangeYd: rangeYd,
        rangeM: rangeM,
        angleDeg: angleDeg,
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
