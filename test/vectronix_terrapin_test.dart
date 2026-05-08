// Smoke tests for the Vectronix Terrapin X live measurement frame
// parser. The frame is reverse-engineered from the Vectronix SDK PDF
// and competitor implementations (Applied Ballistics, Ballistic AE,
// Trasol). The Terrapin X is unique among LoadOut's rangefinders in
// reporting magnetic azimuth (compass bearing) alongside the LOS
// distance + incline angle — the parser handles all three channels.
//
// Reference frame layout (see lib/services/ble/vectronix_terrapin_service.dart):
//   bytes 0–1    0x56 0x58 ('VX' marker — Vectronix)
//   byte 2       uint8       message type (0x10 = range measurement)
//   byte 3       uint8       unit flag: 0 = metres, 1 = yards
//   bytes 4–5    uint16      LOS distance (declared unit, little-endian)
//   bytes 6–7    int16       incline angle * 10 (degrees, signed)
//   bytes 8–9    uint16      magnetic azimuth * 10 deg (0–3600)
//   bytes 10–11  uint16      incline-corrected range
//   byte 12      uint8       reserved / status flags

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/services/ble/vectronix_terrapin_service.dart';

/// Build a 13-byte Terrapin X live frame with the right header so the
/// parser accepts it. All optional fields default to "absent" sentinels
/// (0 / 0xFFFF for azimuth) so tests can selectively populate them.
Uint8List _buildVxFrame({
  int unitFlag = 0,
  int losRaw = 600,
  int angleTenthDeg = 0,
  int azimuthTenthDeg = 0xFFFF, // sentinel: no azimuth
  int icRangeRaw = 0,
  int statusByte = 0,
  int msgType = 0x10,
  int marker0 = 0x56,
  int marker1 = 0x58,
}) {
  final bd = ByteData(13);
  bd.setUint8(0, marker0);
  bd.setUint8(1, marker1);
  bd.setUint8(2, msgType);
  bd.setUint8(3, unitFlag);
  bd.setUint16(4, losRaw, Endian.little);
  bd.setInt16(6, angleTenthDeg, Endian.little);
  bd.setUint16(8, azimuthTenthDeg, Endian.little);
  bd.setUint16(10, icRangeRaw, Endian.little);
  bd.setUint8(12, statusByte);
  return bd.buffer.asUint8List();
}

void main() {
  group('VectronixTerrapinService.parseLiveFrame', () {
    test('returns null on short / empty frames', () {
      // Empty frame → null.
      expect(VectronixTerrapinService.parseLiveFrame(<int>[]), isNull);
      // 5 bytes is below the parser's minimum of 6.
      expect(
        VectronixTerrapinService.parseLiveFrame(
          const [0x56, 0x58, 0x10, 0x00, 0x58],
        ),
        isNull,
      );
    });

    test('returns null when the header / message-type byte is wrong', () {
      // 'VV' instead of 'VX' — wrong marker.
      final bad = _buildVxFrame(marker0: 0x56, marker1: 0x56, losRaw: 600);
      expect(
        VectronixTerrapinService.parseLiveFrame(bad),
        isNull,
        reason: 'wrong marker bytes must be rejected',
      );
      // Right marker but wrong message type (0x20 = battery, not range).
      final wrongMsg = _buildVxFrame(msgType: 0x20, losRaw: 600);
      expect(
        VectronixTerrapinService.parseLiveFrame(wrongMsg),
        isNull,
        reason: 'non-range message types must be skipped',
      );
    });

    test('rejects out-of-bounds distances (>10 km, <1)', () {
      // 12,000 m blows past the Terrapin X envelope (rated 2500 m, max
      // tested ~3500 yd). Must be rejected by the sanity gate.
      final overrange = _buildVxFrame(unitFlag: 0, losRaw: 12000);
      expect(VectronixTerrapinService.parseLiveFrame(overrange), isNull);
      // Zero range is also nonsensical (no laser return).
      final zero = _buildVxFrame(unitFlag: 0, losRaw: 0);
      expect(VectronixTerrapinService.parseLiveFrame(zero), isNull);
    });

    test('drops insane incline angle but keeps the range', () {
      // 200° is bogus — angle should be dropped, range still returned.
      final raw = _buildVxFrame(
        unitFlag: 1,
        losRaw: 800,
        angleTenthDeg: 2000,
      );
      final r = VectronixTerrapinService.parseLiveFrame(raw);
      expect(r, isNotNull);
      expect(r!.rangeYd, closeTo(800, 0.5));
      expect(r.angleDeg, isNull,
          reason: 'angle outside ±90° must be nulled by the parser');
    });

    test('parses a metres-only frame with LOS only', () {
      // unit=0 (m), LOS=750 m, no incline (0°), no azimuth (sentinel),
      // no IC range. Standard "ranged but no aux data" frame.
      final raw = _buildVxFrame(unitFlag: 0, losRaw: 750);
      final r = VectronixTerrapinService.parseLiveFrame(raw);
      expect(r, isNotNull);
      expect(r!.rangeM, closeTo(750, 0.5));
      // 750 m ≈ 820.2 yd
      expect(r.rangeYd, closeTo(820.2, 0.5));
      // Incline of 0° still surfaces as 0.0 (it's inside ±90°).
      expect(r.angleDeg, closeTo(0, 0.05));
      // Azimuth sentinel (0xFFFF) → null.
      expect(r.azimuthDeg, isNull);
      expect(r.inclineCorrectedRangeYd, isNull);
      expect(r.vendor, equals('vectronix'));
    });

    test('parses a yards frame with LOS + incline', () {
      // unit=1 (yd), LOS=900 yd, incline 12.5° up, no azimuth, no IC.
      final raw = _buildVxFrame(
        unitFlag: 1,
        losRaw: 900,
        angleTenthDeg: 125,
      );
      final r = VectronixTerrapinService.parseLiveFrame(raw);
      expect(r, isNotNull);
      expect(r!.rangeYd, closeTo(900, 0.5));
      // 900 yd ≈ 822.96 m
      expect(r.rangeM, closeTo(822.96, 0.5));
      expect(r.angleDeg, closeTo(12.5, 0.05));
      expect(r.hasIncline, isTrue);
      expect(r.azimuthDeg, isNull);
    });

    test('parses LOS + incline + magnetic azimuth (full Terrapin X frame)', () {
      // unit=0 (m), LOS=1200 m, incline -7.5° down, azimuth 287.3°
      // (West-Northwest), no IC range. Negative angle exercises the
      // signed-int16 path.
      final raw = _buildVxFrame(
        unitFlag: 0,
        losRaw: 1200,
        angleTenthDeg: -75,
        azimuthTenthDeg: 2873,
      );
      final r = VectronixTerrapinService.parseLiveFrame(raw);
      expect(r, isNotNull);
      expect(r!.rangeM, closeTo(1200, 0.5));
      expect(r.angleDeg, closeTo(-7.5, 0.05));
      expect(r.azimuthDeg, closeTo(287.3, 0.05),
          reason: 'magnetic azimuth must round-trip through *10 encoding');
      expect(r.hasAzimuth, isTrue);
      expect(r.vendor, equals('vectronix'));
    });

    test('uses the incline-corrected range when the device computed it', () {
      // unit=0 (m), LOS=1000 m, incline 30° down (steep — Alaska-style
      // hunting), IC range 866 m. The parser's job is just to surface
      // both fields; the Range Day quick-fill prefers the IC value
      // when it's present, so this test validates that the field
      // round-trips through metres → yards conversion correctly.
      // 866 m ≈ 947.06 yd
      final raw = _buildVxFrame(
        unitFlag: 0,
        losRaw: 1000,
        angleTenthDeg: -300,
        icRangeRaw: 866,
      );
      final r = VectronixTerrapinService.parseLiveFrame(raw);
      expect(r, isNotNull);
      expect(r!.rangeM, closeTo(1000, 0.5));
      expect(r.angleDeg, closeTo(-30, 0.05));
      expect(r.inclineCorrectedRangeYd, isNotNull);
      expect(r.inclineCorrectedRangeYd!, closeTo(947.06, 0.5),
          reason: 'IC range must convert metres → yards using the same '
              'helpers as the LOS field');
      // IC range should NOT equal LOS — that would mean the conversion
      // dropped the metric data.
      expect(r.inclineCorrectedRangeYd, isNot(closeTo(r.rangeYd, 1)));
    });
  });
}
