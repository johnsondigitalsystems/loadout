// FILE: test/range_day_screen_widget_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Widget smoke tests for `lib/screens/range_day/range_day_screen.dart` —
// the Range Day tab's list screen. Every test pumps the screen via the
// shared harness in `test/_range_day_test_harness.dart` and asserts that
// the screen renders without crashing across the matrix of states the
// production app actually surfaces:
//
//   * fresh-install user (empty DB),
//   * anonymous user,
//   * free (non-Pro) user,
//   * Pro user,
//   * platforms with no sensors (the test host already has no sensors,
//     so this is a free check that the screen tolerates that posture),
//   * a populated DB with three sessions,
//   * the FAB / "+" action firing a Navigator.push.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The user has been hitting layout-time crashes on Range Day. This file
// is the safety net: any time the widget tree's invariants change such
// that the list screen would crash on first render, one of these tests
// should fail loudly. The repo-level coverage for `RangeDayRepository`
// already exists in `range_day_repository_test.dart`; these tests cover
// the BUILD path that consumes the repo.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * The screen reads from a real `Stream<List<RangeDaySessionRow>>`
//     (drift's `watchAll()`). `pumpAndSettle()` is required to drain
//     the initial empty emission before assertions run; otherwise the
//     test sees the loading spinner.
//   * The "+" FAB pushes a route to `RangeDayDetailScreen`, which itself
//     has a heavy initState that reads many providers. We use a
//     NavigatorObserver to ASSERT the push happened without actually
//     letting the new screen pump (the parent pop handler short-circuits
//     after `didPush`).
//   * `tester.takeException()` is checked after each pumpAndSettle to
//     catch silent layout exceptions Flutter would otherwise route
//     through `FlutterError.onError` (the production code's
//     `RangeDayErrorBoundary` catches these in production, but in tests
//     `FlutterError.onError` re-throws by default).
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// `flutter test` (CI + local). Read by future engineers touching
// `lib/screens/range_day/range_day_screen.dart` to see what render
// states are pinned.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// In-memory drift DB per test. Closed by the harness in `addTearDown`.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loadout/database/database.dart';
import 'package:loadout/repositories/range_day_repository.dart';
import 'package:loadout/screens/range_day/range_day_screen.dart';

import '_range_day_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders without crashing on a fresh-install user (empty DB)',
      (tester) async {
    await pumpRangeDayScreen(tester, screen: const RangeDayScreen());
    await tester.pumpAndSettle();

    // AppBar title is present.
    expect(find.text('Range Day'), findsOneWidget);
    // Empty-state CTA shows.
    expect(find.text('No range sessions yet'), findsOneWidget);
    expect(find.text('Start a session'), findsOneWidget);
    // No silent layout exceptions.
    expect(tester.takeException(), isNull);
    await tearDownRangeDayWidgetTree(tester);
  });

  testWidgets('renders without crashing for an anonymous user (no auth wired)',
      (tester) async {
    // The Range Day screen has no auth gate of its own — anonymous and
    // signed-out are visually identical. Pumping the screen with the
    // default harness (which never wires Firebase Auth) effectively
    // is the anonymous-user case.
    await pumpRangeDayScreen(tester, screen: const RangeDayScreen());
    await tester.pumpAndSettle();

    expect(find.text('Range Day'), findsOneWidget);
    expect(find.text('No range sessions yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without crashing for a free (non-Pro) user',
      (tester) async {
    await pumpRangeDayScreen(
      tester,
      screen: const RangeDayScreen(),
      isPro: false,
    );
    await tester.pumpAndSettle();

    // The list screen has no Pro-gated UI itself; everything renders.
    expect(find.text('Range Day'), findsOneWidget);
    // Empty state is shown for free users on a fresh DB.
    expect(find.text('No range sessions yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without crashing for a Pro user', (tester) async {
    await pumpRangeDayScreen(
      tester,
      screen: const RangeDayScreen(),
      isPro: true,
    );
    await tester.pumpAndSettle();

    expect(find.text('Range Day'), findsOneWidget);
    // The list screen looks identical for Pro and free users — assert
    // the same invariants.
    expect(find.text('No range sessions yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without crashing on platforms with no sensors',
      (tester) async {
    // The test host (macOS) already has `isAvailable == false` for
    // CantService / MagnetometerService / InclinometerService once
    // start() runs — but the LIST screen doesn't read sensors at all.
    // This test confirms the screen renders in that posture anyway,
    // and is the same body as the fresh-install test (just labelled
    // differently for documentation purposes).
    await pumpRangeDayScreen(tester, screen: const RangeDayScreen());
    await tester.pumpAndSettle();

    expect(find.text('Range Day'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('list shows 3 items when DB has 3 saved sessions',
      (tester) async {
    final harness = await pumpRangeDayScreen(
      tester,
      screen: const RangeDayScreen(),
    );
    final repo = RangeDayRepository(harness.db);
    await repo.insertSession(
      RangeDaySessionsCompanion.insert(
        name: 'Session A',
        date: DateTime.utc(2026, 5, 1, 8, 0, 0),
        distanceYd: 100,
      ),
    );
    await repo.insertSession(
      RangeDaySessionsCompanion.insert(
        name: 'Session B',
        date: DateTime.utc(2026, 5, 2, 8, 0, 0),
        distanceYd: 200,
      ),
    );
    await repo.insertSession(
      RangeDaySessionsCompanion.insert(
        name: 'Session C',
        date: DateTime.utc(2026, 5, 3, 8, 0, 0),
        distanceYd: 300,
      ),
    );
    // Let the StreamBuilder pick up the inserts.
    await tester.pumpAndSettle();

    expect(find.text('Session A'), findsOneWidget);
    expect(find.text('Session B'), findsOneWidget);
    expect(find.text('Session C'), findsOneWidget);
    // Empty state should NOT be visible.
    expect(find.text('No range sessions yet'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the AppBar "+" action calls Navigator.push',
      (tester) async {
    final observer = _RecordingNavigatorObserver();
    await pumpRangeDayScreen(
      tester,
      screen: const RangeDayScreen(),
      navigatorObserver: observer,
    );
    await tester.pumpAndSettle();
    // Reset to ignore the initial home-route push.
    observer.pushedRoutes.clear();

    // The AppBar action is an IconButton with the "+" icon.
    final addButton = find.byIcon(Icons.add);
    expect(addButton, findsOneWidget);
    await tester.tap(addButton);
    // Don't pumpAndSettle — the new screen would deeply mount and bring
    // its own initState chain. A single pump is enough to fire the
    // route push and let the observer record it.
    await tester.pump();

    // Exactly one new route was pushed.
    expect(observer.pushedRoutes.length, 1);
    final route = observer.pushedRoutes.first;
    expect(route, isA<MaterialPageRoute<dynamic>>());
    // Don't drive into the new screen's pumpAndSettle — that would
    // require populating the entire detail-screen provider tree's
    // post-frame callbacks. We pop manually so the test tear-down
    // doesn't trip on a still-mounted future.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pump();
    // Allow any pending async work in the now-popped detail screen
    // to drain so it cancels timers / subscriptions cleanly.
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  });

  testWidgets('saved-session row tap pushes the detail route', (tester) async {
    final observer = _RecordingNavigatorObserver();
    final harness = await pumpRangeDayScreen(
      tester,
      screen: const RangeDayScreen(),
      navigatorObserver: observer,
    );
    final repo = RangeDayRepository(harness.db);
    await repo.insertSession(
      RangeDaySessionsCompanion.insert(
        name: 'Tap me',
        date: DateTime.utc(2026, 5, 8, 8, 0, 0),
        distanceYd: 600,
        notes: const Value('Some notes'),
      ),
    );
    await tester.pumpAndSettle();
    observer.pushedRoutes.clear();

    expect(find.text('Tap me'), findsOneWidget);
    await tester.tap(find.text('Tap me'));
    await tester.pump();

    expect(observer.pushedRoutes.length, 1);
    // Pop to keep teardown clean.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  });

  testWidgets('AppBar action button has the "New session" tooltip',
      (tester) async {
    await pumpRangeDayScreen(tester, screen: const RangeDayScreen());
    await tester.pumpAndSettle();

    // The AppBar IconButton wraps an Icons.add with a tooltip — verify
    // the tooltip is on the right icon.
    final iconButton = tester.widget<IconButton>(
      find
          .ancestor(
            of: find.byIcon(Icons.add),
            matching: find.byType(IconButton),
          )
          .first,
    );
    expect(iconButton.tooltip, 'New session');
    expect(tester.takeException(), isNull);
  });
}

/// Test-only navigator observer that records every `didPush` call so
/// the test body can assert how many routes were pushed.
class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}
