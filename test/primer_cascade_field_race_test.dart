// FILE: test/primer_cascade_field_race_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Regression coverage for the dropdown async-value race fixed in
// the Phase Two Group 3.5 sidecar (2026-05-16). Pumps
// `PrimerCascadeField` with its controller pre-set to an existing
// primer label ("Federal #210M") and asserts the widget does NOT
// throw during the FutureBuilder waiting phase — the exact crash
// the operator hit on a real device:
//
//   "There should be exactly one item with [DropdownButton]'s
//    value: Federal. Either zero or 2 or more [DropdownMenuItem]s
//    were detected with the same value"
//
// The root cause: `_PrimerCascadeFieldState.initState` sets
// `_selectedBrand = "Federal"` synchronously (parsed from the
// controller) while `_futureBrands` resolves async. A `FutureBuilder`
// ALWAYS renders its first frame in the `waiting` state with no
// data — even when the underlying future is already complete,
// because the subscription + first build happen synchronously
// before the `.then` microtask fires. So the first paint has
// `brands == []` + `initialValue: "Federal"` → zero matching
// `DropdownMenuItem`s → Flutter's exactly-one-match assertion.
//
// The fix injects a synthetic fallback `DropdownMenuItem` for the
// selected brand whenever the loaded list doesn't contain it, so
// the invariant holds through the waiting phase AND survives a
// catalog reseed that dropped a value a saved recipe still
// references.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// `PrimerCascadeField` is the directly-testable instance of a bug
// class shared with the recipe form's `_seededDropdown` helper
// (a Group 2 regression — same defect, fixed in the same sidecar).
// `_seededDropdown` is private to `_RecipeFormScreenState` and
// can't be pumped without the full 7-provider recipe-form tree;
// this widget exercises the identical defensive pattern against
// real production code with a one-provider harness. The shared
// pattern is the contract; this test pins it.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// - The crash window is the FIRST FRAME. `tester.pumpWidget(...)`
//   builds once synchronously; the FutureBuilder is in `waiting`
//   with no data at that point regardless of how fast the future
//   is. `tester.takeException()` immediately after `pumpWidget`
//   (before any settle) is what catches the pre-fix crash.
// - The widget reads `ComponentRepository` from a Provider, and
//   the `_futureProducts` sub-future fires when a brand is
//   pre-selected — the in-memory DB needs a Federal primer
//   manufacturer + at least one primer so `pumpAndSettle()`
//   resolves cleanly without an unrelated "no data" exception
//   masking the assertion under test.
// - The empty-catalog test pins the catalog-reseed-dropped-value
//   edge: `_selectedBrand` is set but `primerManufacturers()`
//   returns []. The synthetic fallback must still satisfy the
//   exactly-one-match invariant.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `flutter test` (CI; slow-tagged — pumps a Material tree).
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. In-memory drift; no I/O.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:loadout/database/database.dart';
import 'package:loadout/repositories/component_repository.dart';
import 'package:loadout/widgets/primer_cascade_field.dart';

void main() {
  late AppDatabase db;
  late ComponentRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ComponentRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seedFederalPrimer() async {
    final mfgId = await db.into(db.manufacturers).insert(
          ManufacturersCompanion.insert(name: 'Federal', kind: 'primer'),
        );
    await db.into(db.primers).insert(
          PrimersCompanion.insert(
            manufacturerId: mfgId,
            name: '210M',
            size: 'large rifle',
          ),
        );
    return mfgId;
  }

  Future<void> pumpField(WidgetTester tester, TextEditingController c) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ComponentRepository>.value(value: repo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PrimerCascadeField(controller: c),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'no crash on first paint when controller pre-sets an existing brand '
    '(the operator-reported "value: Federal" assertion)',
    (tester) async {
      await seedFederalPrimer();
      final controller = TextEditingController(text: 'Federal #210M');
      addTearDown(controller.dispose);

      await pumpField(tester, controller);

      // THE GATE: the first frame is the FutureBuilder waiting phase.
      // Pre-fix this throws the DropdownButton exactly-one-match
      // assertion. takeException() must be null here.
      expect(tester.takeException(), isNull,
          reason: 'first-paint waiting phase must not crash with a '
              'pre-set brand');

      // Let the brand + product futures resolve. Still no exception,
      // and the brand renders.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Federal'), findsWidgets);

      // Dispose the tree before the framework's pending-timer check.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    tags: 'slow',
  );

  testWidgets(
    'no crash when a saved brand is no longer in the catalog '
    '(reseed-dropped-value edge)',
    (tester) async {
      // DON'T seed Federal. `primerManufacturers()` resolves to [].
      // `_selectedBrand` is still "Federal" from the controller —
      // the synthetic fallback item must keep the invariant.
      final controller = TextEditingController(text: 'Federal #210M');
      addTearDown(controller.dispose);

      await pumpField(tester, controller);
      expect(tester.takeException(), isNull,
          reason: 'first paint with an empty brand catalog + pre-set '
              'brand must not crash');

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The fallback keeps the persisted brand visible/selectable.
      expect(find.text('Federal'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    tags: 'slow',
  );

  testWidgets(
    'empty controller (new recipe) renders cleanly — no fallback needed',
    (tester) async {
      await seedFederalPrimer();
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pumpField(tester, controller);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    tags: 'slow',
  );

  group('primerManufacturers defensive dedupe', () {
    // NOTE: the "legacy duplicate rows collapse" case is NOT
    // unit-testable. `AppDatabase.forTesting` always CREATES
    // `manufacturers` with the current schema, which bakes the
    // `UNIQUE(name, kind)` table constraint into the CREATE TABLE
    // — even a raw `customStatement` INSERT of a duplicate throws
    // SqliteException(2067) before the dedupe is ever reached
    // (verified during sidecar development). That is itself the
    // proof the operator's on-device crash was the ZERO-items
    // race (covered by the widget tests above), not a 2+-items
    // duplicate: duplicates are impossible on any DB whose
    // `manufacturers` table was created at a schema version that
    // declared `uniqueKeys`. The `.toSet()` in
    // `primerManufacturers()` is harmless cheap insurance for the
    // only remaining theoretical path — a device whose table was
    // created BEFORE `uniqueKeys` existed and never rebuilt — and
    // that path can't be constructed against a fresh test schema.
    // This test instead pins that the dedupe doesn't disturb the
    // normal (already-distinct) case.
    test('distinct brands are all preserved (dedupe is a no-op here)',
        () async {
      await db.into(db.manufacturers).insert(
            ManufacturersCompanion.insert(name: 'Federal', kind: 'primer'),
          );
      await db.into(db.manufacturers).insert(
            ManufacturersCompanion.insert(name: 'CCI', kind: 'primer'),
          );
      await db.into(db.manufacturers).insert(
            ManufacturersCompanion.insert(
              name: 'Winchester',
              kind: 'primer',
              country: const Value('USA'),
            ),
          );

      final brands = await repo.primerManufacturers();
      expect(brands, containsAll(['Federal', 'CCI', 'Winchester']));
      expect(brands, hasLength(3));
    });
  });
}
