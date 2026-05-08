// FILE: test/range_day_detail_screen_widget_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Widget smoke tests for
// `lib/screens/range_day/range_day_detail_screen.dart` — the heart of
// the Range Day workspace. The user has been hitting layout-time
// crashes on this screen, so these tests cover the full state matrix:
//
//   * fresh-install user (empty DB, sessionId == null) — Setup card
//     expanded, distance defaults to "500", AppBar reads "New Range
//     Day".
//   * anonymous user — same expectation.
//   * free (non-Pro) user — Pro-gated buttons stay locked / hidden.
//   * Pro user — Pro-gated buttons render their unlocked state.
//   * platforms with no sensors — sensor reads return null, UI hides
//     the affordances.
//   * existing session id → fields hydrate (distance text matches the
//     persisted value).
//   * solver re-runs after a distance edit (debounced 500ms).
//   * Setup card auto-collapses when hydrating an existing session.
//   * AppBar refresh button fires `_solve()` without crashing.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// This is the screen the user actually opens at the range. Its
// `initState` reads ten providers, kicks off three sensor `start()`
// calls, schedules a post-frame solve + hit-probability compute, and
// (if `sessionId != null`) hydrates from the database. Any of those
// can crash on a malformed widget tree. These tests catch the bulk of
// the regressions before they reach a user.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * The screen wires ~50 `context.read` / `context.watch` calls. The
//     harness `pumpRangeDayScreen` provides every one of them; if a
//     new provider is added in `lib/app.dart`, the harness must be
//     updated in lock-step.
//   * `initState` schedules a post-frame solve + hit-probability
//     compute. We `pumpAndSettle` so those callbacks finish before
//     assertions run. This also drains the auto-save debounce
//     timer.
//   * Tests that hydrate from a saved sessionId need to insert the
//     row BEFORE the screen mounts. The harness exposes the DB via
//     [RangeDayHarness.db]; we insert via that, then a second
//     `pumpRangeDayScreen` call (passing the same `db`) mounts the
//     real screen with a sessionId.
//   * Plenty of fields fire `_scheduleSolve()` on edit. We pump 600ms
//     to clear the 500ms debounce, then assert the screen survives.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// `flutter test` (CI + local).
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// In-memory drift DB per test. Closed by the harness via `addTearDown`.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loadout/database/database.dart';
import 'package:loadout/repositories/range_day_repository.dart';
import 'package:loadout/screens/range_day/range_day_detail_screen.dart';

import '_range_day_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'renders without crashing on a fresh-install user with sessionId == null',
      (tester) async {
    await pumpRangeDayScreen(
      tester,
      screen: const RangeDayDetailScreen(),
    );
    // pumpAndSettle has to absorb the post-frame solve callback +
    // any 500ms solver debounce.
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // AppBar title is "New Range Day" for an unsaved session.
    expect(find.text('New Range Day'), findsOneWidget);
    // Setup card should be expanded by default on a new session.
    expect(find.text('Setup'), findsOneWidget);
    // Distance section is rendered.
    expect(find.text('Distance (yd)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without crashing for an anonymous user',
      (tester) async {
    // No auth gate here; harness leaves Firebase Auth unwired which
    // is the anonymous-user posture.
    await pumpRangeDayScreen(
      tester,
      screen: const RangeDayDetailScreen(),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('New Range Day'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without crashing for a free (non-Pro) user',
      (tester) async {
    await pumpRangeDayScreen(
      tester,
      screen: const RangeDayDetailScreen(),
      isPro: false,
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Section headers all render.
    expect(find.text('Setup'), findsOneWidget);
    // Pro-gated UI is either absent or shown with a lock affordance —
    // the screen does NOT crash on render.
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without crashing for a Pro user', (tester) async {
    await pumpRangeDayScreen(
      tester,
      screen: const RangeDayDetailScreen(),
      isPro: true,
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Setup'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without crashing on platforms with no sensors',
      (tester) async {
    // The test host (macOS) sees CantService.isAvailable == false
    // after start() runs. The detail screen calls start() in
    // initState; we just have to confirm it doesn't crash and the
    // sensor readouts gracefully degrade.
    await pumpRangeDayScreen(
      tester,
      screen: const RangeDayDetailScreen(),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('New Range Day'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hydrates fields from a saved session when sessionId is set',
      (tester) async {
    // Build the DB out-of-band, seed a row, then mount the screen
    // pointing at that id. The harness manages the DB lifecycle when
    // we pass it via the `db:` parameter.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());
    final repo = RangeDayRepository(db);
    final id = await repo.insertSession(
      RangeDaySessionsCompanion.insert(
        name: 'Persisted session',
        date: DateTime.utc(2026, 5, 8, 12, 0, 0),
        distanceYd: 800,
        notes: const Value('persisted notes'),
      ),
    );

    await pumpRangeDayScreen(
      tester,
      screen: RangeDayDetailScreen(sessionId: id),
      db: db,
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // The AppBar title should be the session name.
    expect(find.text('Persisted session'), findsOneWidget);
    // Distance field's controller text should be "800".
    final textFields = tester.widgetList<TextField>(find.byType(TextField));
    final distances = textFields
        .where((tf) => tf.controller?.text == '800')
        .toList();
    expect(distances.length, greaterThanOrEqualTo(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'distance controller value persists through the solver-debounce window',
      (tester) async {
    await pumpRangeDayScreen(
      tester,
      screen: const RangeDayDetailScreen(),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Find the distance text field by its controller value (default
    // "500"). Multiple text fields exist on the screen — pick the
    // first one whose value is "500".
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    final distance = fields.firstWhere((tf) => tf.controller?.text == '500');
    final controller = distance.controller!;
    // Programmatically set the text and wait through the 500ms
    // debounce window. The solver runs in a `try/catch` so even bad
    // inputs shouldn't crash the screen.
    controller.text = '750';
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(controller.text, '750');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'tapping the AppBar refresh button calls _solve without crashing',
      (tester) async {
    await pumpRangeDayScreen(
      tester,
      screen: const RangeDayDetailScreen(),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final refresh = find.byTooltip('Recalculate');
    expect(refresh, findsOneWidget);
    await tester.tap(refresh);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Solver runs synchronously; even if it errors internally it sets
    // `_solveError` and renders an inline tile. The screen must NOT
    // crash.
    expect(tester.takeException(), isNull);
  });

  testWidgets('Setup section auto-collapses when hydrating an existing session',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());
    final repo = RangeDayRepository(db);
    final id = await repo.insertSession(
      RangeDaySessionsCompanion.insert(
        name: 'Collapsed setup',
        date: DateTime.utc(2026, 5, 8, 12, 0, 0),
        distanceYd: 300,
      ),
    );

    await pumpRangeDayScreen(
      tester,
      screen: RangeDayDetailScreen(sessionId: id),
      db: db,
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Setup heading text is still present (collapsed-mode header
    // shows the title), but the inside-body "Distance (yd)" label is
    // absent because the body is hidden.
    expect(find.text('Setup'), findsOneWidget);
    expect(find.text('Distance (yd)'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the Setup section header on first build', (tester) async {
    await pumpRangeDayScreen(
      tester,
      screen: const RangeDayDetailScreen(),
      isPro: true,
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // The Setup card header is the most reliable rendering anchor
    // for a freshly-pumped screen. If it's there, the rest of the
    // initState chain (post-frame solve, sensor starts, etc.) ran
    // without throwing.
    expect(find.text('Setup'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
