// FILE: test/active_range_day_session_test.dart
//
// Verifies the [ActiveRangeDaySession] singleton's set/clear/idempotency
// contract. The tracker is process-local in-memory state — these tests
// only need the framework binding (no SharedPreferences mock, no
// platform channels).

import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/services/active_range_day_session.dart';

void main() {
  // Each test starts from a known clean state. Singletons are
  // process-local so previous tests can leave state behind.
  setUp(() {
    ActiveRangeDaySession.clear();
  });

  group('ActiveRangeDaySession', () {
    test('starts null on first read', () {
      expect(ActiveRangeDaySession.id, isNull);
      expect(ActiveRangeDaySession.notifier.value, isNull);
    });

    test('set() stores the id and notifies listeners', () {
      var notifyCount = 0;
      void listener() => notifyCount++;
      ActiveRangeDaySession.notifier.addListener(listener);
      try {
        ActiveRangeDaySession.set(42);
        expect(ActiveRangeDaySession.id, 42);
        expect(notifyCount, 1);
      } finally {
        ActiveRangeDaySession.notifier.removeListener(listener);
      }
    });

    test('set() with the same id is a no-op (no listener notification)', () {
      ActiveRangeDaySession.set(42);
      var notifyCount = 0;
      void listener() => notifyCount++;
      ActiveRangeDaySession.notifier.addListener(listener);
      try {
        ActiveRangeDaySession.set(42);
        expect(ActiveRangeDaySession.id, 42);
        expect(
          notifyCount,
          0,
          reason: 'setting the same id again must not notify listeners',
        );
      } finally {
        ActiveRangeDaySession.notifier.removeListener(listener);
      }
    });

    test('set() with a different id replaces and notifies', () {
      ActiveRangeDaySession.set(42);
      var notifyCount = 0;
      void listener() => notifyCount++;
      ActiveRangeDaySession.notifier.addListener(listener);
      try {
        ActiveRangeDaySession.set(99);
        expect(ActiveRangeDaySession.id, 99);
        expect(notifyCount, 1);
      } finally {
        ActiveRangeDaySession.notifier.removeListener(listener);
      }
    });

    test('clear() resets the value and notifies', () {
      ActiveRangeDaySession.set(42);
      var notifyCount = 0;
      void listener() => notifyCount++;
      ActiveRangeDaySession.notifier.addListener(listener);
      try {
        ActiveRangeDaySession.clear();
        expect(ActiveRangeDaySession.id, isNull);
        expect(notifyCount, 1);
      } finally {
        ActiveRangeDaySession.notifier.removeListener(listener);
      }
    });

    test('clear() when already null is a no-op', () {
      var notifyCount = 0;
      void listener() => notifyCount++;
      ActiveRangeDaySession.notifier.addListener(listener);
      try {
        ActiveRangeDaySession.clear();
        expect(notifyCount, 0);
      } finally {
        ActiveRangeDaySession.notifier.removeListener(listener);
      }
    });
  });
}
