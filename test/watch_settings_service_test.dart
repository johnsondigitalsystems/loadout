// FILE: test/watch_settings_service_test.dart
//
// Verifies the watch-side shot-capture sensitivity preset table and
// wire-format round-trip. Persistence + bridge plumbing are exercised
// implicitly by the in-memory SharedPreferences mock; we check the
// observable contract: same wire string in, same threshold + sustained
// window out.

import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/services/watch_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ShotCaptureSensitivity', () {
    test('wire values match CLAUDE.md §15 verbatim', () {
      expect(ShotCaptureSensitivity.off.wireValue, 'off');
      expect(ShotCaptureSensitivity.low.wireValue, 'low');
      expect(ShotCaptureSensitivity.medium.wireValue, 'medium');
      expect(ShotCaptureSensitivity.high.wireValue, 'high');
    });

    test('threshold + sustained-peak table matches the spec', () {
      // Off -> motion detect disabled, both fields null.
      expect(ShotCaptureSensitivity.off.thresholdG, isNull);
      expect(ShotCaptureSensitivity.off.sustainedPeakMs, isNull);

      // Low / medium / high — exact values from the spec table.
      expect(ShotCaptureSensitivity.low.thresholdG, 8.0);
      expect(ShotCaptureSensitivity.low.sustainedPeakMs, 80);

      expect(ShotCaptureSensitivity.medium.thresholdG, 5.0);
      expect(ShotCaptureSensitivity.medium.sustainedPeakMs, 50);

      expect(ShotCaptureSensitivity.high.thresholdG, 3.0);
      expect(ShotCaptureSensitivity.high.sustainedPeakMs, 30);
    });

    test('fromWire round-trips every preset', () {
      for (final v in ShotCaptureSensitivity.values) {
        expect(ShotCaptureSensitivity.fromWire(v.wireValue), v);
      }
    });

    test('fromWire returns null for unknown / null inputs', () {
      expect(ShotCaptureSensitivity.fromWire(null), isNull);
      expect(ShotCaptureSensitivity.fromWire(''), isNull);
      expect(ShotCaptureSensitivity.fromWire('extreme'), isNull);
      expect(ShotCaptureSensitivity.fromWire('OFF'), isNull, reason: 'case sensitive');
    });
  });

  group('WatchSettingsService', () {
    test('defaults to medium when no pref is stored', () async {
      final svc = WatchSettingsService();
      // Allow the async _load to settle.
      await Future<void>.delayed(Duration.zero);
      expect(svc.sensitivity, ShotCaptureSensitivity.medium);
    });

    test('setSensitivity persists the wire value', () async {
      final svc = WatchSettingsService();
      await svc.setSensitivity(ShotCaptureSensitivity.high);
      expect(svc.sensitivity, ShotCaptureSensitivity.high);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(kShotCaptureSensitivityPrefKey),
        ShotCaptureSensitivity.high.wireValue,
      );
    });

    test('restores stored sensitivity on construction', () async {
      SharedPreferences.setMockInitialValues({
        kShotCaptureSensitivityPrefKey: 'low',
      });
      final svc = WatchSettingsService();
      // Allow the async _load to settle.
      await Future<void>.delayed(Duration.zero);
      expect(svc.sensitivity, ShotCaptureSensitivity.low);
    });

    test('setSensitivity is a no-op when value matches current', () async {
      final svc = WatchSettingsService();
      var notifyCount = 0;
      svc.addListener(() => notifyCount++);
      await svc.setSensitivity(ShotCaptureSensitivity.medium);
      // Default is medium → setting medium again should not notify.
      expect(notifyCount, 0);
      await svc.setSensitivity(ShotCaptureSensitivity.high);
      expect(notifyCount, 1);
    });
  });
}
