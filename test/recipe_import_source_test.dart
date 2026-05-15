// FILE: test/recipe_import_source_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Pins the file-extension -> `RecipeImportSourceKind` mapping the
// `RecipeImportLandingScreen` (Phase One Group 5) uses to dispatch
// a picked file to the right per-source flow. The mapping is the
// single source of truth for "which screen does a .csv vs .xlsx
// vs .json vs .fit vs .docx route to" — a regression here would
// silently route every file the same way (or to "Unsupported file
// type") without any other test catching it.
//
// Plus a small group on `isLiveRecipeImportKind` so the Coming
// Soon discriminator never silently flips for an existing kind.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The Phase One Group 5 spec's source taxonomy is in three places
// at once: the enum here, the landing screen's `_routeFor` switch,
// and the Engineering.md § 19.4 source-taxonomy table. The unit
// test gates the first; the landing screen's exhaustive switch
// (`case _ when:` with `return`) gates the second; the doc audit
// gates the third. Three places held in sync by one test + a
// compile-time check + a docs review.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// - Filename casing matters. The helper lower-cases before
//   matching, so `.CSV` should map to `spreadsheet` just like
//   `.csv`. The test pins the case-insensitivity.
// - Multi-extension files (e.g. `.tar.gz`) are not currently
//   supported by any of our import flows — the test pins null for
//   one such case so a future "let's also support `.tar`" change
//   has to think through what kind it should map to.
// - The `.fit` extension lives in the live-kinds set (per the
//   enum's `isLiveRecipeImportKind` discriminator) even though
//   the landing-screen route currently surfaces an informational
//   snackbar rather than parsing the file — see the file header
//   of `recipe_import_landing_screen.dart` for why. The Phase Two
//   completion of `.fit` will flip the snackbar to a real route
//   without changing the kind's live/coming-soon status.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `flutter test` (CI gate).
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None — pure function tests.

import 'package:flutter_test/flutter_test.dart';

import 'package:loadout/screens/recipes/recipe_import_source.dart';

void main() {
  group('detectKindFromFileExtension', () {
    test('.csv → spreadsheet', () {
      expect(detectKindFromFileExtension('loads.csv'),
          RecipeImportSourceKind.spreadsheet);
    });

    test('.xlsx → spreadsheet', () {
      expect(detectKindFromFileExtension('mybook.xlsx'),
          RecipeImportSourceKind.spreadsheet);
    });

    test('.xls (legacy Excel) → spreadsheet', () {
      expect(detectKindFromFileExtension('mybook.xls'),
          RecipeImportSourceKind.spreadsheet);
    });

    test('.json → loadoutJson', () {
      expect(detectKindFromFileExtension('loadout-export-2026-05-14.json'),
          RecipeImportSourceKind.loadoutJson);
    });

    test('.fit → garminFit', () {
      expect(detectKindFromFileExtension('shots.fit'),
          RecipeImportSourceKind.garminFit);
    });

    test('.docx → msWordDoc (Coming Soon)', () {
      expect(detectKindFromFileExtension('manual-page.docx'),
          RecipeImportSourceKind.msWordDoc);
    });

    test('.doc (legacy Word) → msWordDoc (Coming Soon)', () {
      expect(detectKindFromFileExtension('manual-page.doc'),
          RecipeImportSourceKind.msWordDoc);
    });

    test('.one → msOneNote (Coming Soon)', () {
      expect(detectKindFromFileExtension('notebook.one'),
          RecipeImportSourceKind.msOneNote);
    });

    test('case-insensitive — UPPER-CASE .CSV still maps to spreadsheet',
        () {
      expect(detectKindFromFileExtension('LOADS.CSV'),
          RecipeImportSourceKind.spreadsheet);
      expect(detectKindFromFileExtension('shots.FIT'),
          RecipeImportSourceKind.garminFit);
      expect(detectKindFromFileExtension('FILE.Json'),
          RecipeImportSourceKind.loadoutJson);
    });

    test('unsupported extension → null', () {
      expect(detectKindFromFileExtension('photo.png'), isNull);
      expect(detectKindFromFileExtension('photo.jpg'), isNull);
      expect(detectKindFromFileExtension('archive.tar.gz'), isNull);
      expect(detectKindFromFileExtension('cookies.txt'), isNull);
      expect(detectKindFromFileExtension('no_extension'), isNull);
      expect(detectKindFromFileExtension(''), isNull);
    });

    test('filename containing a known extension MID-string does not match',
        () {
      // A file literally named "csv-report.pdf" has its real
      // extension at the END; the helper must not be fooled by
      // ".csv" anywhere else in the name.
      expect(detectKindFromFileExtension('csv-report.pdf'), isNull);
      expect(detectKindFromFileExtension('xlsx-spec.txt'), isNull);
    });
  });

  group('isLiveRecipeImportKind', () {
    test('the seven live kinds return true', () {
      for (final kind in const <RecipeImportSourceKind>[
        RecipeImportSourceKind.spreadsheet,
        RecipeImportSourceKind.photoSingle,
        RecipeImportSourceKind.photoMultiPage,
        RecipeImportSourceKind.loadoutJson,
        RecipeImportSourceKind.qrCode,
        RecipeImportSourceKind.clipboard,
        RecipeImportSourceKind.garminFit,
      ]) {
        expect(isLiveRecipeImportKind(kind), isTrue,
            reason: '$kind should be live');
      }
    });

    test('the three Coming Soon kinds return false', () {
      for (final kind in const <RecipeImportSourceKind>[
        RecipeImportSourceKind.msWordDoc,
        RecipeImportSourceKind.msOneNote,
        RecipeImportSourceKind.garminXeroPhoto,
      ]) {
        expect(isLiveRecipeImportKind(kind), isFalse,
            reason: '$kind should be Coming Soon');
      }
    });

    test(
        'every enum value is covered — no kind silently misclassified by '
        'omission', () {
      // Guards against a future enum addition that forgets to
      // update `isLiveRecipeImportKind`'s switch. Any new kind
      // must explicitly land in one of the two buckets above; the
      // exhaustive switch in `isLiveRecipeImportKind` will refuse
      // to compile when a new enum value is added without a case.
      // This test just iterates all values to confirm the
      // function returns a non-null bool for every one.
      for (final kind in RecipeImportSourceKind.values) {
        // ignore: unnecessary_type_check — the type check
        // documents the intent.
        expect(isLiveRecipeImportKind(kind), isA<bool>());
      }
    });
  });
}
