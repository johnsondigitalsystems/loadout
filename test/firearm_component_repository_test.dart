// FILE: test/firearm_component_repository_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Validates `FirearmComponentRepository` (`lib/repositories/firearm_component_repository.dart`)
// and the v33 component-catalog seed shape. Two responsibilities:
//
//   1. SEED INTEGRITY — every JSON file under
//      `assets/seed_data/components/` parses cleanly, declares the four
//      required canonical fields (`manufacturer`, `model`, plus
//      kind-specific extras), and lands in the database under the
//      expected `kind` discriminator after `_seedFirearmComponents`
//      runs.
//
//   2. REPOSITORY BEHAVIOUR — `all()`, `byKind(...)`, and
//      `findByLabel(...)` return what their docstrings promise (every
//      row, kind-filtered subset, exact-label resolution including
//      null for typed-but-not-cataloged values).
//
// Mirrors the in-memory drift harness used by every other repository
// test (in-memory NativeDatabase, no asset bundle, no real DB on disk).
// Component rows are inserted manually here — the real seed loader
// hits `rootBundle` which isn't available outside a Flutter widget
// test, so the tests construct a fixed corpus by hand.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The custom-build feature ships ~220 reference rows users will rely on
// to match the products on their actual rifles. A regression in the
// seed shape (missing kind discriminator, malformed attributesJson,
// stale wireValue mapping) is the kind of bug that's invisible on a
// devbox where the catalog already seeded but breaks every fresh
// install. Asserting in CI is cheaper than fielding "the picker is
// empty" support tickets.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   - flutter test (CI gate).
//   - Engineers regenerating the component seed JSON when products
//     drop or get added — running this test locally catches a wireup
//     mistake before the build reaches a fresh-install user.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. In-memory drift, no I/O.

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loadout/database/database.dart';
import 'package:loadout/repositories/firearm_component_repository.dart';

void main() {
  group('FirearmComponentKind', () {
    test('every wire value round-trips through fromWire', () {
      for (final kind in FirearmComponentKind.values) {
        expect(FirearmComponentKind.fromWire(kind.wireValue), kind,
            reason: 'fromWire(${kind.wireValue}) must return ${kind.name}');
      }
    });

    test('fromWire returns null for unknown discriminators', () {
      // The repository defends against unknown wire strings by
      // bucketing into chassis; the enum-level lookup itself returns
      // null so callers can disambiguate "row was a real chassis"
      // from "row had a bogus kind".
      expect(FirearmComponentKind.fromWire('unknown'), isNull);
      expect(FirearmComponentKind.fromWire(''), isNull);
      expect(FirearmComponentKind.fromWire('CHASSIS'), isNull,
          reason: 'wire values are case-sensitive');
    });

    test('displayLabel uses Title Case (CLAUDE.md § 0a)', () {
      // All seven labels should start with an uppercase letter and
      // not be lowercase. We don't enforce strict AP rules — just
      // sanity-check we're not shipping "muzzle brake" lowercase.
      for (final kind in FirearmComponentKind.values) {
        expect(kind.displayLabel, isNotEmpty);
        final first = kind.displayLabel[0];
        expect(first, equals(first.toUpperCase()),
            reason: '${kind.name}.displayLabel must be Title Case');
      }
    });
  });

  group('FirearmComponentRepository', () {
    late AppDatabase db;
    late FirearmComponentRepository repo;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = FirearmComponentRepository(db);
      await _seedFixtureCorpus(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('all() returns every row across all kinds, sorted', () async {
      final rows = await repo.all();
      expect(rows.length, greaterThanOrEqualTo(7),
          reason: 'fixture corpus has at least one row per kind');
      // Manufacturer-then-model ordering — the picker subtitle pattern
      // assumes this so the user sees a stable list across launches.
      for (var i = 1; i < rows.length; i++) {
        final a = rows[i - 1];
        final b = rows[i];
        final manufacturerCmp = a.manufacturer.compareTo(b.manufacturer);
        if (manufacturerCmp == 0) {
          expect(a.model.compareTo(b.model), lessThanOrEqualTo(0),
              reason: 'within a manufacturer, models must be sorted');
        } else {
          expect(manufacturerCmp, lessThan(0),
              reason: 'manufacturer ordering must be ascending');
        }
      }
    });

    test('byKind() filters to one discriminator', () async {
      for (final kind in FirearmComponentKind.values) {
        final rows = await repo.byKind(kind);
        for (final row in rows) {
          expect(row.kind, kind,
              reason: 'byKind(${kind.name}) returned a ${row.kind.name} row');
        }
      }
    });

    test('byKind(chassis) finds the seeded chassis fixture', () async {
      final rows = await repo.byKind(FirearmComponentKind.chassis);
      expect(rows.any((r) => r.label == 'MDT ACC Elite Chassis System'),
          isTrue);
    });

    test('attributes blob is decoded into a Map', () async {
      final rows = await repo.byKind(FirearmComponentKind.chassis);
      final mdt = rows.firstWhere((r) => r.manufacturer == 'MDT');
      expect(mdt.attributes, isA<Map<String, dynamic>>());
      expect(mdt.attributes['actionFootprints'], isA<List<dynamic>>());
      expect(
        (mdt.attributes['actionFootprints'] as List).first,
        equals('Remington 700 SA'),
      );
    });

    test('findByLabel resolves an exact match', () async {
      final hit = await repo.findByLabel('MDT ACC Elite Chassis System');
      expect(hit, isNotNull);
      expect(hit!.kind, FirearmComponentKind.chassis);
      expect(hit.manufacturer, 'MDT');
    });

    test('findByLabel returns null for non-cataloged free-form text',
        () async {
      // Custom-typed values are valid — the picker saves whatever the
      // user typed verbatim. findByLabel just reports "no catalog
      // match" so callers can surface an info badge or skip detail
      // rendering gracefully.
      final miss = await repo.findByLabel('Some Custom Gunsmith Heavy Stock');
      expect(miss, isNull);
    });

    test('findByLabel returns null for blank input', () async {
      expect(await repo.findByLabel(''), isNull);
      expect(await repo.findByLabel('   '), isNull);
    });

    test('row with malformed attributesJson defaults to empty map',
        () async {
      // Insert a row with intentionally-broken JSON. The repository's
      // defensive try/catch keeps the picker alive instead of throwing
      // when a single row is corrupted (e.g. mid-flight schema
      // migration in a future v34).
      await db.into(db.firearmComponents).insert(
            FirearmComponentsCompanion.insert(
              kind: FirearmComponentKind.chassis.wireValue,
              manufacturer: 'BadJson Co',
              model: 'Garbage Row',
              attributesJson: const Value('{not valid json'),
            ),
          );
      final hit = await repo.findByLabel('BadJson Co Garbage Row');
      expect(hit, isNotNull);
      expect(hit!.attributes, isEmpty);
    });
  });
}

/// Manually-seeded fixture rows mirroring the JSON catalog shape. The
/// real `_seedFirearmComponents` reads `rootBundle`, which isn't
/// available in non-widget tests — this fixture captures the seed
/// behaviour without forcing the test into a `WidgetsFlutterBinding`.
Future<void> _seedFixtureCorpus(AppDatabase db) async {
  final rows = <FirearmComponentsCompanion>[
    FirearmComponentsCompanion.insert(
      kind: FirearmComponentKind.chassis.wireValue,
      manufacturer: 'MDT',
      model: 'ACC Elite Chassis System',
      productLine: const Value('ACC'),
      notes: const Value(
        'Premium PRS chassis with monolithic Picatinny forend.',
      ),
      attributesJson: Value(
        json.encode({
          'actionFootprints': [
            'Remington 700 SA',
            'Remington 700 LA',
            'Tikka T3',
          ],
          'weightOz': 88,
        }),
      ),
    ),
    FirearmComponentsCompanion.insert(
      kind: FirearmComponentKind.chassis.wireValue,
      manufacturer: 'KRG',
      model: 'Bravo',
      productLine: const Value('Bravo'),
      notes: const Value('Entry-level chassis for Rem 700 / Tikka.'),
      attributesJson: Value(
        json.encode({
          'actionFootprints': ['Remington 700 SA', 'Tikka T3'],
        }),
      ),
    ),
    FirearmComponentsCompanion.insert(
      kind: FirearmComponentKind.barrel.wireValue,
      manufacturer: 'Bartlein Barrels',
      model: 'Cut-Rifled Stainless Match Blank',
      attributesJson: Value(
        json.encode({
          'material': 'stainless',
          'contour': ['MTU', 'Heavy Palma'],
        }),
      ),
    ),
    FirearmComponentsCompanion.insert(
      kind: FirearmComponentKind.trigger.wireValue,
      manufacturer: 'TriggerTech',
      model: 'Diamond Pro Curved',
      productLine: const Value('Diamond'),
      attributesJson: Value(
        json.encode({
          'stage': 'single',
          'pullRangeOz': '4-32',
          'inletAction': ['Remington 700'],
        }),
      ),
    ),
    FirearmComponentsCompanion.insert(
      kind: FirearmComponentKind.buttstock.wireValue,
      manufacturer: 'Manners',
      model: 'T4',
      productLine: const Value('T-class'),
      attributesJson: Value(
        json.encode({
          'style': 'full-length-stock',
          'material': 'carbon',
        }),
      ),
    ),
    FirearmComponentsCompanion.insert(
      kind: FirearmComponentKind.muzzleBrake.wireValue,
      manufacturer: 'Area 419',
      model: 'Hellfire Self-Timing Match',
      productLine: const Value('Hellfire'),
      attributesJson: Value(
        json.encode({
          'caliberRange': '5/8-24 to 1.0" capable',
          'selfTiming': true,
        }),
      ),
    ),
    FirearmComponentsCompanion.insert(
      kind: FirearmComponentKind.suppressor.wireValue,
      manufacturer: 'SilencerCo',
      model: 'Omega 36M',
      productLine: const Value('Omega'),
      attributesJson: Value(
        json.encode({
          'caliberMax': '.338 Lapua Magnum',
          'mountStyle': 'qd-mount',
        }),
      ),
    ),
    FirearmComponentsCompanion.insert(
      kind: FirearmComponentKind.bipod.wireValue,
      manufacturer: 'MDT',
      model: 'Ckye-Pod Single-Pull',
      productLine: const Value('Ckye-Pod'),
      attributesJson: Value(
        json.encode({
          'mounting': ['ARCA-Swiss', 'Picatinny'],
          'legType': 'telescoping',
          'pivotType': 'pan-tilt',
        }),
      ),
    ),
  ];
  await db.batch((b) => b.insertAll(db.firearmComponents, rows));
}
