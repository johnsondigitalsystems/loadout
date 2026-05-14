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
import 'package:loadout/utils/natural_sort.dart';

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
        'each of 16 species has 3 distinct-dim variants', () {
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
        // Phase 9.6 — size words are GONE; variants are identified
        // by distinct dimensions. Assert the 3 variants have 3
        // distinct widths (proves they're not duplicate rows).
        final widths = entry.value
            .map((r) => (r['width_in'] as num).toDouble())
            .toSet();
        expect(widths, hasLength(3),
            reason: "Species '${entry.key}' should have 3 distinct "
                "widths; got ${widths.length}");
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
      // Phase 9.5 — `shape` field dropped; `category` is the
      // taxonomy now.
      expect(square2.first['category'], 'square');
      expect(square2.first['width_in'], 2.0);
      expect(square2.first['height_in'], 2.0);
    });

    test('every generic circle name matches ^N in Circle\$', () {
      final circles = rows.where((r) => r['category'] == 'circle');
      final pat = RegExp(r'^\d+ in Circle$');
      for (final r in circles) {
        expect(pat.hasMatch(r['name'] as String), isTrue,
            reason: "Circle name '${r['name']}' fails pattern");
      }
    });

    test('every generic square name matches ^N in Square\$', () {
      final squares = rows.where((r) => r['category'] == 'square');
      final pat = RegExp(r'^\d+ in Square$');
      for (final r in squares) {
        expect(pat.hasMatch(r['name'] as String), isTrue,
            reason: "Square name '${r['name']}' fails pattern");
      }
    });

    test('every GENERIC rectangle name matches Phase 8 pattern', () {
      final pat =
          RegExp(r'^\d+(?:\.\d+)?" x \d+(?:\.\d+)?" Rectangle$');
      final genericRects = rows
          .where((r) => r['category'] == 'rectangle')
          .where((r) => pat.hasMatch(r['name'] as String))
          .toList();
      expect(genericRects, hasLength(6));
    });

    test(
        'Phase 9.5 — category enum populated for every row '
        '(circle / square / rectangle / ipsc / animal / special)',
        () {
      const valid = <String>{
        'circle',
        'square',
        'rectangle',
        'ipsc',
        'animal',
        'special',
      };
      for (final r in rows) {
        final c = r['category'];
        expect(c, isA<String>(),
            reason: "Row '${r['name']}' missing category");
        expect(valid.contains(c), isTrue,
            reason: "Row '${r['name']}' has invalid category '$c'");
      }
    });

    test(
        'Phase 9.5 — `shape` field is GONE from every row '
        '(category-driven taxonomy)',
        () {
      for (final r in rows) {
        expect(r.containsKey('shape'), isFalse,
            reason: "Row '${r['name']}' still carries legacy 'shape' field");
      }
    });

    test('Phase 9.6 — animal names use "{Species} {W}×{H}" format', () {
      final animals =
          rows.where((r) => r['category'] == 'animal').toList();
      expect(animals, hasLength(48));
      // Phase 9.6 — names are "Bear 30×16" / "Mountain Lion 84×45"
      // etc. Title-case species (multi-word with single spaces);
      // dimensions joined by U+00D7 multiplication sign (×), not
      // letter x. Decimals preserved when present. No size words,
      // no comma, no "in" suffix.
      final pat = RegExp(r'^[A-Z][a-zA-Z ]+ \d+(?:\.\d+)?×\d+(?:\.\d+)?$');
      for (final r in animals) {
        final name = r['name'] as String;
        expect(pat.hasMatch(name), isTrue,
            reason: "Animal name '$name' doesn't match "
                "'{Species} {W}×{H}' format. Multiplication "
                'sign must be U+00D7, not the letter x.');
        // The dimensions in the name MUST come from width_in/height_in
        // verbatim — the seed loader trusts them as ballistic inputs.
        // A mismatch indicates a hand-edit drifted away from the row's
        // own width_in / height_in.
        final w = (r['width_in'] as num);
        final h = (r['height_in'] as num);
        String fmt(num v) =>
            v == v.roundToDouble() ? v.toInt().toString() : v.toString();
        expect(name, endsWith(' ${fmt(w)}×${fmt(h)}'),
            reason: "Animal name '$name' dimensions don't match "
                "width_in=${r['width_in']} height_in=${r['height_in']}.");
      }
    });

    test(
        'Phase 9.6 — naturalCompare on the new animal names produces '
        'small→large order within each species', () {
      // The Range Day target picker calls `repo.allTargets()` which
      // applies `naturalCompare(a.name, b.name)`. The Phase 9.6
      // animal names ("Bear 30×16" / "Bear 48×26" / "Bear 60×32")
      // are designed so the numeric chunk right after the species
      // prefix decides the order — no separate sort code path is
      // needed in the picker. This test pins that invariant: any
      // future naturalCompare regression that broke numeric-chunk
      // ordering would surface here, not in a UI bug report.
      final names = <String>[
        'Bear 60×32',
        'Bear 30×16',
        'Bear 48×26',
        'Moose 120×64',
        'Moose 48×26',
        'Moose 84×48',
      ];
      names.sort(naturalCompare);
      expect(names, <String>[
        'Bear 30×16',
        'Bear 48×26',
        'Bear 60×32',
        'Moose 48×26',
        'Moose 84×48',
        // 120 > 84 numerically — naive string sort would put
        // "Moose 120" before "Moose 48" because '1' < '4'.
        'Moose 120×64',
      ]);
    });

    test('Phase 9.6 — animal rows are pre-sorted (species ASC, width_in ASC)',
        () {
      // The seed file ships in canonical sort order. The repository's
      // naturalCompare(name) sort produces the same ordering at runtime
      // because the new "{Species} {W}×{H}" format puts numeric tokens
      // right after the matching species prefix, and naturalCompare
      // numerically-compares those tokens. Pinning the file order
      // catches a hand-edit that shuffles the catalog AND any future
      // sort regression that would have only shown up in the picker
      // UI.
      final animals =
          rows.where((r) => r['category'] == 'animal').toList();
      String species(Map<String, dynamic> r) {
        return (r['shape_id'] as String)
            .split('_')
            .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
            .join(' ');
      }
      for (var i = 1; i < animals.length; i++) {
        final prev = animals[i - 1];
        final curr = animals[i];
        final cmp = species(prev).compareTo(species(curr));
        if (cmp != 0) {
          expect(cmp < 0, isTrue,
              reason: "Animal '${curr['name']}' precedes "
                  "'${prev['name']}' alphabetically by species but "
                  'comes after in the seed file.');
        } else {
          final wPrev = (prev['width_in'] as num).toDouble();
          final wCurr = (curr['width_in'] as num).toDouble();
          expect(wPrev <= wCurr, isTrue,
              reason: "Same species '${species(prev)}' but variant "
                  "'${curr['name']}' (w=$wCurr) sorts before "
                  "'${prev['name']}' (w=$wPrev) — expected "
                  'small-to-large.');
        }
      }
    });

    test('Phase 9.5 — special-category rows: pepper_popper + texas_star', () {
      final specials =
          rows.where((r) => r['category'] == 'special').toList();
      expect(specials, hasLength(3),
          reason: '2 poppers + Texas Star = 3 special-category rows');
      final shapeIds = specials.map((r) => r['shape_id']).toSet();
      expect(shapeIds, containsAll(['pepper_popper', 'texas_star']));
    });

    test('Phase 9.5 — category counts match expected', () {
      final counts = <String, int>{};
      for (final r in rows) {
        final c = r['category'] as String;
        counts[c] = (counts[c] ?? 0) + 1;
      }
      expect(counts['circle'], 13);
      expect(counts['square'], 6);
      expect(counts['rectangle'], 15);
      expect(counts['ipsc'], 6);
      expect(counts['animal'], 48);
      expect(counts['special'], 3);
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
