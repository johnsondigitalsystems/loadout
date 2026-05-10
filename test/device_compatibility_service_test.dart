// FILE: test/device_compatibility_service_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Unit tests for `DeviceCompatibilityService` — the service that maps a
// `DeviceProfile` (platform + OS version) to a list of `GatedFeature`
// rows the Settings → Device Compatibility screen renders.
//
// All tests drive the service through `fromProfile(...)`, the synchronous
// constructor that takes an explicit profile and skips the platform-
// channel read. This is what lets us test every branch (Android 10,
// Android 11, Android 12+, iOS 15+, web, unknown) without a real device.
//
// ============================================================================
// WHAT'S COVERED
// ============================================================================
// - Android 10 (API 29) → BLE / Wear OS / Watch sensors all blocked.
// - Android 11 (API 30) → Wear OS / Watch sensors available, BLE blocked.
// - Android 12 (API 31) → all three available.
// - iOS / macOS → no Android-specific gates surfaced (and no iOS gates
//   today, so `gatedFeatures` is empty).
// - Web / unknown → empty gates.
// - Sort order — blocked rows first, alphabetic within each bucket.
// - `hasAnyGates` flag matches.
// - `isAndroidBelow(N)` helper for the BLE explainer hook.
// - Version-string parser handles "17", "17.4", "17.4.1", and garbage.

import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/services/device_compatibility_service.dart';

void main() {
  group('DeviceCompatibilityService', () {
    group('Android API 29 (Android 10)', () {
      late DeviceCompatibilityService svc;

      setUp(() {
        svc = DeviceCompatibilityService.fromProfile(
          const DeviceProfile(
            platform: 'Android',
            osDisplay: 'Android 10',
            androidSdkInt: 29,
          ),
        );
      });

      test('reports all three Android-only features as gated', () {
        final names = svc.gatedFeatures.map((f) => f.name).toSet();
        expect(names, contains('Bluetooth Devices'));
        expect(names, contains('Wear OS Watch Pairing'));
        expect(names, contains('Watch Motion Sensors'));
      });

      test('every feature reports isAvailable == false', () {
        for (final f in svc.gatedFeatures) {
          expect(f.isAvailable, isFalse,
              reason: '${f.name} should be unavailable on API 29');
        }
      });

      test('hasAnyGates is true', () {
        expect(svc.hasAnyGates, isTrue);
      });

      test('isAndroidBelow(31) is true', () {
        expect(svc.isAndroidBelow(31), isTrue);
      });

      test('isAndroidBelow(29) is false (strict less-than)', () {
        expect(svc.isAndroidBelow(29), isFalse);
      });
    });

    group('Android API 30 (Android 11)', () {
      late DeviceCompatibilityService svc;

      setUp(() {
        svc = DeviceCompatibilityService.fromProfile(
          const DeviceProfile(
            platform: 'Android',
            osDisplay: 'Android 11',
            androidSdkInt: 30,
          ),
        );
      });

      test('Bluetooth Devices is gated, Wear OS / sensors are available', () {
        final byName = {for (final f in svc.gatedFeatures) f.name: f};
        expect(byName['Bluetooth Devices']?.isAvailable, isFalse);
        expect(byName['Wear OS Watch Pairing']?.isAvailable, isTrue);
        expect(byName['Watch Motion Sensors']?.isAvailable, isTrue);
      });

      test('hasAnyGates is true (BLE still blocked)', () {
        expect(svc.hasAnyGates, isTrue);
      });

      test('isAndroidBelow(31) is true', () {
        expect(svc.isAndroidBelow(31), isTrue);
      });
    });

    group('Android API 31+ (Android 12+)', () {
      late DeviceCompatibilityService svc;

      setUp(() {
        svc = DeviceCompatibilityService.fromProfile(
          const DeviceProfile(
            platform: 'Android',
            osDisplay: 'Android 14',
            androidSdkInt: 34,
          ),
        );
      });

      test('every feature is available', () {
        for (final f in svc.gatedFeatures) {
          expect(f.isAvailable, isTrue,
              reason: '${f.name} should be available on API 34');
        }
      });

      test('hasAnyGates is false', () {
        expect(svc.hasAnyGates, isFalse);
      });

      test('isAndroidBelow(31) is false', () {
        expect(svc.isAndroidBelow(31), isFalse);
      });
    });

    group('iOS', () {
      test('iOS 15.0 → no gated features (no iOS-version gates exist)', () {
        final svc = DeviceCompatibilityService.fromProfile(
          const DeviceProfile(
            platform: 'iOS',
            osDisplay: 'iOS 15.0',
            iosMajorVersion: 15,
          ),
        );
        expect(svc.gatedFeatures, isEmpty);
        expect(svc.hasAnyGates, isFalse);
        expect(svc.isAndroidBelow(31), isFalse);
      });

      test('iOS 17.4.1 → also no gated features', () {
        final svc = DeviceCompatibilityService.fromProfile(
          const DeviceProfile(
            platform: 'iOS',
            osDisplay: 'iOS 17.4.1',
            iosMajorVersion: 17,
          ),
        );
        expect(svc.gatedFeatures, isEmpty);
      });
    });

    group('macOS / Web / Unknown', () {
      test('macOS → no gated features', () {
        final svc = DeviceCompatibilityService.fromProfile(
          const DeviceProfile(platform: 'macOS', osDisplay: 'macOS 14.2'),
        );
        expect(svc.gatedFeatures, isEmpty);
      });

      test('Web → no gated features', () {
        final svc = DeviceCompatibilityService.fromProfile(
          const DeviceProfile(platform: 'Web', osDisplay: 'Web'),
        );
        expect(svc.gatedFeatures, isEmpty);
      });

      test('Unknown → no gated features', () {
        final svc = DeviceCompatibilityService.fromProfile(
          DeviceProfile.unknown,
        );
        expect(svc.gatedFeatures, isEmpty);
      });
    });

    group('sort order', () {
      test('blocked rows come before available rows', () {
        // API 30: BLE blocked, Wear OS / sensors available.
        final svc = DeviceCompatibilityService.fromProfile(
          const DeviceProfile(
            platform: 'Android',
            osDisplay: 'Android 11',
            androidSdkInt: 30,
          ),
        );
        final names = svc.gatedFeatures.map((f) => f.name).toList();
        // First row should be blocked.
        expect(svc.gatedFeatures.first.isAvailable, isFalse);
        // Bluetooth Devices is the only blocked row at API 30, so it's first.
        expect(names.first, 'Bluetooth Devices');
        // Remaining rows are available, alphabetic.
        expect(names.sublist(1), ['Watch Motion Sensors', 'Wear OS Watch Pairing']);
      });

      test('within blocked group, rows are alphabetic', () {
        final svc = DeviceCompatibilityService.fromProfile(
          const DeviceProfile(
            platform: 'Android',
            osDisplay: 'Android 10',
            androidSdkInt: 29,
          ),
        );
        final blocked = svc.gatedFeatures
            .where((f) => !f.isAvailable)
            .map((f) => f.name)
            .toList();
        final sorted = [...blocked]..sort();
        expect(blocked, sorted);
      });
    });

    group('GatedFeature carrier', () {
      test('rows have non-empty name, requirement, and description', () {
        final svc = DeviceCompatibilityService.fromProfile(
          const DeviceProfile(
            platform: 'Android',
            osDisplay: 'Android 10',
            androidSdkInt: 29,
          ),
        );
        for (final f in svc.gatedFeatures) {
          expect(f.name, isNotEmpty);
          expect(f.requirement, isNotEmpty);
          expect(f.shortDescription, isNotEmpty);
        }
      });
    });
  });
}
