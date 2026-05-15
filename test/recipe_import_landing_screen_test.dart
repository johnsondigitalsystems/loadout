// FILE: test/recipe_import_landing_screen_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Smoke tests for `RecipeImportLandingScreen` (Phase One Group 5).
// Confirms the landing screen renders the documented tile set,
// that Coming Soon tiles are visible-but-disabled (`onTap: null`
// + "Coming Soon" chip), and that the page title is the canonical
// "Import a Recipe" copy. Routing assertions live in
// `recipe_import_source_test.dart` because exercising the actual
// per-source pushes would require a wider provider tree than
// these smoke tests need.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The landing screen replaced six tiles inside
// `ImportOptionsSection`. A regression in tile rendering (missing
// Take a Photo on iOS, "Coming Soon" chip disappearing, paste
// tile silently dropping) would degrade the discoverability the
// new entry point was supposed to provide. The smoke tests pin
// the per-tile rendering so a future refactor of the visual
// layout can't silently lose a tile.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// - The five "live" tiles include two photo tiles (Take a Photo +
//   Pick from Gallery) that only render on platforms where
//   `PhotoImportScreen.isSupportedPlatform` is true. The test
//   doesn't try to mock `Platform` — it just asserts on the
//   tiles that always render on the host platform AND the
//   Coming Soon block which renders unconditionally.
// - The landing screen depends on `RecipeRepository` via Provider
//   for the LoadOut JSON re-import path; we provide an in-memory
//   drift-backed instance so the constructor's `context.read`
//   doesn't fail when the user taps a file tile (we don't tap
//   one in these tests — but a constructed widget tree that
//   ProviderNotFound-throws on first build is unstable).
// - Wider 800x2000 viewport so the lazy ListView builds every
//   tile up front; otherwise the Coming Soon block can fall
//   below the fold and never enter the widget tree.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `flutter test` (CI; tests are slow-tagged because they pump
//   a Material widget tree).
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. In-memory drift; no I/O.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:loadout/database/database.dart';
import 'package:loadout/repositories/recipe_repository.dart';
import 'package:loadout/screens/recipes/recipe_import_landing_screen.dart';

void main() {
  late AppDatabase db;
  late RecipeRepository recipeRepo;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    recipeRepo = RecipeRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpLanding(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 2000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<RecipeRepository>.value(value: recipeRepo),
        ],
        child: const MaterialApp(home: RecipeImportLandingScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'page title is "Import a Recipe"',
    (tester) async {
      await pumpLanding(tester);
      expect(find.text('Import a Recipe'), findsOneWidget);

      // Dispose explicitly — no Navigator.pop in this test, so the
      // tree must be torn down before the framework checks for
      // pending timers.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    tags: 'slow',
  );

  testWidgets(
    'renders the always-on live tiles (file, clipboard, QR)',
    (tester) async {
      await pumpLanding(tester);
      expect(find.text('Choose a File'), findsOneWidget);
      expect(find.text('Paste From Clipboard'), findsOneWidget);
      expect(find.text('Scan a Recipe QR'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    tags: 'slow',
  );

  testWidgets(
    'renders the three Coming Soon tiles with "Coming Soon" chips',
    (tester) async {
      await pumpLanding(tester);
      expect(find.text('Microsoft Word Document'), findsOneWidget);
      expect(find.text('Microsoft OneNote'), findsOneWidget);
      expect(find.text('Garmin Xero Chronograph Photo'), findsOneWidget);
      // 4 hits for "Coming Soon": one section-heading Text above
      // the disabled tiles, plus one chip per disabled tile (3).
      // A future visual refactor that drops the heading would
      // collapse this to 3; the count pins the current layout.
      expect(find.text('Coming Soon'), findsNWidgets(4));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    tags: 'slow',
  );

  testWidgets(
    'Coming Soon tiles are disabled (ListTile.enabled is effectively false)',
    (tester) async {
      await pumpLanding(tester);
      // Find the ListTile that owns the "Microsoft Word Document"
      // text and assert its `onTap` is null. A non-null onTap on a
      // disabled tile would silently swallow a tap and confuse the
      // user.
      final wordTile = tester.widgetList<ListTile>(find.byType(ListTile));
      final disabledTitles = <String>{
        'Microsoft Word Document',
        'Microsoft OneNote',
        'Garmin Xero Chronograph Photo',
      };
      var foundDisabled = 0;
      for (final tile in wordTile) {
        final title = tile.title;
        if (title is Text && disabledTitles.contains(title.data)) {
          expect(tile.onTap, isNull,
              reason: '${title.data} tile must be disabled');
          foundDisabled++;
        }
      }
      expect(foundDisabled, 3,
          reason: 'all three Coming Soon tiles must be present');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    tags: 'slow',
  );
}
