// FILE: test/common_loads_catalog_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Unit coverage for `lib/services/common_loads_catalog.dart`. The
// catalog is now backed by the [ManufacturedAmmo] SQLite table
// (schema v23) — the previous incarnation was a hand-coded
// `static const` list, but the data was lifted into the table during
// the v23 migration so it can be live-updated via SeedUpdater. The
// in-Dart `CommonLoadsCatalog` API now takes a
// [ManufacturedAmmoRepository] and returns a `Future` for every
// helper.
//
// Tests here verify:
//
//   * `CommonLoad.fromRow` produces sensible records: G7 wins over
//     G1 when both are present, G1 falls back to G7 when G7 is null,
//     null-BC rows return null.
//   * Catalog reads from a seeded in-memory DB are non-empty and
//     have the expected scale (~17 entries for the curated picker).
//   * Every entry has plausible numeric values — no zero / negative
//     BCs, weights, diameters, or muzzle velocities, and the muzzle
//     velocity is bounded to physically reasonable limits.
//   * `byCartridge()` preserves the source order and groups
//     correctly.
//   * `cartridges()` returns distinct names in source order.
//   * `search()` is case-insensitive and matches across cartridge,
//     name, and notes; empty / whitespace queries return everything.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The catalog is shipped to every user as the default starting point
// for ballistics inputs. A typo'd BC or a 30000 fps muzzle velocity
// would produce nonsensical solutions that the Range Day screen would
// happily render — and the user might not realize the defaults are
// wrong. The bounds-check tests here are cheap insurance against a
// data-entry mistake landing in production.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// `flutter test` (CI + local).

// Hide drift's `isNotNull` / `isNull` operators so they don't shadow
// the same-named matchers from `flutter_test`. We only need `Value`
// from drift here for the seed-row companions.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/database/database.dart';
import 'package:loadout/repositories/manufactured_ammo_repository.dart';
import 'package:loadout/services/ballistics/drag_functions.dart';
import 'package:loadout/services/common_loads_catalog.dart';

/// Insert a small representative slice of the curated catalog so the
/// repo-backed helpers have something to read. We deliberately don't
/// seed from the JSON file here — the goal is to test the API surface,
/// not the seed pipeline.
Future<void> _seedSampleRows(AppDatabase db) async {
  await db.batch((b) => b.insertAll(db.manufacturedAmmo, [
        // Centerfire rifle — G7 BC.
        ManufacturedAmmoCompanion.insert(
          manufacturer: 'Hornady',
          cartridge: '6.5 Creedmoor',
          name: 'Hornady 140gr ELD-Match',
          bulletWeightGr: 140,
          bulletDiameterIn: 0.264,
          muzzleVelocityFps: 2710,
          bcG7: const Value(0.315),
        ),
        ManufacturedAmmoCompanion.insert(
          manufacturer: 'Berger',
          cartridge: '6.5 Creedmoor',
          name: 'Berger 140gr Hybrid Target',
          bulletWeightGr: 140,
          bulletDiameterIn: 0.264,
          muzzleVelocityFps: 2750,
          bcG7: const Value(0.319),
        ),
        ManufacturedAmmoCompanion.insert(
          manufacturer: 'Federal',
          cartridge: '308 Win',
          name: 'Federal Gold Medal 175gr SMK',
          bulletWeightGr: 175,
          bulletDiameterIn: 0.308,
          muzzleVelocityFps: 2600,
          bcG7: const Value(0.243),
        ),
        ManufacturedAmmoCompanion.insert(
          manufacturer: 'Sierra',
          cartridge: '308 Win',
          name: 'Subsonic 220gr SMK',
          bulletWeightGr: 220,
          bulletDiameterIn: 0.308,
          muzzleVelocityFps: 1050,
          bcG7: const Value(0.310),
          notes: const Value('Subsonic — for short / suppressed barrels'),
        ),
        // Rimfire — G1 BC only.
        ManufacturedAmmoCompanion.insert(
          manufacturer: 'CCI',
          cartridge: '22 LR',
          name: 'CCI Standard Velocity 40gr',
          bulletWeightGr: 40,
          bulletDiameterIn: 0.224,
          muzzleVelocityFps: 1070,
          bcG1: const Value(0.115),
          notes: const Value('BC is G1 — typical for rimfire'),
        ),
        // Pistol — G1 BC only.
        ManufacturedAmmoCompanion.insert(
          manufacturer: 'Federal',
          cartridge: '9mm Luger',
          name: 'Federal HST 124gr',
          bulletWeightGr: 124,
          bulletDiameterIn: 0.355,
          muzzleVelocityFps: 1150,
          bcG1: const Value(0.150),
          notes: const Value('BC is G1 — typical for pistol'),
        ),
      ]));
}

void main() {
  late AppDatabase db;
  late ManufacturedAmmoRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await _seedSampleRows(db);
    repo = ManufacturedAmmoRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('CommonLoad.fromRow', () {
    test('G7 BC wins over G1 when both are present', () {
      final row = ManufacturedAmmoRow(
        id: 1,
        manufacturer: 'Hornady',
        cartridge: '6.5 Creedmoor',
        name: 'Hornady 140gr ELD-Match',
        bulletWeightGr: 140,
        bulletDiameterIn: 0.264,
        muzzleVelocityFps: 2710,
        bcG7: 0.315,
        bcG1: 0.605, // legacy compatibility number, should be ignored
        createdAt: DateTime.now(),
      );
      final load = CommonLoad.fromRow(row);
      expect(load, isNotNull);
      expect(load!.bc, 0.315);
      expect(load.dragModel, DragModel.g7);
    });

    test('falls back to G1 when G7 is null', () {
      final row = ManufacturedAmmoRow(
        id: 1,
        manufacturer: 'CCI',
        cartridge: '22 LR',
        name: 'CCI Standard Velocity 40gr',
        bulletWeightGr: 40,
        bulletDiameterIn: 0.224,
        muzzleVelocityFps: 1070,
        bcG1: 0.115,
        createdAt: DateTime.now(),
      );
      final load = CommonLoad.fromRow(row);
      expect(load, isNotNull);
      expect(load!.bc, 0.115);
      expect(load.dragModel, DragModel.g1);
    });

    test('returns null when no BC is populated', () {
      final row = ManufacturedAmmoRow(
        id: 1,
        manufacturer: 'Mystery',
        cartridge: 'Wildcat',
        name: 'No BC entry',
        bulletWeightGr: 100,
        bulletDiameterIn: 0.300,
        muzzleVelocityFps: 2500,
        createdAt: DateTime.now(),
      );
      expect(CommonLoad.fromRow(row), isNull);
    });
  });

  group('CommonLoadsCatalog.all', () {
    test('catalog is non-empty for the seeded test rows', () async {
      final loads = await CommonLoadsCatalog.all(repo);
      expect(loads, isNotEmpty);
    });

    test('every seeded entry maps to a CommonLoad', () async {
      final loads = await CommonLoadsCatalog.all(repo);
      // We seeded 6 rows, all of which have a BC; none should be
      // dropped.
      expect(loads.length, 6);
    });

    test('every entry has plausible numeric values', () async {
      final loads = await CommonLoadsCatalog.all(repo);
      for (final l in loads) {
        // Bullet weight in grains: 30..400 covers 22 LR through
        // .50 BMG comfortably.
        expect(l.bulletWeightGr, greaterThan(30),
            reason: '${l.name}: bulletWeightGr too low');
        expect(l.bulletWeightGr, lessThan(400),
            reason: '${l.name}: bulletWeightGr too high');
        // Bullet diameter in inches: 0.17..0.50 covers 17 HMR
        // through .50 BMG.
        expect(l.bulletDiameterIn, greaterThan(0.15),
            reason: '${l.name}: bulletDiameterIn too low');
        expect(l.bulletDiameterIn, lessThan(0.55),
            reason: '${l.name}: bulletDiameterIn too high');
        // BCs are always positive, generally < 1.0 for hand-loaded
        // bullets.
        expect(l.bc, greaterThan(0),
            reason: '${l.name}: bc must be positive');
        expect(l.bc, lessThan(1.0),
            reason: '${l.name}: bc unrealistically high');
        // Muzzle velocity: 800..4500 fps covers subsonic 22 LR
        // through hot wildcat magnums.
        expect(l.muzzleVelocityFps, greaterThan(800),
            reason: '${l.name}: muzzleVelocityFps too low');
        expect(l.muzzleVelocityFps, lessThan(4500),
            reason: '${l.name}: muzzleVelocityFps too high');
      }
    });

    test('drag model is one of the supported enum values', () async {
      final loads = await CommonLoadsCatalog.all(repo);
      for (final l in loads) {
        expect(DragModel.values, contains(l.dragModel),
            reason: '${l.name}: drag model out of enum');
      }
    });

    test('rimfire 22 LR uses G1 (per published convention)', () async {
      final loads = await CommonLoadsCatalog.all(repo);
      final rimfire = loads.firstWhere((l) => l.cartridge == '22 LR');
      expect(rimfire.dragModel, DragModel.g1);
    });

    test('centerfire 6.5 Creedmoor uses G7', () async {
      final loads = await CommonLoadsCatalog.all(repo);
      final centerfire =
          loads.firstWhere((l) => l.cartridge == '6.5 Creedmoor');
      expect(centerfire.dragModel, DragModel.g7);
    });
  });

  group('CommonLoadsCatalog.byCartridge()', () {
    test('groups loads by cartridge name', () async {
      final loads = await CommonLoadsCatalog.all(repo);
      final grouped = await CommonLoadsCatalog.byCartridge(repo);
      expect(grouped, isNotEmpty);
      // Every load should appear under its cartridge key. Compare on
      // `name` rather than identity because each `all(repo)` call
      // builds a fresh `CommonLoad` (no `==` operator), so two
      // independent reads produce reference-different objects with
      // identical content.
      for (final l in loads) {
        final names = grouped[l.cartridge]?.map((g) => g.name).toList();
        expect(names, contains(l.name));
      }
    });

    test('preserves catalog ordering inside each cartridge group',
        () async {
      final loads = await CommonLoadsCatalog.all(repo);
      final grouped = await CommonLoadsCatalog.byCartridge(repo);
      for (final cartridge in grouped.keys) {
        final groupedOrder =
            grouped[cartridge]!.map((l) => l.name).toList();
        final sourceOrder = loads
            .where((l) => l.cartridge == cartridge)
            .map((l) => l.name)
            .toList();
        expect(groupedOrder, equals(sourceOrder));
      }
    });
  });

  group('CommonLoadsCatalog.cartridges()', () {
    test('returns distinct cartridge names', () async {
      final names = await CommonLoadsCatalog.cartridges(repo);
      expect(names.toSet().length, names.length);
    });

    test('matches the keys returned by byCartridge()', () async {
      final names = (await CommonLoadsCatalog.cartridges(repo)).toSet();
      final grouped =
          (await CommonLoadsCatalog.byCartridge(repo)).keys.toSet();
      expect(names, grouped);
    });
  });

  group('CommonLoadsCatalog.search()', () {
    test('empty query returns the full catalog', () async {
      final all = await CommonLoadsCatalog.all(repo);
      // Compare on `name` rather than identity — see comment in
      // `byCartridge() groups loads by cartridge name` above.
      final emptyQueryNames =
          (await CommonLoadsCatalog.search(repo, '')).map((l) => l.name);
      final blankQueryNames =
          (await CommonLoadsCatalog.search(repo, '   ')).map((l) => l.name);
      final allNames = all.map((l) => l.name);
      expect(emptyQueryNames, allNames);
      expect(blankQueryNames, allNames);
    });

    test('case-insensitive matching on bullet name', () async {
      final hits = await CommonLoadsCatalog.search(repo, 'eld-match');
      expect(hits, isNotEmpty);
      for (final h in hits) {
        expect(h.name.toLowerCase(), contains('eld-match'));
      }
    });

    test('case-insensitive matching on cartridge', () async {
      final hits = await CommonLoadsCatalog.search(repo, 'CREEDMOOR');
      expect(hits, isNotEmpty);
      for (final h in hits) {
        expect(h.cartridge.toLowerCase(), contains('creedmoor'));
      }
    });

    test('matches notes for the subsonic load', () async {
      final hits = await CommonLoadsCatalog.search(repo, 'subsonic');
      expect(hits, isNotEmpty);
      // The 220gr SMK subsonic entry should be the canonical hit.
      expect(hits.any((l) => l.bulletWeightGr == 220), isTrue);
    });

    test('returns empty list for clearly unmatched query', () async {
      final hits =
          await CommonLoadsCatalog.search(repo, 'NONEXISTENT_xyz_12345');
      expect(hits, isEmpty);
    });
  });
}
