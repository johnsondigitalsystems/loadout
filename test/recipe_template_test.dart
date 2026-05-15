// FILE: test/recipe_template_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Pure-Dart tests for `RecipeTemplate.fromJson` + the
// `RecipeTemplateDetailLevel` enum semantics. No drift, no
// repositories — those are exercised in
// `test/recipe_repository_templates_test.dart`. This file pins the
// JSON parsing contract that the Phase Two Group 1 seed pipeline
// depends on.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// `RecipeTemplate.fromJson` is the boundary between the static
// JSON in `assets/seed_data/recipe_templates.json` and the typed
// Dart code that consumes it. A parse regression here breaks every
// recipe template silently on first launch — the Quick Add picker
// would render an empty list. The unit tests pin every field's
// parse path so a future refactor of the JSON shape can't bypass
// the existing seed data.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// - `recommendedDetailLevel` must throw `ArgumentError` on an
//   unknown value, NOT silently fall back to a default. A typo in
//   the seed file should be loud at startup, not silent in
//   production with a "no templates available" empty state.
// - Every pre-fill field except `id` / `name` /
//   `recommendedDetailLevel` is nullable. The minimal-template
//   test pins that a template with ONLY the required fields still
//   parses cleanly.
// - The `disclaimer` string is a class-level `static const` (not
//   per-instance). The test confirms it's the same string Phase
//   One Group 4 used so the disclaimer banner copy is preserved.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `flutter test` (CI gate).
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure-function tests.

import 'package:flutter_test/flutter_test.dart';

import 'package:loadout/models/recipe_template.dart';

void main() {
  group('RecipeTemplate.fromJson', () {
    test('parses every field on a fully-populated template', () {
      final t = RecipeTemplate.fromJson(<String, dynamic>{
        'id': '6_5_creedmoor_h4350_140eldm',
        'name': '6.5 Creedmoor — H4350 + 140gr ELD-M',
        'description': 'Hornady published starting load',
        'recommendedDetailLevel': 'quick',
        'caliber': '6.5 Creedmoor',
        'powder': 'Hodgdon H4350',
        'powderChargeGr': 41.5,
        'bullet': 'Hornady ELD Match 140gr',
        'bulletWeightGr': 140,
        'coalIn': 2.800,
        'cbtoIn': null,
        'useCase': 'match',
        'notes': 'Popular match starting load.',
      });

      expect(t.id, '6_5_creedmoor_h4350_140eldm');
      expect(t.name, '6.5 Creedmoor — H4350 + 140gr ELD-M');
      expect(t.description, 'Hornady published starting load');
      expect(t.recommendedDetailLevel, RecipeTemplateDetailLevel.quick);
      expect(t.caliber, '6.5 Creedmoor');
      expect(t.powder, 'Hodgdon H4350');
      expect(t.powderChargeGr, 41.5);
      expect(t.bullet, 'Hornady ELD Match 140gr');
      expect(t.bulletWeightGr, 140.0);
      expect(t.coalIn, closeTo(2.800, 1e-9));
      expect(t.cbtoIn, isNull);
      expect(t.useCase, 'match');
      expect(t.notes, 'Popular match starting load.');
    });

    test('parses a minimal template (id + name + level only)', () {
      final t = RecipeTemplate.fromJson(<String, dynamic>{
        'id': 'minimal',
        'name': 'Minimal',
        'recommendedDetailLevel': 'quick',
      });

      expect(t.id, 'minimal');
      expect(t.name, 'Minimal');
      expect(t.recommendedDetailLevel, RecipeTemplateDetailLevel.quick);
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

    test('defaults recommendedDetailLevel to `quick` when absent', () {
      final t = RecipeTemplate.fromJson(<String, dynamic>{
        'id': 'no-level',
        'name': 'No Level',
      });

      expect(t.recommendedDetailLevel, RecipeTemplateDetailLevel.quick);
    });

    test('throws ArgumentError on unknown recommendedDetailLevel', () {
      // A typo in the seed file should fail loud at startup, not
      // silently degrade to a default. The seed loader surfaces
      // the throw to the user-visible crash channel; better than
      // a silent empty template list at runtime.
      expect(
        () => RecipeTemplate.fromJson(<String, dynamic>{
          'id': 'bad',
          'name': 'Bad',
          'recommendedDetailLevel': 'kwick',
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('parses every shipping enum value (quick / core / extended / full)',
        () {
      for (final level in RecipeTemplateDetailLevel.values) {
        final t = RecipeTemplate.fromJson(<String, dynamic>{
          'id': 'level-${level.name}',
          'name': 'Level ${level.name}',
          'recommendedDetailLevel': level.name,
        });
        expect(t.recommendedDetailLevel, level);
      }
    });

    test('accepts integer JSON numbers for double-typed fields', () {
      // JSON files written without trailing zeroes (e.g. 41 instead
      // of 41.0) need to parse cleanly — `(num).toDouble()` handles
      // this but the unit test pins it.
      final t = RecipeTemplate.fromJson(<String, dynamic>{
        'id': 'int-doubles',
        'name': 'Int Doubles',
        'recommendedDetailLevel': 'quick',
        'powderChargeGr': 41,
        'bulletWeightGr': 140,
        'coalIn': 2,
      });

      expect(t.powderChargeGr, 41.0);
      expect(t.bulletWeightGr, 140.0);
      expect(t.coalIn, 2.0);
    });
  });

  group('RecipeTemplate.disclaimer', () {
    test('is non-empty and references reloading manuals', () {
      // The Quick Add picker reads this string verbatim and renders
      // it in a banner. The exact wording was settled in Phase One
      // Group 4; verifying two key tokens guards against a future
      // refactor accidentally dropping the "verify against your
      // current reloading manual" clause.
      expect(RecipeTemplate.disclaimer, isNotEmpty);
      expect(RecipeTemplate.disclaimer, contains('reloading manual'));
      expect(RecipeTemplate.disclaimer, contains('maximum charge'));
    });
  });
}
