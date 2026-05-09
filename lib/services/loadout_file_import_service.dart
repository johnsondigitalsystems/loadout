// FILE: lib/services/loadout_file_import_service.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Re-imports recipes from a previously-exported LoadOut JSON file. Surfaces
// a single public entry point on `LoadoutFileImportService`:
//
//   - `pickAndImportRecipes(...)` — prompts the user to pick a `.json` /
//     `.loadout` file via `file_picker`, then walks the file and inserts
//     every recipe it finds via `RecipeRepository.insert`. Returns a
//     `LoadoutFileImportResult` with `imported` and `skipped` counts plus
//     the list of error messages collected along the way.
//
// The parser tolerates two on-disk shapes:
//
//   1. **Full LoadOut export wrapper** produced by `ExportService.exportToJson`
//      — `{ loadout_export_version, schema_version, tables: { user_loads: [...] } }`.
//      Only the `user_loads` table is consumed; the rest of the wrapper is
//      ignored. This is the common path: a user exports their backup, hands
//      the file to a friend, and the friend re-imports just the recipes
//      without touching their firearms / brass / lots.
//
//   2. **Bare list of recipes** — either a plain JSON array `[ {...}, {...} ]`
//      or an object with a `recipes` field. Both are accepted.
//
// Each row is treated as a candidate `UserLoadsCompanion`. Inbound `id`,
// `createdAt`, and `updatedAt` are dropped so the importer never collides
// with primary keys already in the local DB. Foreign-key columns that
// reference rows we won't be importing (lot ids) are nulled — the
// recipes still load with literal powder / primer / bullet / brass strings,
// and the user can attach lots later.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// `ExportService.importFromJson` is the canonical full-DB restore path —
// it walks every user-data table inside one transaction, preserves IDs,
// and respects the merge policy. Re-importing recipes from a friend's
// backup needs different semantics: drop IDs, ignore everything except
// `user_loads`, and don't touch the rest of the local data. Forking the
// behaviour into a tiny dedicated service keeps both code paths simple.
//
// The Recipes form's "Imports" section is the only consumer today.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **Foreign keys cannot survive.** The exported file references lot
//    ids (`powderLotId`, `primerLotId`, etc.) that mean nothing on a
//    different device. Forwarding them would fail with FK violations.
//    We strip every `*LotId` field before constructing the companion.
// 2. **Drift's `fromJson` is strict about types.** A column declared as
//    `double?` rejects `null` strings, integers, or "1.5" with a quote.
//    We use `UserLoadRow.fromJson` and let drift's parser handle it,
//    catching exceptions per-row so one malformed record doesn't kill
//    the whole import.
// 3. **The user expects "their recipes show up."** Soft-fail policy: if
//    the file is unreadable, return a structured result with an error
//    message — never throw. The caller surfaces a SnackBar.
// 4. **`file_picker` returns paths, not bytes, by default.** On iOS
//    that path lives in a sandboxed temp dir. We `withData: true` so
//    the bytes come back inline — faster than two reads and avoids
//    fighting the iOS document scope on edge cases.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/widgets/import_options_section.dart — the "Import from file" row
//   in the collapsible imports section, used by both the Quick Add and
//   the full Recipe form screens.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Opens the OS file picker (`file_picker` plugin).
// - Reads the picked file's bytes (no disk persistence).
// - Inserts new rows into `UserLoads` via `RecipeRepository.insert`.
// - No network, no SharedPreferences, no analytics.

import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';

import '../database/database.dart';
import '../repositories/recipe_repository.dart';

/// Result of a [LoadoutFileImportService.pickAndImportRecipes] call.
///
/// The `cancelled` flag distinguishes "user closed the picker" from
/// "we tried to import and got nothing." `errors` is a list of
/// human-readable strings — one per row that failed.
class LoadoutFileImportResult {
  const LoadoutFileImportResult({
    required this.imported,
    required this.skipped,
    required this.errors,
    required this.cancelled,
    this.fatalError,
  });

  /// Number of `UserLoads` rows successfully inserted into the DB.
  final int imported;

  /// Rows that were structurally valid JSON objects but didn't decode
  /// into a `UserLoadRow` (drift parse failure, missing `name`, etc.).
  final int skipped;

  /// One human-readable string per row error.
  final List<String> errors;

  /// True when the user cancelled the file picker. `imported`,
  /// `skipped`, and `errors` are zero/empty in this case.
  final bool cancelled;

  /// Set when the entire import was rejected (couldn't parse JSON,
  /// unknown shape). Per-row errors live in `errors` instead.
  final String? fatalError;

  /// True when at least one recipe made it into the DB.
  bool get hasAnyImport => imported > 0;

  /// Sentinel for "user cancelled the file picker." Used by the UI to
  /// suppress the success snackbar.
  static const LoadoutFileImportResult cancelledResult =
      LoadoutFileImportResult(
        imported: 0,
        skipped: 0,
        errors: <String>[],
        cancelled: true,
      );

  /// One-line summary string suitable for a SnackBar ("Imported 12 recipes.").
  String snackbarSummary() {
    if (cancelled) return '';
    if (fatalError != null) return fatalError!;
    if (imported == 0 && skipped == 0) {
      return 'No recipes found in this file.';
    }
    if (skipped == 0 && errors.isEmpty) {
      return imported == 1
          ? 'Imported 1 recipe.'
          : 'Imported $imported recipes.';
    }
    return 'Imported $imported '
        '${imported == 1 ? 'recipe' : 'recipes'}, '
        'skipped $skipped.';
  }
}

/// Re-imports recipes from a previously-exported LoadOut JSON file.
class LoadoutFileImportService {
  LoadoutFileImportService(this.repo);

  final RecipeRepository repo;

  /// FK columns that reference user data we don't import here. They are
  /// stripped before drift's `fromJson` runs so we never write a
  /// stale-pointing lot id.
  static const List<String> _fkColumnsToStrip = [
    'powder_lot_id',
    'primer_lot_id',
    'bullet_lot_id',
    'brass_lot_id',
    // camelCase aliases — drift's generated `fromJson` accepts both
    // depending on the version, so strip both to be safe.
    'powderLotId',
    'primerLotId',
    'bulletLotId',
    'brassLotId',
  ];

  /// Drop these so SQLite assigns fresh values and we don't collide
  /// with primary keys already on the local device.
  static const List<String> _identityColumnsToStrip = [
    'id',
    'created_at',
    'updated_at',
    'createdAt',
    'updatedAt',
  ];

  /// Open the OS file picker and import recipes from the chosen file.
  ///
  /// Soft-fails on every error path — the caller surfaces a SnackBar
  /// from the returned result and never has to wrap this in a
  /// try/catch.
  Future<LoadoutFileImportResult> pickAndImportRecipes() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['loadout', 'json'],
        // Pull bytes inline so we don't have to chase a sandboxed path
        // on iOS. The export files are ~tens of KB to a few MB at
        // worst; small enough to keep in memory.
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        return LoadoutFileImportResult.cancelledResult;
      }
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        return LoadoutFileImportResult(
          imported: 0,
          skipped: 0,
          errors: const <String>[],
          cancelled: false,
          fatalError: "Couldn't read the selected file.",
        );
      }
      final json = utf8.decode(bytes, allowMalformed: true);
      return importFromJson(json);
    } catch (e) {
      return LoadoutFileImportResult(
        imported: 0,
        skipped: 0,
        errors: const <String>[],
        cancelled: false,
        fatalError: 'Import failed: $e',
      );
    }
  }

  /// Visible for testing. Parses a JSON string and inserts every recipe
  /// row it can decode.
  Future<LoadoutFileImportResult> importFromJson(String json) async {
    final List<Map<String, dynamic>> rows;
    try {
      rows = _extractRecipeRows(json);
    } catch (e) {
      return LoadoutFileImportResult(
        imported: 0,
        skipped: 0,
        errors: const <String>[],
        cancelled: false,
        fatalError: 'Could not parse this file as a LoadOut export: $e',
      );
    }

    if (rows.isEmpty) {
      return const LoadoutFileImportResult(
        imported: 0,
        skipped: 0,
        errors: <String>[],
        cancelled: false,
      );
    }

    var imported = 0;
    var skipped = 0;
    final errors = <String>[];

    for (final raw in rows) {
      try {
        final companion = _rowToCompanion(raw);
        if (companion == null) {
          skipped++;
          continue;
        }
        await repo.insert(companion);
        imported++;
      } catch (e) {
        skipped++;
        errors.add('Row failed: $e');
      }
    }

    return LoadoutFileImportResult(
      imported: imported,
      skipped: skipped,
      errors: errors,
      cancelled: false,
    );
  }

  /// Extracts the recipe-row list from any of the three accepted shapes:
  /// full LoadOut export wrapper, bare array, or object with `recipes`
  /// field.
  List<Map<String, dynamic>> _extractRecipeRows(String json) {
    final decoded = jsonDecode(json);
    // Shape 1: bare list of recipes.
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList(growable: false);
    }
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'Top-level JSON must be an object or an array.',
      );
    }
    // Shape 2: full LoadOut export wrapper. Pull `tables.user_loads`.
    final tables = decoded['tables'];
    if (tables is Map<String, dynamic>) {
      final loads = tables['user_loads'];
      if (loads is List) {
        return loads
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .toList(growable: false);
      }
    }
    // Shape 3: object with a `recipes` field.
    final recipes = decoded['recipes'];
    if (recipes is List) {
      return recipes
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList(growable: false);
    }
    // Some builds also write `user_loads` at the top level instead of
    // nested under `tables`. Accept that for resilience.
    final flatLoads = decoded['user_loads'];
    if (flatLoads is List) {
      return flatLoads
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  /// Convert one inbound row into a `UserLoadsCompanion`. Returns null
  /// when the row has no usable name (we treat name as the soft-required
  /// field for a recipe — without it the user will never find the import
  /// in their list).
  UserLoadsCompanion? _rowToCompanion(Map<String, dynamic> raw) {
    // Defensive copy. We mutate to strip identity / FK columns.
    final cleaned = <String, dynamic>{...raw};
    for (final col in _identityColumnsToStrip) {
      cleaned.remove(col);
    }
    for (final col in _fkColumnsToStrip) {
      cleaned.remove(col);
    }

    // Pull the name eagerly so we can early-out before drift parses.
    final dynamic nameValue = cleaned['name'];
    final name = nameValue is String ? nameValue.trim() : '';
    if (name.isEmpty) return null;

    // Round-trip through drift's generated row class — that handles
    // nullable doubles, ISO-8601 dates, and column rename aliases for
    // us. Then convert the row to a companion with absent ids so SQLite
    // assigns fresh primary keys.
    final row = UserLoadRow.fromJson(cleaned);
    return row.toCompanion(false).copyWith(
          id: const drift.Value.absent(),
          createdAt: const drift.Value.absent(),
          updatedAt: const drift.Value.absent(),
          // Already stripped above, but force absent to be doubly sure
          // we don't write a stale FK.
          powderLotId: const drift.Value.absent(),
          primerLotId: const drift.Value.absent(),
          bulletLotId: const drift.Value.absent(),
          brassLotId: const drift.Value.absent(),
        );
  }
}
