// FILE: test/component_repository_names_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Drift round-trip tests for the Phase Two Group 3 (2026-05-15)
// `ComponentRepository.componentNames(kind)` method — the new
// bare-name accessor that replaced the buggy prefix-strip
// workaround in `photo_import_screen.dart` and
// `text_import_service.dart`.
//
// Tests:
//   1. `componentNames('powder')` returns bare `Powders.name`
//      strings (no manufacturer prefix), confirming the
//      "Hodgdon H4350" -> "H4350" canonicalisation works without
//      the fragile split-on-space approach.
//   2. The previously-broken examples from the Phase Two spec
//      (`"Western Powders Ramshot Hunter"`,
//      `"Vihtavuori"` as a bare-manufacturer label) are handled
//      correctly via the direct-column read.
//   3. `componentNames('primer')` returns bare `Primers.name`
//      strings (no `#` prefix, no manufacturer prefix).
//   4. `componentNames('bullet')` composes `line + weight` since
//      a bare `line` collides across weights.
//   5. `componentNames('brass')` and `componentNames('cartridge')`
//      delegate to `componentLabels` — same list, same order.
//   6. Custom components (via `addCustomComponent`) appear in
//      the returned list for the relevant kind.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The Phase Two Group 3 spec deviation surfaced that the `Powders`
// schema was already structurally correct (FK to `Manufacturers` +
// bare `name`); only the consuming code was buggy. The fix was a
// minimum-change addition of `componentNames(kind)` to the
// repository — no schema bump, no JSON rewrite. These tests pin
// the bare-name contract so a future refactor can't reintroduce
// the prefix-strip dependency.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// - The repository's `componentNames` for `brass` / `cartridge`
//   delegates to `componentLabels`. The tests assert behavior, not
//   implementation — verifying that the list shape is the same is
//   what matters; whether it's delegated or recomputed is internal.
// - Tests seed `Manufacturers` + `Powders` / `Primers` / `Bullets`
//   rows manually rather than via `SeedLoader` because the seed
//   loader hits `rootBundle` which isn't available in unit tests.
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

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loadout/database/database.dart';
import 'package:loadout/repositories/component_repository.dart';

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

  Future<int> insertManufacturer(String name, String kind) async {
    return db.into(db.manufacturers).insert(
          ManufacturersCompanion.insert(name: name, kind: kind),
        );
  }

  Future<void> insertPowder(String name, int mfgId) async {
    await db.into(db.powders).insert(
          PowdersCompanion.insert(
            manufacturerId: mfgId,
            name: name,
            type: 'rifle',
          ),
        );
  }

  Future<void> insertPrimer(String name, String size, int mfgId) async {
    await db.into(db.primers).insert(
          PrimersCompanion.insert(
            manufacturerId: mfgId,
            name: name,
            size: size,
          ),
        );
  }

  Future<void> insertBullet(
    String line,
    int mfgId, {
    double diameterIn = 0.264,
    required double weightGr,
  }) async {
    await db.into(db.bullets).insert(
          BulletsCompanion.insert(
            manufacturerId: mfgId,
            line: line,
            diameterIn: diameterIn,
            weightGr: weightGr,
          ),
        );
  }

  group('componentNames("powder")', () {
    test('returns bare Powders.name (no manufacturer prefix)',
        () async {
      final hodgdon = await insertManufacturer('Hodgdon', 'powder');
      await insertPowder('H4350', hodgdon);
      await insertPowder('Varget', hodgdon);

      final names = await repo.componentNames('powder');
      // H4350 sorts numerically after Varget; assert membership
      // not order.
      expect(names, containsAll(['H4350', 'Varget']));
      // Crucially, neither entry includes "Hodgdon".
      for (final n in names) {
        expect(n, isNot(contains('Hodgdon')),
            reason: 'componentNames must NOT include the '
                'manufacturer prefix');
      }
    });

    test(
        'handles two-word manufacturer names correctly '
        '(the bug the prefix-strip workaround had)', () async {
      // Pre-Phase-Two-Group-3 the prefix-strip workaround did
      // `label.split(' ').sublist(1).join(' ')` on each label.
      // For "Western Powders Ramshot Hunter" that produced
      // "Powders Ramshot Hunter" — the strip ate one word of
      // the manufacturer, leaving "Powders" as a fake prefix on
      // the bare name. The new method reads `Powders.name`
      // directly so the manufacturer's word count is irrelevant.
      final westernPowders =
          await insertManufacturer('Western Powders', 'powder');
      await insertPowder('Ramshot Hunter', westernPowders);

      final names = await repo.componentNames('powder');
      expect(names, contains('Ramshot Hunter'));
      // The buggy strip would have left "Powders Ramshot Hunter"
      // — make sure we don't.
      expect(names, isNot(contains('Powders Ramshot Hunter')));
    });

    test('includes custom-added powder names', () async {
      final hodgdon = await insertManufacturer('Hodgdon', 'powder');
      await insertPowder('H4350', hodgdon);
      await repo.addCustomComponent('powder', 'CustomBlackPowder42');

      final names = await repo.componentNames('powder');
      expect(names, containsAll(['H4350', 'CustomBlackPowder42']));
    });
  });

  group('componentNames("primer")', () {
    test(
        'returns bare Primers.name (no manufacturer prefix, no `#` '
        'prefix)', () async {
      final federal = await insertManufacturer('Federal', 'primer');
      await insertPrimer('210M', 'large rifle', federal);
      await insertPrimer('205', 'small rifle', federal);

      final names = await repo.componentNames('primer');
      expect(names, containsAll(['210M', '205']));
      for (final n in names) {
        expect(n, isNot(startsWith('#')),
            reason: '`#` prefix is a label-formatting concern');
        expect(n, isNot(contains('Federal')));
      }
    });
  });

  group('componentNames("bullet")', () {
    test(
        'composes "line + weight" (line alone collides across '
        'weights)', () async {
      final berger = await insertManufacturer('Berger', 'bullet');
      await insertBullet('Hybrid', berger, weightGr: 105);
      await insertBullet('Hybrid', berger, weightGr: 115);
      await insertBullet('Hybrid', berger, weightGr: 140);

      final names = await repo.componentNames('bullet');
      expect(names, containsAll([
        'Hybrid 105gr',
        'Hybrid 115gr',
        'Hybrid 140gr',
      ]));
      // Crucially, no manufacturer prefix.
      for (final n in names) {
        expect(n, isNot(contains('Berger')));
      }
    });

    test('formats fractional weights with one decimal', () async {
      final lehigh = await insertManufacturer('Lehigh Defense', 'bullet');
      await insertBullet('Xtreme Defense', lehigh, weightGr: 87.5);

      final names = await repo.componentNames('bullet');
      expect(names, contains('Xtreme Defense 87.5gr'));
    });
  });

  group('componentNames delegates for kinds without brand+name', () {
    test('brass returns same shape as componentLabels (manufacturer only)',
        () async {
      final lapua = await insertManufacturer('Lapua', 'brass');
      await db.into(db.brassProducts).insert(
            BrassProductsCompanion.insert(
              manufacturerId: lapua,
              tier: const Value('match'),
              calibersJson: const Value('["6.5 Creedmoor"]'),
            ),
          );

      final names = await repo.componentNames('brass');
      final labels = await repo.componentLabels('brass');
      expect(names, equals(labels),
          reason: 'brass has no separate bare name — delegates');
    });

    test('cartridge returns same shape as componentLabels (name only)',
        () async {
      await db.into(db.cartridges).insert(
            CartridgesCompanion.insert(
              name: '6.5 Creedmoor',
              type: 'rifle',
            ),
          );
      await db.into(db.cartridges).insert(
            CartridgesCompanion.insert(
              name: '.308 Winchester',
              type: 'rifle',
            ),
          );

      final names = await repo.componentNames('cartridge');
      final labels = await repo.componentLabels('cartridge');
      expect(names, equals(labels));
    });
  });
}
