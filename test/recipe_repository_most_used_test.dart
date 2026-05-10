// FILE: test/recipe_repository_most_used_test.dart
//
// Unit tests for `RecipeRepository.mostUsedComponentNames(kind)` —
// the SQL `GROUP BY` query that powers the "Frequently used"
// middle bucket of the Favorites → Frequently used → general
// ordering rule in `ComponentField`.
//
// Tests cover:
//   1. Empty database → empty list (no recipes touching the kind).
//   2. Counts respect duplicates (the same powder appearing in 5
//      recipes outranks one appearing in 1).
//   3. Result is ordered by usage-count desc, then name asc (the
//      tiebreaker keeps the order stable when two components were
//      used the same number of times).
//   4. Null and whitespace-only values are skipped.
//   5. The `limit` parameter caps the result length.
//   6. Unknown kinds return an empty list (forward-compat for
//      future kinds the caller might supply).
//   7. Each kind queries its own column (powder ≠ bullet ≠ ...).

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loadout/database/database.dart';
import 'package:loadout/repositories/recipe_repository.dart';

Future<int> _insertRecipe(
  AppDatabase db, {
  required String name,
  String? caliber,
  String? powder,
  String? bullet,
  String? primer,
  String? brass,
}) async {
  return db.into(db.userLoads).insert(
        UserLoadsCompanion.insert(
          name: name,
          caliber: Value(caliber),
          powder: Value(powder),
          bullet: Value(bullet),
          primer: Value(primer),
          brass: Value(brass),
        ),
      );
}

void main() {
  group('RecipeRepository.mostUsedComponentNames', () {
    late AppDatabase db;
    late RecipeRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = RecipeRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('empty database returns empty list', () async {
      expect(await repo.mostUsedComponentNames('powder'), isEmpty);
      expect(await repo.mostUsedComponentNames('bullet'), isEmpty);
      expect(await repo.mostUsedComponentNames('primer'), isEmpty);
      expect(await repo.mostUsedComponentNames('brass'), isEmpty);
      expect(await repo.mostUsedComponentNames('cartridge'), isEmpty);
    });

    test('orders by usage count desc, then name asc on ties', () async {
      // Varget × 3, H4350 × 2, RL16 × 1 → Varget, H4350, RL16
      await _insertRecipe(db, name: 'a', powder: 'Varget');
      await _insertRecipe(db, name: 'b', powder: 'Varget');
      await _insertRecipe(db, name: 'c', powder: 'Varget');
      await _insertRecipe(db, name: 'd', powder: 'H4350');
      await _insertRecipe(db, name: 'e', powder: 'H4350');
      await _insertRecipe(db, name: 'f', powder: 'RL16');
      final result = await repo.mostUsedComponentNames('powder');
      expect(result, ['Varget', 'H4350', 'RL16']);
    });

    test('tiebreaks alphabetically when usage counts are equal', () async {
      // Two powders, both used twice → alphabetical by name.
      await _insertRecipe(db, name: '1', powder: 'Vihtavuori N140');
      await _insertRecipe(db, name: '2', powder: 'Vihtavuori N140');
      await _insertRecipe(db, name: '3', powder: 'Hodgdon H4350');
      await _insertRecipe(db, name: '4', powder: 'Hodgdon H4350');
      final result = await repo.mostUsedComponentNames('powder');
      expect(result, ['Hodgdon H4350', 'Vihtavuori N140']);
    });

    test('skips null and whitespace-only values', () async {
      await _insertRecipe(db, name: '1', powder: 'Varget');
      await _insertRecipe(db, name: '2', powder: '   ');
      await _insertRecipe(db, name: '3', powder: '');
      await _insertRecipe(db, name: '4'); // null powder
      final result = await repo.mostUsedComponentNames('powder');
      expect(result, ['Varget']);
    });

    test('limit caps result length', () async {
      for (var i = 0; i < 10; i++) {
        await _insertRecipe(db, name: 'r$i', powder: 'Powder$i');
      }
      final top3 = await repo.mostUsedComponentNames('powder', limit: 3);
      expect(top3.length, 3);
      final top1 = await repo.mostUsedComponentNames('powder', limit: 1);
      expect(top1.length, 1);
    });

    test('unknown kinds return empty list', () async {
      await _insertRecipe(db, name: '1', powder: 'Varget');
      expect(await repo.mostUsedComponentNames('unknown'), isEmpty);
      expect(await repo.mostUsedComponentNames('powder_lot'), isEmpty);
      expect(await repo.mostUsedComponentNames(''), isEmpty);
    });

    test('each kind queries its own column', () async {
      await _insertRecipe(
        db,
        name: 'shared',
        powder: 'Varget',
        bullet: 'MatchKing',
        primer: 'BR-2',
        brass: 'Lapua',
        caliber: '6.5 Creedmoor',
      );
      expect(await repo.mostUsedComponentNames('powder'), ['Varget']);
      expect(await repo.mostUsedComponentNames('bullet'), ['MatchKing']);
      expect(await repo.mostUsedComponentNames('primer'), ['BR-2']);
      expect(await repo.mostUsedComponentNames('brass'), ['Lapua']);
      expect(await repo.mostUsedComponentNames('cartridge'), ['6.5 Creedmoor']);
    });

    test('default limit is 5', () async {
      for (var i = 0; i < 10; i++) {
        await _insertRecipe(db, name: 'r$i', powder: 'Powder$i');
      }
      final result = await repo.mostUsedComponentNames('powder');
      expect(result.length, 5);
    });
  });
}
