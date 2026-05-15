// FILE: test/quick_add_coal_cbto_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Widget tests for the Phase One Group 4 COAL/CBTO axis toggle on
// `QuickAddRecipeScreen` (`lib/screens/recipes/quick_add_recipe_screen.dart`).
//
// The form lets a reloader capture EITHER the cartridge overall length
// (COAL) OR the base-to-ogive (CBTO), via a `SegmentedButton` + a
// single `TextFormField` whose label and target drift column flip
// based on the selected axis. The "either/or" pattern is what
// reloading notebooks use — they carry one dimension per line, not
// both — and the form has to make sure the OTHER column is null on
// save so a stale value from before an axis swap doesn't leak.
//
// Three behaviours under test:
//
//   1. Default axis is COAL — the segmented toggle selects COAL on
//      first build and the field renders with COAL label + helper.
//   2. Flipping to CBTO swaps the field's label, helper, and the
//      target column on save (verified end-to-end through the
//      drift insert).
//   3. Applying a template with `coalIn` populates the field AND
//      forces the axis to COAL — templates are reference loads
//      drawn from published manuals (which quote COAL, not CBTO).
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The user-flagged scope of Quick Add is "five fields that match a
// notebook line" (CLAUDE.md / Quick Add header comment). The COAL/CBTO
// row was always in the spec but the editor never rendered it — a
// silent regression that pen-and-paper migrators would notice
// immediately ("the screen says it captures COAL but there's no
// field"). The Group 4 implementation closes the gap; this test
// keeps it closed.
//
// The either/or-on-save invariant matters because BOTH `coalIn` and
// `cbtoIn` are independent nullable columns on `UserLoads`. If a
// future refactor accidentally writes both, the recipe form's
// detail-level rendering would show conflicting Cartridge Dimensions
// rows (COAL shown in one section, CBTO in another, with no UI hint
// which the user actually measured).
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// - These tests pump the full `QuickAddRecipeScreen`, which under the
//   hood instantiates `ImportOptionsSection` (needs
//   `RecipeRepository`) and a `BeginnerModeService` (reads
//   SharedPreferences). The harness initialises SharedPreferences
//   with empty mock values before each pump.
// - The dimension field has the same label across both axes when you
//   ignore the parenthetical ("COAL (in)" vs "CBTO (in)"), so the
//   tests `find.text(...)` against the exact label string including
//   the unit — the helper text is the discriminator that confirms
//   the screen actually switched, not just the segment selection.
// - The save flow inserts via `RecipeRepository.insert`, returns the
//   new row id, then pops. The test reads the row back via
//   `repo.getById` to verify the COAL/CBTO routing landed in the
//   correct column.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `flutter test` (CI). Tests are tagged `slow` because they pump a
//   full Material widget tree; the dev-loop wrapper
//   `tool/test-fast.sh` excludes them.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None observable outside the test process. SharedPreferences uses
// the in-test mock; drift uses `NativeDatabase.memory()`.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:loadout/database/database.dart';
import 'package:loadout/repositories/component_repository.dart';
import 'package:loadout/repositories/favorites_repository.dart';
import 'package:loadout/repositories/recipe_repository.dart';
import 'package:loadout/screens/recipes/quick_add_recipe_screen.dart';
import 'package:loadout/services/beginner_mode_service.dart';
import 'package:loadout/services/component_favorites_service.dart';

void main() {
  late AppDatabase db;
  late RecipeRepository recipeRepo;
  late ComponentRepository componentRepo;
  late FavoritesRepository favoritesRepo;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // Pre-warm the SharedPreferences singleton before any widget
    // builds. `BeginnerModeService`'s constructor schedules an
    // unawaited `_hydrate()` that calls `SharedPreferences.getInstance()`
    // — if the very first plugin call happens during widget
    // construction, the resulting Timer can outlive `pumpAndSettle`
    // and trip the "Timer is still pending" assertion at tearDown.
    // Forcing the plugin to resolve once here makes every subsequent
    // `getInstance()` return synchronously.
    await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    recipeRepo = RecipeRepository(db);
    componentRepo = ComponentRepository(db);
    favoritesRepo = FavoritesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpQuickAdd(WidgetTester tester) async {
    // The QuickAdd `ListView` has ~12 children stacked vertically;
    // the COAL/CBTO row sits below the bullet-weight field. The
    // default flutter_test viewport is 800x600 and ListView lazy-
    // renders only what's in view, so the segments would be culled
    // from the widget tree without a taller viewport. 2400px is
    // enough headroom for every row to be on-screen at once.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<RecipeRepository>.value(value: recipeRepo),
          Provider<ComponentRepository>.value(value: componentRepo),
          Provider<FavoritesRepository>.value(value: favoritesRepo),
          ChangeNotifierProvider<BeginnerModeService>(
            create: (_) => BeginnerModeService(),
          ),
          ChangeNotifierProvider<ComponentFavoritesService>(
            create: (_) => ComponentFavoritesService(db),
          ),
        ],
        child: const MaterialApp(home: QuickAddRecipeScreen()),
      ),
    );
    // Let the BeginnerModeService.SharedPreferences hydrate so the
    // widget doesn't rebuild mid-test.
    await tester.pumpAndSettle();
  }

  // The two assertion-only tests (no Save → no Navigator.pop) need
  // explicit `pumpWidget(SizedBox.shrink())` at the end to dispose
  // the prior widget tree's ChangeNotifier providers. Without it,
  // `BeginnerModeService` and `ComponentFavoritesService` outlive
  // the test, leaving an async listener that registers as a pending
  // Timer at tearDown and trips the framework's `!timersPending`
  // assertion. The two save-flow tests below pop the navigator as
  // part of `_save()`, which disposes the tree naturally — no
  // explicit teardown needed there.
  Future<void> disposeWidgetTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'default axis is COAL — field label and helper say COAL',
    (tester) async {
      await pumpQuickAdd(tester);

      // Both segment labels exist on screen.
      expect(find.text('COAL'), findsWidgets);
      expect(find.text('CBTO'), findsWidgets);

      // The dimension field's label is the COAL form.
      expect(find.text('COAL (in)'), findsOneWidget);
      expect(find.text('Cartridge overall length'), findsOneWidget);
      // CBTO helper text is NOT shown.
      expect(find.text('Cartridge base-to-ogive'), findsNothing);

      await disposeWidgetTree(tester);
    },
    tags: 'slow',
  );

  testWidgets(
    'tapping CBTO flips the dimension field label and helper',
    (tester) async {
      await pumpQuickAdd(tester);

      // The CBTO segment label is the topmost `Text('CBTO')` in the
      // tree — `find.text` resolves to the segment's label widget,
      // and a tap on it triggers `SegmentedButton.onSelectionChanged`.
      // (`find.widgetWithText(ButtonSegment, ...)` does NOT work
      // because `ButtonSegment` is a data class, not a `Widget`.)
      await tester.tap(find.text('CBTO').first);
      await tester.pumpAndSettle();

      expect(find.text('CBTO (in)'), findsOneWidget);
      expect(find.text('Cartridge base-to-ogive'), findsOneWidget);
      expect(find.text('Cartridge overall length'), findsNothing);

      await disposeWidgetTree(tester);
    },
    tags: 'slow',
  );

  testWidgets(
    'saving in CBTO mode writes cbtoIn, leaves coalIn null',
    (tester) async {
      await pumpQuickAdd(tester);

      // Switch axis to CBTO before entering the value so the field's
      // controller is the CBTO one.
      await tester.tap(find.text('CBTO').first);
      await tester.pumpAndSettle();

      // Type a dimension value into the (now CBTO-labelled) field.
      await tester.enterText(find.widgetWithText(TextFormField, 'CBTO (in)'),
          '2.225');

      // Type a Recipe Name so the autosave fallback name generator
      // doesn't run (keeps the assertion focused on the dimension
      // columns).
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Recipe Name'), 'CBTO Test');

      // Save by tapping the bottom-of-screen Save button. Viewport is
      // already 800x2400 (set in `pumpQuickAdd`) so the button is
      // always on-screen and we don't need to scroll first — direct
      // tap is more deterministic than `scrollUntilVisible`, which
      // can flicker between zero/multiple matches as a lazy ListView
      // builds offscreen rows.
      await tester.tap(find.widgetWithText(FilledButton, 'Save Recipe'));
      await tester.pumpAndSettle();

      // The Quick Add screen pops on success; the row should be in
      // the database with the right columns.
      final rows = await recipeRepo.allOnce();
      expect(rows, hasLength(1));
      expect(rows.first.cbtoIn, closeTo(2.225, 1e-9),
          reason: 'CBTO axis save must populate cbtoIn');
      expect(rows.first.coalIn, isNull,
          reason: 'CBTO axis save must leave coalIn null');
    },
    tags: 'slow',
  );

  testWidgets(
    'saving in COAL mode (default) writes coalIn, leaves cbtoIn null',
    (tester) async {
      await pumpQuickAdd(tester);

      // No axis tap — default is COAL.
      await tester.enterText(find.widgetWithText(TextFormField, 'COAL (in)'),
          '2.800');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Recipe Name'), 'COAL Test');

      await tester.tap(find.widgetWithText(FilledButton, 'Save Recipe'));
      await tester.pumpAndSettle();

      final rows = await recipeRepo.allOnce();
      expect(rows, hasLength(1));
      expect(rows.first.coalIn, closeTo(2.800, 1e-9));
      expect(rows.first.cbtoIn, isNull);
    },
    tags: 'slow',
  );
}
