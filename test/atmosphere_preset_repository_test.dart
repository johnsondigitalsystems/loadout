// FILE: test/atmosphere_preset_repository_test.dart
//
// Unit tests for `lib/repositories/atmosphere_preset_repository.dart`.
// Mirrors the in-memory drift pattern used by `factory_load_repository_test.dart`
// and the rest of the repository tests. Verifies CRUD round-trips and the
// natural-sort ordering of `watchAll()`.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loadout/database/database.dart';
import 'package:loadout/repositories/atmosphere_preset_repository.dart';

void main() {
  group('AtmospherePresetRepository', () {
    late AppDatabase db;
    late AtmospherePresetRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = AtmospherePresetRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('insert + readback persists every column', () async {
      final id = await repo.insert(
        AtmospherePresetsCompanion.insert(
          name: 'Camp Atterbury summer',
          stationPressureInHg: 28.7,
          temperatureF: 88,
          humidityPct: 62,
          altitudeFt: const Value(720),
          latitudeDeg: const Value(39.346),
          longitudeDeg: const Value(-86.024),
          notes: const Value('Mid-day match conditions'),
        ),
      );
      expect(id, greaterThan(0));

      final row = await repo.getById(id);
      expect(row, isNotNull);
      expect(row!.name, 'Camp Atterbury summer');
      expect(row.stationPressureInHg, closeTo(28.7, 1e-6));
      expect(row.temperatureF, closeTo(88, 1e-6));
      expect(row.humidityPct, closeTo(62, 1e-6));
      expect(row.altitudeFt, closeTo(720, 1e-6));
      expect(row.latitudeDeg, closeTo(39.346, 1e-6));
      expect(row.longitudeDeg, closeTo(-86.024, 1e-6));
      expect(row.notes, 'Mid-day match conditions');
      expect(row.createdAt, isNotNull);
      expect(row.updatedAt, isNotNull);
    });

    test('non-ASCII / apostrophe / quote names round-trip cleanly', () async {
      final names = <String>[
        "O'Connor's range",
        '"Big Sandy" — fall',
        'Tirée Élysée 50°N',
      ];
      final ids = <int>[];
      for (final name in names) {
        final id = await repo.insert(
          AtmospherePresetsCompanion.insert(
            name: name,
            stationPressureInHg: 29.92,
            temperatureF: 59,
            humidityPct: 50,
          ),
        );
        ids.add(id);
      }
      for (var i = 0; i < ids.length; i++) {
        final row = await repo.getById(ids[i]);
        expect(row, isNotNull);
        expect(row!.name, names[i]);
      }
    });

    test('insert without optional fields leaves them null', () async {
      final id = await repo.insert(
        AtmospherePresetsCompanion.insert(
          name: 'Bare bones',
          stationPressureInHg: 29.92,
          temperatureF: 59,
          humidityPct: 50,
        ),
      );
      final row = await repo.getById(id);
      expect(row, isNotNull);
      expect(row!.altitudeFt, isNull);
      expect(row.latitudeDeg, isNull);
      expect(row.longitudeDeg, isNull);
      expect(row.notes, isNull);
    });

    test('update writes new values and bumps updatedAt', () async {
      final id = await repo.insert(
        AtmospherePresetsCompanion.insert(
          name: 'Big Sandy',
          stationPressureInHg: 25.4,
          temperatureF: 95,
          humidityPct: 22,
        ),
      );
      final originalUpdatedAt = (await repo.getById(id))!.updatedAt;
      // Sleep a tick so the bumped updatedAt strictly exceeds the original.
      // Drift's DateTime columns persist to second precision on SQLite, so
      // 5ms isn't enough — sleep a full second to guarantee a strictly
      // greater timestamp on read-back.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final ok = await repo.update(
        id,
        AtmospherePresetsCompanion(
          name: const Value('Big Sandy (updated)'),
          temperatureF: const Value(101),
          notes: const Value('Hotter than expected'),
        ),
      );
      expect(ok, isTrue);
      final row = await repo.getById(id);
      expect(row, isNotNull);
      expect(row!.name, 'Big Sandy (updated)');
      expect(row.temperatureF, closeTo(101, 1e-6));
      expect(row.stationPressureInHg, closeTo(25.4, 1e-6));
      expect(row.humidityPct, closeTo(22, 1e-6));
      expect(row.notes, 'Hotter than expected');
      expect(row.updatedAt.isAfter(originalUpdatedAt), isTrue);
    });

    test('update of non-existent id returns false', () async {
      final ok = await repo.update(
        999999,
        AtmospherePresetsCompanion(name: const Value('Nope')),
      );
      expect(ok, isFalse);
    });

    test('delete removes the row and the watchAll stream reflects it',
        () async {
      final id = await repo.insert(
        AtmospherePresetsCompanion.insert(
          name: 'Cold dry day',
          stationPressureInHg: 29.20,
          temperatureF: 28,
          humidityPct: 30,
        ),
      );
      // First emission: contains the new row.
      final initial = await repo.watchAll().first;
      expect(initial.map((r) => r.name).toList(), ['Cold dry day']);

      final deleted = await repo.delete(id);
      expect(deleted, 1);

      // After delete, watchAll's next emission should be empty.
      final next = await repo.watchAll().first;
      expect(next, isEmpty);

      final row = await repo.getById(id);
      expect(row, isNull);
    });

    test('watchAll orders rows naturally by name', () async {
      // Insertion order intentionally scrambled so we can prove the sort
      // is by name, not by id.
      final names = <String>[
        'Camp Atterbury #10',
        'Big Sandy',
        'Camp Atterbury #2',
        'Camp Atterbury #1',
        'Cold dry day',
      ];
      for (final n in names) {
        await repo.insert(
          AtmospherePresetsCompanion.insert(
            name: n,
            stationPressureInHg: 29.92,
            temperatureF: 59,
            humidityPct: 50,
          ),
        );
      }
      final rows = await repo.watchAll().first;
      expect(
        rows.map((r) => r.name).toList(),
        // Natural sort: numeric runs compared as numbers, so "#2" < "#10".
        const [
          'Big Sandy',
          'Camp Atterbury #1',
          'Camp Atterbury #2',
          'Camp Atterbury #10',
          'Cold dry day',
        ],
      );
    });

    test('getAll matches watchAll snapshot ordering', () async {
      final names = <String>['Z', 'A', 'M'];
      for (final n in names) {
        await repo.insert(
          AtmospherePresetsCompanion.insert(
            name: n,
            stationPressureInHg: 29.92,
            temperatureF: 59,
            humidityPct: 50,
          ),
        );
      }
      final all = await repo.getAll();
      expect(all.map((r) => r.name).toList(), ['A', 'M', 'Z']);
    });

    test('getById returns null for unknown id', () async {
      expect(await repo.getById(424242), isNull);
    });
  });

  group('AppDatabase.wipeUserData() with atmosphere presets', () {
    test('clears every atmosphere preset row', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async => db.close());
      final repo = AtmospherePresetRepository(db);
      await repo.insert(
        AtmospherePresetsCompanion.insert(
          name: 'To be wiped',
          stationPressureInHg: 29.92,
          temperatureF: 59,
          humidityPct: 50,
        ),
      );
      expect((await repo.getAll()).length, 1);
      await db.wipeUserData();
      expect((await repo.getAll()).length, 0);
    });
  });
}
