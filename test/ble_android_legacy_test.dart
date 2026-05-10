// FILE: test/ble_android_legacy_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Unit tests for the Android 10/11 BLE-legacy code path on `BleService`:
// the SDK-int reader, the "have we shown the explainer?" pref, and the
// `isAndroidLegacyBleStack` helper used by `device_scan_screen.dart` and
// the future entry points to decide whether to surface the one-time
// location-permission explainer.
//
// We use `BleService.forTesting(...)` to inject fakes for every
// platform-channel call so the tests run on any host without a real
// Android device. The fakes are simple closures that return canned
// values.
//
// ============================================================================
// WHAT'S COVERED
// ============================================================================
// - `readAndroidSdkInt` returns the injected SDK level on first call.
// - The reader is cached — second call doesn't re-invoke the closure.
// - `isAndroidLegacyBleStack` is true on API 29 / 30, false on API 31.
// - `hasSeenAndroidLegacyExplainer` and `markAndroidLegacyExplainerSeen`
//   round-trip through the injected reader / writer.
// - The explainer "seen" defaults to false on a fresh service.

import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/services/ble/ble_service.dart';

void main() {
  group('BleService.forTesting — Android legacy BLE stack', () {
    test('readAndroidSdkInt returns the injected value', () async {
      var calls = 0;
      final svc = BleService.forTesting(
        androidSdkIntReader: () async {
          calls++;
          return 29;
        },
        explainerSeenReader: () async => false,
        explainerSeenWriter: () async {},
      );
      expect(await svc.readAndroidSdkInt(), 29);
      expect(calls, 1);
    });

    test('readAndroidSdkInt caches the result on subsequent calls', () async {
      var calls = 0;
      final svc = BleService.forTesting(
        androidSdkIntReader: () async {
          calls++;
          return 30;
        },
        explainerSeenReader: () async => false,
        explainerSeenWriter: () async {},
      );
      await svc.readAndroidSdkInt();
      await svc.readAndroidSdkInt();
      await svc.readAndroidSdkInt();
      expect(calls, 1, reason: 'SDK int should be read once and cached');
    });

    test('isAndroidLegacyBleStack: true on API 29', () async {
      final svc = BleService.forTesting(
        androidSdkIntReader: () async => 29,
        explainerSeenReader: () async => false,
        explainerSeenWriter: () async {},
      );
      expect(await svc.isAndroidLegacyBleStack(), isTrue);
    });

    test('isAndroidLegacyBleStack: true on API 30', () async {
      final svc = BleService.forTesting(
        androidSdkIntReader: () async => 30,
        explainerSeenReader: () async => false,
        explainerSeenWriter: () async {},
      );
      expect(await svc.isAndroidLegacyBleStack(), isTrue);
    });

    test('isAndroidLegacyBleStack: false on API 31 (Android 12)', () async {
      final svc = BleService.forTesting(
        androidSdkIntReader: () async => 31,
        explainerSeenReader: () async => false,
        explainerSeenWriter: () async {},
      );
      expect(await svc.isAndroidLegacyBleStack(), isFalse);
    });

    test('isAndroidLegacyBleStack: false on null (non-Android)', () async {
      final svc = BleService.forTesting(
        androidSdkIntReader: () async => null,
        explainerSeenReader: () async => false,
        explainerSeenWriter: () async {},
      );
      expect(await svc.isAndroidLegacyBleStack(), isFalse);
    });
  });

  group('BleService.forTesting — explainer "seen" round-trip', () {
    test('hasSeenAndroidLegacyExplainer returns the injected value', () async {
      final svc = BleService.forTesting(
        androidSdkIntReader: () async => 29,
        explainerSeenReader: () async => true,
        explainerSeenWriter: () async {},
      );
      expect(await svc.hasSeenAndroidLegacyExplainer(), isTrue);
    });

    test('hasSeenAndroidLegacyExplainer defaults to false on fresh service',
        () async {
      final svc = BleService.forTesting(
        androidSdkIntReader: () async => 29,
        explainerSeenReader: () async => false,
        explainerSeenWriter: () async {},
      );
      expect(await svc.hasSeenAndroidLegacyExplainer(), isFalse);
    });

    test('markAndroidLegacyExplainerSeen invokes the writer', () async {
      var writes = 0;
      final svc = BleService.forTesting(
        androidSdkIntReader: () async => 29,
        explainerSeenReader: () async => false,
        explainerSeenWriter: () async {
          writes++;
        },
      );
      await svc.markAndroidLegacyExplainerSeen();
      expect(writes, 1);
    });
  });
}
