// FILE: test/device_compatibility_screen_widget_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Widget tests for `DeviceCompatibilityScreen` — verifies the three
// rendering modes:
//
//   * Android 10 → blocked rows render with the "Requires Android 11+"
//     / "Requires Android 12+" copy and the "you're on Android 10"
//     banner.
//   * Android 12+ → "All Features Run On This Device" empty state.
//   * iOS → empty state too (no iOS-version gates today).
//
// ============================================================================
// WHAT'S COVERED
// ============================================================================
// - The OS-version banner at the top reads from `DeviceProfile.osDisplay`.
// - Blocked rows on Android 10 render the feature names, the
//   requirement copy, and the short description.
// - Modern devices see the "All features run on this device" card and
//   not the requirement rows.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/screens/settings/device_compatibility_screen.dart';
import 'package:loadout/services/device_compatibility_service.dart';
import 'package:provider/provider.dart';

void main() {
  Widget buildHarness(DeviceCompatibilityService svc) {
    return MaterialApp(
      home: Provider<DeviceCompatibilityService>.value(
        value: svc,
        child: const DeviceCompatibilityScreen(),
      ),
    );
  }

  group('DeviceCompatibilityScreen — Android 10', () {
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

    testWidgets('shows the OS-version banner', (tester) async {
      await tester.pumpWidget(buildHarness(svc));
      await tester.pumpAndSettle();
      expect(find.text('Android 10'), findsOneWidget);
      expect(find.text("You're On"), findsOneWidget);
    });

    testWidgets('lists every gated feature', (tester) async {
      await tester.pumpWidget(buildHarness(svc));
      await tester.pumpAndSettle();
      expect(find.text('Bluetooth Devices'), findsOneWidget);
      expect(find.text('Wear OS Watch Pairing'), findsOneWidget);
      expect(find.text('Watch Motion Sensors'), findsOneWidget);
    });

    testWidgets('renders the requirement copy', (tester) async {
      await tester.pumpWidget(buildHarness(svc));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Requires Android 12 or newer'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Requires Android 11 or newer'),
        findsAtLeast(1),
      );
    });

    testWidgets('shows the "Requires a Newer OS Version" section header',
        (tester) async {
      await tester.pumpWidget(buildHarness(svc));
      await tester.pumpAndSettle();
      expect(
        find.text('REQUIRES A NEWER OS VERSION'),
        findsOneWidget,
      );
    });
  });

  group('DeviceCompatibilityScreen — Android 12+', () {
    testWidgets('renders the "All Features Run" empty state', (tester) async {
      final svc = DeviceCompatibilityService.fromProfile(
        const DeviceProfile(
          platform: 'Android',
          osDisplay: 'Android 14',
          androidSdkInt: 34,
        ),
      );
      await tester.pumpWidget(buildHarness(svc));
      await tester.pumpAndSettle();
      expect(
        find.text('All Features Run on This Device'),
        findsOneWidget,
      );
      // Nothing should appear in the "Requires a Newer OS Version"
      // section because there's no such section to render.
      expect(find.text('REQUIRES A NEWER OS VERSION'), findsNothing);
    });
  });

  group('DeviceCompatibilityScreen — iOS', () {
    testWidgets('renders the "All Features Run" empty state', (tester) async {
      final svc = DeviceCompatibilityService.fromProfile(
        const DeviceProfile(
          platform: 'iOS',
          osDisplay: 'iOS 17.4',
          iosMajorVersion: 17,
        ),
      );
      await tester.pumpWidget(buildHarness(svc));
      await tester.pumpAndSettle();
      expect(
        find.text('All Features Run on This Device'),
        findsOneWidget,
      );
      expect(find.text('iOS 17.4'), findsOneWidget);
    });
  });
}
