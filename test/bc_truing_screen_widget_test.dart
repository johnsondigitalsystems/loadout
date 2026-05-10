// FILE: test/bc_truing_screen_widget_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Widget smoke tests for `lib/screens/range_day/bc_truing_screen.dart`
// — the industry-standard BC-truing wizard. Confirms the screen renders across
// the matrix of states the production app surfaces:
//
//   * fresh-install user (empty DB),
//   * anonymous user (no auth gate),
//   * free (non-Pro) user — the screen has no inline Pro gate; the
//     check happens at the entry point on the parent screen,
//   * Pro user,
//   * platforms with no sensors,
//   * default observation-row count is 3 (range 600 / 800 / 1000),
//   * adding a row via the "+" button bumps the visible row count,
//   * removing a row via the trash icon decrements the count.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The truing math (`BcTruingService.trueBcFromObservations`) is unit-
// tested in `test/bc_truing_test.dart`. These tests confirm the SCREEN
// builds with no Pro / firearm / load selected and that the observation
// table's add / remove handlers update the visible row count.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * Each observation row contains its own `TextFormField`s, so
//     counting observation rows by `find.byType(TextFormField)` would
//     also pick up the BC + atmosphere fields above. We count rows by
//     the unique label "Observed drop (mil)" on the second column of
//     each row.
//   * The "+" add-row button is inside the Observations card with the
//     "Add row" tooltip. We tap by tooltip to disambiguate from the
//     atmosphere / BC fields.
//   * Every test ends with `tearDownRangeDayWidgetTree` so drift's
//     stream-cancel timer fires inside the test body window.
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

import 'package:flutter_test/flutter_test.dart';

import 'package:loadout/screens/range_day/bc_truing_screen.dart';

import '_range_day_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders without crashing on a fresh-install user (empty DB)',
      (tester) async {
    await pumpRangeDayScreen(tester, screen: const BcTruingScreen());
    await tester.pumpAndSettle();

    expect(find.text('BC Truing'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tearDownRangeDayWidgetTree(tester);
  });

  testWidgets('renders without crashing for an anonymous user',
      (tester) async {
    await pumpRangeDayScreen(tester, screen: const BcTruingScreen());
    await tester.pumpAndSettle();

    expect(find.text('BC Truing'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tearDownRangeDayWidgetTree(tester);
  });

  testWidgets('renders without crashing for a free (non-Pro) user',
      (tester) async {
    await pumpRangeDayScreen(
      tester,
      screen: const BcTruingScreen(),
      isPro: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('BC Truing'), findsOneWidget);
    // The screen has no inline Pro gate — observation table still
    // renders.
    expect(find.text('Observations'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tearDownRangeDayWidgetTree(tester);
  });

  testWidgets('renders without crashing for a Pro user', (tester) async {
    await pumpRangeDayScreen(
      tester,
      screen: const BcTruingScreen(),
      isPro: true,
    );
    await tester.pumpAndSettle();

    expect(find.text('BC Truing'), findsOneWidget);
    expect(find.text('Observations'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tearDownRangeDayWidgetTree(tester);
  });

  testWidgets('renders without crashing on platforms with no sensors',
      (tester) async {
    await pumpRangeDayScreen(tester, screen: const BcTruingScreen());
    await tester.pumpAndSettle();

    expect(find.text('BC Truing'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tearDownRangeDayWidgetTree(tester);
  });

  testWidgets('default observation-row count is 3 (rangeYd 600 / 800 / 1000)',
      (tester) async {
    await pumpRangeDayScreen(tester, screen: const BcTruingScreen());
    await tester.pumpAndSettle();

    // The screen seeds three editable rows by default. Count by the
    // unique-per-row "Observed drop (mil)" label.
    final dropFields = find.text('Observed drop (mil)');
    expect(dropFields, findsNWidgets(3));
    expect(tester.takeException(), isNull);
    await tearDownRangeDayWidgetTree(tester);
  });

  testWidgets('tapping "Add row" appends a fourth observation row',
      (tester) async {
    await pumpRangeDayScreen(tester, screen: const BcTruingScreen());
    await tester.pumpAndSettle();

    expect(find.text('Observed drop (mil)'), findsNWidgets(3));
    // The Add row IconButton has tooltip "Add row".
    await tester.tap(find.byTooltip('Add row'));
    await tester.pumpAndSettle();

    expect(find.text('Observed drop (mil)'), findsNWidgets(4));
    expect(tester.takeException(), isNull);
    await tearDownRangeDayWidgetTree(tester);
  });

  testWidgets('tapping a row\'s trash icon removes that observation',
      (tester) async {
    await pumpRangeDayScreen(tester, screen: const BcTruingScreen());
    await tester.pumpAndSettle();

    expect(find.text('Observed drop (mil)'), findsNWidgets(3));
    // Each row has a "Remove" tooltip on its trash icon. Tap the
    // first one.
    final removeButtons = find.byTooltip('Remove');
    expect(removeButtons, findsNWidgets(3));
    await tester.tap(removeButtons.first);
    await tester.pumpAndSettle();

    expect(find.text('Observed drop (mil)'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tearDownRangeDayWidgetTree(tester);
  });

  testWidgets('result card surfaces empty-state copy with no observations',
      (tester) async {
    await pumpRangeDayScreen(tester, screen: const BcTruingScreen());
    await tester.pumpAndSettle();

    // Remove all three default rows.
    final removeButtons = find.byTooltip('Remove');
    expect(removeButtons, findsNWidgets(3));
    // We have to tap "first" three times because the indices shift
    // after each removal (the list shrinks).
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Remove').first);
      await tester.pumpAndSettle();
    }

    expect(find.text('Observed drop (mil)'), findsNothing);
    // With zero observations the result card surfaces its empty-state
    // copy.
    expect(
      find.text('Add at least one observation to compute the trued BC.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tearDownRangeDayWidgetTree(tester);
  });
}
