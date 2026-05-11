// FILE: test/hang_detector_test.dart
//
// Unit tests for `lib/services/hang_detector.dart`. Covers the
// public-API contract — start/stop is idempotent, debugSetEnabled
// short-circuits both detectors, the singleton's `isRunning` flag
// reflects state.
//
// We don't simulate a real UI hang here — that would require pumping
// a real WidgetsBinding through pathological synchronous work, which
// is fragile in `flutter_test`'s fake-async harness. The integration
// path (heartbeat math + spam-throttle) is exercised by manually
// triggering the test-crash button on a device build and watching the
// non-fatal land in Firebase Crashlytics.

import 'package:flutter_test/flutter_test.dart';

import 'package:loadout/services/crash_reporter.dart';
import 'package:loadout/services/hang_detector.dart';

void main() {
  group('HangDetector', () {
    setUp(() {
      // Reset both singletons before every test so suites don't leak
      // observers / timers / pref state across cases.
      CrashReporter.instance.debugSetEnabled(false);
      HangDetector.instance.debugSetEnabled(true);
      HangDetector.instance.stop();
    });

    tearDown(() {
      HangDetector.instance.stop();
      HangDetector.instance.debugSetEnabled(true);
    });

    test('isRunning is false before start', () {
      expect(HangDetector.instance.isRunning, isFalse);
    });

    testWidgets(
      'start wires the detector and isRunning flips to true',
      (tester) async {
        HangDetector.instance.start(
          tickInterval: const Duration(milliseconds: 100),
          hangThreshold: const Duration(seconds: 5),
        );
        expect(HangDetector.instance.isRunning, isTrue);
        HangDetector.instance.stop();
        expect(HangDetector.instance.isRunning, isFalse);
      },
    );

    testWidgets(
      'start is idempotent — second call replaces config without throwing',
      (tester) async {
        HangDetector.instance.start();
        HangDetector.instance.start(
          tickInterval: const Duration(milliseconds: 250),
          hangThreshold: const Duration(seconds: 2),
        );
        expect(HangDetector.instance.isRunning, isTrue);
        // Must stop within the test body — `tearDown` runs AFTER the
        // fake-async harness verifies no pending timers, so leaving a
        // live `Timer.periodic` here would fail the test on a
        // "still-pending Timer" assertion regardless of the cleanup.
        HangDetector.instance.stop();
      },
    );

    testWidgets(
      'debugSetEnabled(false) tears down the active detector',
      (tester) async {
        HangDetector.instance.start();
        expect(HangDetector.instance.isRunning, isTrue);
        HangDetector.instance.debugSetEnabled(false);
        expect(HangDetector.instance.isRunning, isFalse);
      },
    );

    testWidgets(
      'start is a no-op when debugSetEnabled(false)',
      (tester) async {
        HangDetector.instance.debugSetEnabled(false);
        HangDetector.instance.start();
        expect(HangDetector.instance.isRunning, isFalse);
      },
    );

    test('stop is safe to call when never started', () {
      // Should not throw.
      HangDetector.instance.stop();
      HangDetector.instance.stop();
    });

    test(
      'AppHangDetected.toString includes the message for Crashlytics grouping',
      () {
        final e = AppHangDetected('UI thread blocked for 4500ms');
        expect(
          e.toString(),
          equals('AppHangDetected: UI thread blocked for 4500ms'),
        );
      },
    );

    test(
      'SlowFrameDetected.toString includes the message for Crashlytics grouping',
      () {
        final e = SlowFrameDetected('Frame took 1234ms to render');
        expect(
          e.toString(),
          equals('SlowFrameDetected: Frame took 1234ms to render'),
        );
      },
    );
  });
}
