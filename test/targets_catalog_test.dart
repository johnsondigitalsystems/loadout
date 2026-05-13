// FILE: test/targets_catalog_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Catalog-shape regression tests for `assets/seed_data/targets.json`.
// Phase 8 Group D rewrote every row's `name` field so the catalog
// directly drives the picker dropdown label (the dynamic
// `_targetDropdownLabel` generator was simplified to `=> t.name`).
// These tests pin the naming patterns so a future catalog edit
// can't silently regress the dropdown UX (e.g. by reintroducing
// duplicate-dimension IPSC names like
// `"IPSC USPSA Classic 18×30 in 18×30 in"` that Phase 8 fixed).
//
// Assertions covered:
//   * Row count is 59 (was 58 pre-Phase-8; +1 for the new
//     `2 in Square` row).
//   * `2 in Square` is present.
//   * Generic circles match `^\d+ in Circle$`.
//   * Generic squares match `^\d+ in Square$`.
//   * Generic rectangles match `^\d+(\.\d+)?" x \d+(\.\d+)?" Rectangle$`.
//   * Animal names all contain ` in` (the appended dims).
//   * IPSC names have NO duplicate dimensions — `count('×') <= 1`.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure JSON parse + regex / set assertions.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('targets.json — Phase 8 Group D catalog shape', () {
    late List<Map<String, dynamic>> rows;

    setUpAll(() {
      final raw =
          File('assets/seed_data/targets.json').readAsStringSync();
      rows = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    });

    test('91 rows total (Phase 9: 43 non-animal + 48 animals)', () {
      // Pre-Phase-9: 59 rows (43 non-animal + 16 animals).
      // Phase 9 Group B expanded each of 16 species to 3 sizes
      // (Small / Medium / Large), bringing the animal count to 48.
      expect(rows.length, 91);
    });

    test('48 animal rows total (16 species × 3 sizes)', () {
      final animals =
          rows.where((r) => r['category'] == 'animal').toList();
      expect(animals, hasLength(48));
    });

    test(
        'every animal has center_point.horizontal_from_left = 0.6 '
        '(Phase 9 — was 0.7 in Phase 7a/8)', () {
      final animals =
          rows.where((r) => r['category'] == 'animal').toList();
      for (final r in animals) {
        final cp = r['center_point'] as Map<String, dynamic>?;
        expect(cp, isNotNull,
            reason:
                "Animal '${r['name']}' is missing center_point");
        expect(cp!['horizontal_from_left'], 0.6,
            reason: "Animal '${r['name']}' has wrong "
                "horizontal_from_left (expected 0.6)");
      }
    });

    test(
        'each of 16 species has 3 size variants '
        '(Small / Medium / Large)', () {
      final animals =
          rows.where((r) => r['category'] == 'animal').toList();
      // Group by shape_id (each species should appear thrice).
      final bySpecies = <String, List<Map<String, dynamic>>>{};
      for (final r in animals) {
        final sid = r['shape_id'] as String?;
        if (sid == null) continue;
        bySpecies.putIfAbsent(sid, () => []).add(r);
      }
      expect(bySpecies, hasLength(16),
          reason: 'Expected 16 unique animal species; got '
              '${bySpecies.length}');
      for (final entry in bySpecies.entries) {
        expect(entry.value, hasLength(3),
            reason: "Species '${entry.key}' should have 3 size "
                "variants; got ${entry.value.length}");
        final names = entry.value.map((r) => r['name'] as String);
        expect(names.any((n) => n.startsWith('Small ')), isTrue,
            reason: "Species '${entry.key}' missing Small variant");
        expect(names.any((n) => n.startsWith('Medium ')), isTrue,
            reason:
                "Species '${entry.key}' missing Medium variant");
        expect(names.any((n) => n.startsWith('Large ')), isTrue,
            reason: "Species '${entry.key}' missing Large variant");
      }
    });

    test('all row IDs are unique', () {
      final ids = <String>{};
      for (final r in rows) {
        final id = r['id'] as String?;
        if (id == null) continue;
        expect(ids.add(id), isTrue,
            reason: "Duplicate id '$id' found in catalog");
      }
    });

    test('"2 in Square" row exists with correct geometry', () {
      final square2 =
          rows.where((r) => r['name'] == '2 in Square').toList();
      expect(square2, hasLength(1));
      expect(square2.first['shape'], 'square');
      expect(square2.first['width_in'], 2.0);
      expect(square2.first['height_in'], 2.0);
    });

    test('every generic circle name matches ^N in Circle\$', () {
      final circles = rows.where((r) => r['shape'] == 'circle');
      final pat = RegExp(r'^\d+ in Circle$');
      for (final r in circles) {
        expect(pat.hasMatch(r['name'] as String), isTrue,
            reason: "Circle name '${r['name']}' fails pattern");
      }
    });

    test('every generic square name matches ^N in Square\$', () {
      final squares = rows.where((r) => r['shape'] == 'square');
      final pat = RegExp(r'^\d+ in Square$');
      for (final r in squares) {
        expect(pat.hasMatch(r['name'] as String), isTrue,
            reason: "Square name '${r['name']}' fails pattern");
      }
    });

    test('every GENERIC rectangle name matches Phase 8 pattern', () {
      // The 6 generic rectangles ship as `12" x 18" Rectangle` etc.
      // Named-rectangle rows (NRA SR-1, F-Class F-Open, Bullseye,
      // Dueling Tree) keep their proper names and aren't matched
      // by this pattern. Filter to the generic ones by name shape.
      final pat =
          RegExp(r'^\d+(?:\.\d+)?" x \d+(?:\.\d+)?" Rectangle$');
      final genericRects = rows
          .where((r) => r['shape'] == 'rectangle')
          .where((r) => pat.hasMatch(r['name'] as String))
          .toList();
      // The catalog has exactly 6 generic rectangles per Phase 8
      // (12×18, 18×24, 24×30, 24×36, 36×48, 36×60).
      expect(genericRects, hasLength(6));
    });

    test('every animal name contains " in" (dims appended)', () {
      final animals =
          rows.where((r) => r['category'] == 'animal').toList();
      // Phase 8 expanded all animal names from a single noun
      // (e.g. `"Deer"`) to `"Deer 60×32 in"` for picker readability.
      // Phase 9 Group B expanded to 48 animals (16 species × 3 sizes,
      // each prefixed `Small ` / `Medium ` / `Large `).
      expect(animals, hasLength(48));
      for (final r in animals) {
        expect((r['name'] as String).contains(' in'), isTrue,
            reason: "Animal name '${r['name']}' lacks dimensions");
      }
    });

    test('no IPSC name has duplicate dimensions (Phase 8 bugfix)', () {
      // Pre-Phase-8, dynamic `_targetDropdownLabel` appended the
      // (w × h) dimensions to every row's display label — but IPSC
      // rows already had dims in their catalog `name`, producing
      // labels like `"IPSC USPSA Classic 18×30 in 18×30 in"`.
      // Phase 8 fixed this by simplifying the label generator to
      // `=> t.name`; this assertion guards the catalog side: no
      // row's name should carry doubled dimensions.
      for (final r in rows) {
        final name = r['name'] as String;
        expect('×'.allMatches(name).length, lessThanOrEqualTo(1),
            reason: "Row name '$name' carries multiple '×' dim "
                'separators (likely the duplicate-dims bug).');
      }
    });
  });
}
