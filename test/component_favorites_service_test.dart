// FILE: test/component_favorites_service_test.dart
//
// Unit tests for `lib/services/component_favorites_service.dart`.
// The service is backed by drift (schema v25
// `UserComponentFavorites` table) with a one-time migration from
// the legacy SharedPreferences storage. Tests cover:
//
//   1. Fresh service — no favorites until hydration completes.
//   2. After hydration — favorites read from drift, properly
//      bucketed by `kind`.
//   3. `toggleFavorite` round-trips to drift (insert + delete).
//   4. `toggleFavorite` is a no-op for unsupported kinds and
//      empty / whitespace-only names.
//   5. The legacy SharedPreferences entries are migrated into
//      drift on first hydrate AND cleared from prefs (so a future
//      Cloud Sync pull can't be "shadowed" by stale prefs).
//
// The service uses `notifyListeners()` after every mutation; we
// don't pump a widget tree here — listeners are the consumer's
// concern, not the service's contract.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:loadout/database/database.dart';
import 'package:loadout/services/component_favorites_service.dart';

Future<void> _waitForHydration(ComponentFavoritesService svc) async {
  // Hydration kicks off in the constructor as a fire-and-forget
  // future. Spin until isHydrated flips so tests can assert
  // post-hydration state.
  for (var i = 0; i < 50; i++) {
    if (svc.isHydrated) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('ComponentFavoritesService never hydrated');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ComponentFavoritesService', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      // Reset SharedPreferences mock between tests so legacy-prefs
      // migration tests start from a known state.
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    tearDown(() async {
      await db.close();
    });

    test('reports nothing as favorited until hydrated, then empty', () async {
      final svc = ComponentFavoritesService(db);
      expect(svc.isHydrated, isFalse);
      expect(svc.favorites('powder'), isEmpty);
      await _waitForHydration(svc);
      expect(svc.favorites('powder'), isEmpty);
      expect(svc.favorites('bullet'), isEmpty);
      expect(svc.favorites('primer'), isEmpty);
      expect(svc.favorites('brass'), isEmpty);
    });

    test('toggleFavorite inserts then deletes', () async {
      final svc = ComponentFavoritesService(db);
      await _waitForHydration(svc);

      await svc.toggleFavorite('powder', 'Hodgdon Varget');
      expect(svc.isFavorite('powder', 'Hodgdon Varget'), isTrue);
      expect(svc.favorites('powder'), {'Hodgdon Varget'});

      // Persisted to drift?
      final rows =
          await db.select(db.userComponentFavorites).get();
      expect(rows.length, 1);
      expect(rows.first.kind, 'powder');
      expect(rows.first.name, 'Hodgdon Varget');

      await svc.toggleFavorite('powder', 'Hodgdon Varget');
      expect(svc.isFavorite('powder', 'Hodgdon Varget'), isFalse);
      expect(svc.favorites('powder'), isEmpty);
      final rowsAfterDelete =
          await db.select(db.userComponentFavorites).get();
      expect(rowsAfterDelete, isEmpty);
    });

    test('toggleFavorite trims whitespace before storing', () async {
      final svc = ComponentFavoritesService(db);
      await _waitForHydration(svc);
      await svc.toggleFavorite('powder', '  Varget   ');
      expect(svc.isFavorite('powder', 'Varget'), isTrue);
      expect(svc.isFavorite('powder', '  Varget   '), isTrue,
          reason: 'isFavorite checks against the trimmed canonical name');
    });

    test('toggleFavorite is a no-op for empty / whitespace names', () async {
      final svc = ComponentFavoritesService(db);
      await _waitForHydration(svc);
      await svc.toggleFavorite('powder', '');
      await svc.toggleFavorite('powder', '   ');
      expect(svc.favorites('powder'), isEmpty);
      final rows = await db.select(db.userComponentFavorites).get();
      expect(rows, isEmpty);
    });

    test('toggleFavorite is a no-op for unsupported kinds', () async {
      final svc = ComponentFavoritesService(db);
      await _waitForHydration(svc);
      await svc.toggleFavorite('cartridge', 'will-never-land');
      await svc.toggleFavorite('powder_lot', 'should-be-rejected');
      await svc.toggleFavorite('', 'no-kind');
      expect(svc.favorites('cartridge'), isEmpty);
      final rows = await db.select(db.userComponentFavorites).get();
      expect(rows, isEmpty);
    });

    test('different kinds are bucketed independently', () async {
      final svc = ComponentFavoritesService(db);
      await _waitForHydration(svc);
      await svc.toggleFavorite('powder', 'Varget');
      await svc.toggleFavorite('bullet', 'Sierra MatchKing');
      await svc.toggleFavorite('primer', 'CCI BR-2');
      await svc.toggleFavorite('brass', 'Lapua');

      expect(svc.favorites('powder'), {'Varget'});
      expect(svc.favorites('bullet'), {'Sierra MatchKing'});
      expect(svc.favorites('primer'), {'CCI BR-2'});
      expect(svc.favorites('brass'), {'Lapua'});
      expect(svc.isFavorite('powder', 'Sierra MatchKing'), isFalse,
          reason: 'cross-kind contamination would break the dropdown sort');
    });

    test('toggleFavorite is race-free under repeated calls', () async {
      final svc = ComponentFavoritesService(db);
      await _waitForHydration(svc);
      // Two parallel toggles shouldn't end up in an inconsistent
      // (kind, name) state. Final state should be "favorited" (odd
      // number of toggles) — but the cache + drift have to agree.
      await Future.wait([
        svc.toggleFavorite('powder', 'Varget'),
        svc.toggleFavorite('powder', 'Varget'),
        svc.toggleFavorite('powder', 'Varget'),
      ]);
      // The exact final state depends on ordering, but the cache
      // and drift must match.
      final cached = svc.isFavorite('powder', 'Varget');
      final rows = await (db.select(db.userComponentFavorites)
            ..where((t) => t.name.equals('Varget')))
          .get();
      expect(rows.length, cached ? 1 : 0,
          reason: 'in-memory cache and drift must agree after toggles');
    });

    test('one-time migration copies SharedPreferences keys into drift', () async {
      // Seed legacy v1 favorites in prefs.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'component_favorites_powder': <String>['Varget', 'H4350'],
        'component_favorites_bullet': <String>['Berger Hybrid'],
      });

      final svc = ComponentFavoritesService(db);
      await _waitForHydration(svc);

      expect(svc.favorites('powder'), {'Varget', 'H4350'});
      expect(svc.favorites('bullet'), {'Berger Hybrid'});

      final rows = await db.select(db.userComponentFavorites).get();
      expect(rows.length, 3);

      // Prefs entries cleared so they can't shadow a future Cloud
      // Sync pull.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('component_favorites_powder'), isNull);
      expect(prefs.getStringList('component_favorites_bullet'), isNull);
    });

    test('migration is idempotent on second hydrate', () async {
      // Seed legacy + pre-existing drift row to confirm dedup.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'component_favorites_powder': <String>['Varget'],
      });
      await db.into(db.userComponentFavorites).insert(
            UserComponentFavoritesCompanion.insert(
              kind: 'powder',
              name: 'Varget',
            ),
          );

      final svc = ComponentFavoritesService(db);
      await _waitForHydration(svc);
      // Should NOT have duplicated the row.
      final rows = await (db.select(db.userComponentFavorites)
            ..where((t) => t.name.equals('Varget')))
          .get();
      expect(rows.length, 1);
    });
  });
}
