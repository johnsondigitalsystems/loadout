// FILE: test/common_loads_catalog_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Unit coverage for `lib/services/common_loads_catalog.dart`. The
// catalog is hand-curated factory-load data the Range Day empty-state
// picker uses to seed sensible defaults for first-launch users with no
// saved recipes. Tests here verify:
//
//   * Catalog is non-empty and has the expected scale (~20 entries).
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

import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/services/ballistics/drag_functions.dart';
import 'package:loadout/services/common_loads_catalog.dart';

void main() {
  group('CommonLoadsCatalog.all', () {
    test('catalog is non-empty', () {
      expect(CommonLoadsCatalog.all, isNotEmpty);
    });

    test('catalog has at least 15 entries (curated for empty-state)', () {
      // The empty-state picker is supposed to feel like a real
      // catalog, not a placeholder. If someone slims this down
      // accidentally, surface it in CI.
      expect(CommonLoadsCatalog.all.length, greaterThanOrEqualTo(15));
    });

    test('every entry has plausible numeric values', () {
      for (final l in CommonLoadsCatalog.all) {
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

    test('drag model is one of the supported enum values', () {
      // Sanity: every load should land on a real drag model so the
      // Range Day picker doesn't crash trying to look one up.
      for (final l in CommonLoadsCatalog.all) {
        expect(DragModel.values, contains(l.dragModel),
            reason: '${l.name}: drag model out of enum');
      }
    });

    test('rimfire 22 LR uses G1 (per published convention)', () {
      final rimfire = CommonLoadsCatalog.all.firstWhere(
        (l) => l.cartridge == '22 LR',
      );
      expect(rimfire.dragModel, DragModel.g1);
    });

    test('centerfire 6.5 Creedmoor uses G7', () {
      final centerfire = CommonLoadsCatalog.all.firstWhere(
        (l) => l.cartridge == '6.5 Creedmoor',
      );
      expect(centerfire.dragModel, DragModel.g7);
    });
  });

  group('CommonLoadsCatalog.byCartridge()', () {
    test('groups loads by cartridge name', () {
      final grouped = CommonLoadsCatalog.byCartridge();
      expect(grouped, isNotEmpty);
      // Every load in `all` should appear under its cartridge key.
      for (final l in CommonLoadsCatalog.all) {
        expect(grouped[l.cartridge], contains(l));
      }
    });

    test('preserves catalog ordering inside each cartridge group', () {
      final grouped = CommonLoadsCatalog.byCartridge();
      // For each cartridge with > 1 entry, the grouped order must
      // match the order in `all`. (Otherwise the picker shows
      // entries in mystery order.)
      for (final cartridge in grouped.keys) {
        final groupedOrder =
            grouped[cartridge]!.map((l) => l.name).toList();
        final sourceOrder = CommonLoadsCatalog.all
            .where((l) => l.cartridge == cartridge)
            .map((l) => l.name)
            .toList();
        expect(groupedOrder, equals(sourceOrder));
      }
    });
  });

  group('CommonLoadsCatalog.cartridges()', () {
    test('returns distinct cartridge names', () {
      final names = CommonLoadsCatalog.cartridges();
      expect(names.toSet().length, names.length);
    });

    test('matches the keys returned by byCartridge()', () {
      final names = CommonLoadsCatalog.cartridges().toSet();
      final grouped = CommonLoadsCatalog.byCartridge().keys.toSet();
      expect(names, grouped);
    });
  });

  group('CommonLoadsCatalog.search()', () {
    test('empty query returns the full catalog', () {
      expect(CommonLoadsCatalog.search(''), CommonLoadsCatalog.all);
      expect(CommonLoadsCatalog.search('   '), CommonLoadsCatalog.all);
    });

    test('case-insensitive matching on bullet name', () {
      final hits = CommonLoadsCatalog.search('eld-match');
      expect(hits, isNotEmpty);
      for (final h in hits) {
        expect(h.name.toLowerCase(), contains('eld-match'));
      }
    });

    test('case-insensitive matching on cartridge', () {
      final hits = CommonLoadsCatalog.search('CREEDMOOR');
      // Both 6mm and 6.5 Creedmoor should land here.
      expect(hits, isNotEmpty);
      for (final h in hits) {
        expect(h.cartridge.toLowerCase(), contains('creedmoor'));
      }
    });

    test('matches notes for the subsonic load', () {
      final hits = CommonLoadsCatalog.search('subsonic');
      expect(hits, isNotEmpty);
      // The 220gr SMK subsonic entry should be the canonical hit.
      expect(hits.any((l) => l.bulletWeightGr == 220), isTrue);
    });

    test('returns empty list for clearly unmatched query', () {
      final hits = CommonLoadsCatalog.search('NONEXISTENT_xyz_12345');
      expect(hits, isEmpty);
    });
  });
}
