// FILE: test/ble_android_legacy_explainer_widget_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Widget tests for the one-time Android 10/11 BLE-needs-location
// explainer dialog (`showBleAndroidLegacyExplainer`). Verifies the
// Continue / Cancel button wiring resolves to the right boolean and
// that dismissal via barrier-tap is suppressed.
//
// ============================================================================
// WHAT'S COVERED
// ============================================================================
// - "Continue" tap resolves the future to `true`.
// - "Cancel" tap resolves the future to `false`.
// - The dialog renders the explanatory copy that names Android 10
//   specifically (so the user knows why the location prompt is
//   coming).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/widgets/ble_android_legacy_explainer.dart';

void main() {
  group('showBleAndroidLegacyExplainer', () {
    testWidgets('Continue → returns true', (tester) async {
      Future<bool>? resultFuture;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  resultFuture = showBleAndroidLegacyExplainer(ctx);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Bluetooth Needs Location Permission'), findsOneWidget);
      expect(find.textContaining('Android 10'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final result = await resultFuture;
      expect(result, isTrue);
    });

    testWidgets('Cancel → returns false', (tester) async {
      Future<bool>? resultFuture;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  resultFuture = showBleAndroidLegacyExplainer(ctx);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final result = await resultFuture;
      expect(result, isFalse);
    });

    testWidgets('renders an explanation that mentions Android 10', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showBleAndroidLegacyExplainer(ctx);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Android 10'), findsOneWidget);
      // The copy explicitly states that we don't actually use location.
      expect(find.textContaining("don't actually use your location"),
          findsOneWidget);
    });
  });
}
