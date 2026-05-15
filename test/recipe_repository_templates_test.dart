// FILE: test/recipe_repository_templates_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Drift round-trip tests for `RecipeRepository.allTemplates()` and
// `RecipeRepository.templatesByDetailLevel(...)` — the new Phase
// Two Group 1 entry points that replaced direct iteration over
// the retired `kRecipeTemplates` const list.
//
// Tests:
//   1. Inserting via `RecipeTemplatesCompanion` then reading via
//      `allTemplates()` returns equivalent `RecipeTemplate`
//      instances with every field intact.
//   2. `templatesByDetailLevel(.quick)` returns only quick-level
//      rows; other levels are filtered out.
//   3. Empty table returns an empty list (defensive — the seed
//      loader populates on first run, but the repository must not
//      crash on an empty table).
//
// The drift database is in-memory, populated manually inside each
// test rather than via `SeedLoader` — this isolates the repository
// from the seed-loader contract.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Pre-Phase-Two-Group-1, templates iteration was a compile-time
// const list read; "did the templates load?" was a tautology. Now
// it's a runtime query against the `RecipeTemplates` drift table,
// and the round-trip contract has to be pinned. A future refactor
// that accidentally swaps the column wiring or drops a field
// would otherwise ship silently.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// - The `recommendedDetailLevel` column stores the enum's `.name`
//   string. Round-tripping requires parsing the string back to the
//   enum, and the repository's `_rowToTemplate` does that via
//   `RecipeTemplateDetailLevel.values.firstWhere`. The test
//   inserts a row with `level.name`, reads it, and confirms the
//   enum value matches.
// - Double-precision fields (`powderChargeGr`, `bulletWeightGr`,
//   `coalIn`, `cbtoIn`) are stored as drift `RealColumn`s. The
//   round-trip uses `closeTo(..., 1e-9)` to defend against IEEE-754
//   noise (same convention as `test/component_repository_caliber_test.dart`).
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `flutter test` (CI gate).
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. In-memory drift; no I/O.

// Restrict the drift import to `Value` so `isNull` resolves to
// flutter_test's matcher rather than drift's query-builder symbol.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loadout/database/database.dart';
import 'package:loadout/models/recipe_template.dart';
import 'package:loadout/repositories/recipe_repository.dart';

void main() {
  late AppDatabase db;
  late RecipeRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = RecipeRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('RecipeRepository.allTemplates', () {
    test('empty table returns an empty list', () async {
      final result = await repo.allTemplates();
      expect(result, isEmpty);
    });

    test('round-trips every field on a fully-populated row', () async {
      await db.into(db.recipeTemplates).insert(
            RecipeTemplatesCompanion.insert(
              id: 'rt-full',
              name: 'Fully Populated',
              description: const Value('Description text'),
              recommendedDetailLevel: 'quick',
              caliber: const Value('6.5 Creedmoor'),
              powder: const Value('Hodgdon H4350'),
              powderChargeGr: const Value(41.5),
              bullet: const Value('Hornady ELD Match 140gr'),
              bulletWeightGr: const Value(140.0),
              coalIn: const Value(2.800),
              cbtoIn: const Value(2.225),
              useCase: const Value('match'),
              notes: const Value('Test note.'),
            ),
          );

      final templates = await repo.allTemplates();
      expect(templates, hasLength(1));
      final t = templates.single;

      expect(t.id, 'rt-full');
      expect(t.name, 'Fully Populated');
      expect(t.description, 'Description text');
      expect(t.recommendedDetailLevel, RecipeTemplateDetailLevel.quick);
      expect(t.caliber, '6.5 Creedmoor');
      expect(t.powder, 'Hodgdon H4350');
      expect(t.powderChargeGr, closeTo(41.5, 1e-9));
      expect(t.bullet, 'Hornady ELD Match 140gr');
      expect(t.bulletWeightGr, closeTo(140.0, 1e-9));
      expect(t.coalIn, closeTo(2.800, 1e-9));
      expect(t.cbtoIn, closeTo(2.225, 1e-9));
      expect(t.useCase, 'match');
      expect(t.notes, 'Test note.');
    });

    test('round-trips a minimal row (required fields only, nulls intact)',
        () async {
      await db.into(db.recipeTemplates).insert(
            RecipeTemplatesCompanion.insert(
              id: 'rt-min',
              name: 'Minimal',
              recommendedDetailLevel: 'core',
            ),
          );

      final templates = await repo.allTemplates();
      expect(templates, hasLength(1));
      final t = templates.single;

      expect(t.id, 'rt-min');
      expect(t.name, 'Minimal');
      expect(t.recommendedDetailLevel, RecipeTemplateDetailLevel.core);
      expect(t.description, isNull);
      expect(t.caliber, isNull);
      expect(t.powder, isNull);
      expect(t.powderChargeGr, isNull);
      expect(t.bullet, isNull);
      expect(t.bulletWeightGr, isNull);
      expect(t.coalIn, isNull);
      expect(t.cbtoIn, isNull);
      expect(t.useCase, isNull);
      expect(t.notes, isNull);
    });
  });

  group('RecipeRepository.templatesByDetailLevel', () {
    Future<void> insertOne(String id, String levelName) async {
      await db.into(db.recipeTemplates).insert(
            RecipeTemplatesCompanion.insert(
              id: id,
              name: id,
              recommendedDetailLevel: levelName,
            ),
          );
    }

    test('filters to the requested level (quick only)', () async {
      await insertOne('rt-q1', 'quick');
      await insertOne('rt-q2', 'quick');
      await insertOne('rt-c1', 'core');
      await insertOne('rt-e1', 'extended');
      await insertOne('rt-f1', 'full');

      final quick = await repo.templatesByDetailLevel(
        RecipeTemplateDetailLevel.quick,
      );
      expect(quick.map((t) => t.id), unorderedEquals(['rt-q1', 'rt-q2']));

      final extended = await repo.templatesByDetailLevel(
        RecipeTemplateDetailLevel.extended,
      );
      expect(extended.map((t) => t.id), unorderedEquals(['rt-e1']));

      final full = await repo.templatesByDetailLevel(
        RecipeTemplateDetailLevel.full,
      );
      expect(full.map((t) => t.id), unorderedEquals(['rt-f1']));
    });

    test('returns empty when no rows match the requested level', () async {
      await insertOne('rt-q1', 'quick');
      // Asking for `full` with only `quick` rows present.
      final full = await repo.templatesByDetailLevel(
        RecipeTemplateDetailLevel.full,
      );
      expect(full, isEmpty);
    });
  });
}
