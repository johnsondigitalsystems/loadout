// FILE: lib/repositories/firearm_component_repository.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Read-only repository for the seven-category firearm-component catalog
// seeded into the `FirearmComponents` drift table on first launch
// (chassis, barrels, triggers, buttstocks, muzzle brakes, suppressors,
// bipods — added schema v33). The firearm form's "Custom Build" mode
// pulls suggestions from this repository to drive its seven Autocomplete
// pickers; nothing else in the app writes to the table.
//
// Public surface:
//
//   * `enum FirearmComponentKind` — the seven discriminator values. The
//     catalog ships every kind together; the form filters per-picker by
//     calling `byKind(...)`.
//   * `class FirearmComponentEntry` — display-friendly bundle of one
//     row, with the `attributesJson` blob already decoded into
//     `Map<String, dynamic>` for category-specific UI (action
//     footprints, material, pull range, mounting types, etc.).
//   * `Future<List<FirearmComponentEntry>> all()` — every row in the
//     catalog. Useful for seed-integrity tests and future panels that
//     show the entire corpus at once. Manufacturer + model alphabetical.
//   * `Future<List<FirearmComponentEntry>> byKind(FirearmComponentKind)`
//     — the per-picker query. Returned list is sorted manufacturer
//     first, then model, so the picker presents a predictable order.
//   * `Future<FirearmComponentEntry?> findByLabel(String label)` —
//     resolves a `"Manufacturer Model"` string back to a catalog row
//     when one exists. Returns null when the user typed a custom
//     value not in the catalog (which is allowed — catalog membership
//     is a hint, never a constraint).
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The custom-build path on the firearm form needs a query layer that's
// independent of the form widget — same separation-of-concerns pattern
// every other repository in the app uses. Putting the SQL inside the
// form would couple the picker to drift internals and make it
// impossible to share the catalog with future surfaces (a Resources →
// "Browse Components" tile, a chassis-comparison screen, AI Smart
// Import auto-detection of components from a build photo, etc.).
//
// Provided once in `lib/app.dart` via `Provider<FirearmComponentRepository>`
// so screens can `context.read<FirearmComponentRepository>()` without
// caring how the underlying table is laid out.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * THE CATALOG IS A HINT, NOT A CONSTRAINT. The user can type any
//     string into a custom-build picker and we save it verbatim — the
//     catalog only powers the autocomplete suggestion list. This means
//     `findByLabel` may legitimately return null on saved firearms,
//     and consumers must handle that without treating it as a bug.
//
//   * `attributesJson` IS A FORWARD-COMPATIBILITY BLOB. Different
//     `FirearmComponentKind` values define different attribute keys
//     (chassis: actionFootprints + weightOz; barrel: material +
//     contour + twistRateOptions; trigger: stage + pullRangeOz +
//     inletAction; etc.). The repository decodes the whole blob into
//     a generic `Map<String, dynamic>` and lets the UI extract the
//     keys it cares about, rather than forcing a typed model per kind.
//     Adding a new attribute later requires no schema change — just
//     the seed JSON gets richer.
//
//   * SORT IS MANUFACTURER-FIRST, THEN MODEL. PRS shooters know
//     products by manufacturer ("MDT this", "Bartlein that"); the
//     picker should mirror that mental model. We don't surface the
//     `productLine` field in the visible label — it's a v2 affordance
//     for collapsing a brand's product line into nested suggestions.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   - lib/screens/firearms/firearm_form_screen.dart — the seven
//     "Custom Build" pickers.
//   - lib/app.dart — providers wiring (read-only).
//   - test/firearm_component_repository_test.dart — seed-integrity +
//     query tests.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure-functional reads against a seeded reference table.

import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/database.dart';

/// Discriminator for the seven categories shipped in the v33 component
/// catalog. The `wireValue` is the lowercase string written to
/// `FirearmComponents.kind` by the seed loader; the form pickers and
/// any future query helpers should always go through this enum rather
/// than typing the raw string.
enum FirearmComponentKind {
  chassis('chassis', 'Chassis'),
  barrel('barrel', 'Barrel'),
  trigger('trigger', 'Trigger'),
  buttstock('buttstock', 'Buttstock'),
  muzzleBrake('muzzleBrake', 'Muzzle Brake'),
  suppressor('suppressor', 'Suppressor'),
  bipod('bipod', 'Bipod');

  const FirearmComponentKind(this.wireValue, this.displayLabel);

  /// String stored in `FirearmComponents.kind`. Stable — changing this
  /// would invalidate every seeded row.
  final String wireValue;

  /// Title-cased label suitable for picker section headings, badges,
  /// and the firearm-detail summary card. Title Case per CLAUDE.md
  /// § 0a.
  final String displayLabel;

  static FirearmComponentKind? fromWire(String wire) {
    for (final v in values) {
      if (v.wireValue == wire) return v;
    }
    return null;
  }
}

/// Display-friendly view of one `FirearmComponents` row — manufacturer,
/// model, optional product-line, free-form notes, and the decoded
/// per-kind attributes. The `label` getter is what the picker shows
/// in its field; the `attributes` map exposes per-kind metadata for
/// the suggestion subtitle and any future detail panels.
class FirearmComponentEntry {
  const FirearmComponentEntry({
    required this.id,
    required this.kind,
    required this.manufacturer,
    required this.model,
    required this.productLine,
    required this.notes,
    required this.attributes,
  });

  final int id;
  final FirearmComponentKind kind;
  final String manufacturer;
  final String model;
  final String? productLine;
  final String? notes;

  /// Decoded `attributesJson` blob — keys vary by `kind`. Empty map
  /// when the seed row had no extras.
  final Map<String, dynamic> attributes;

  /// `"<Manufacturer> <Model>"` — the canonical display string and
  /// the value persisted onto `UserFirearms.{chassisName, barrelName,
  /// ...}` columns when the user picks this entry from the
  /// autocomplete. The picker compares typed input against this label
  /// (case-insensitive token match) to drive its suggestion filter.
  String get label => '$manufacturer $model';
}

class FirearmComponentRepository {
  FirearmComponentRepository(this.db);

  final AppDatabase db;

  /// Every component in the catalog, manufacturer-then-model sorted.
  /// The list is short enough (≈220 rows total across all seven kinds
  /// at v33 launch) that an in-memory query is fine; the autocomplete
  /// pickers re-filter against it on every keystroke without
  /// hammering the DB.
  Future<List<FirearmComponentEntry>> all() async {
    final rows = await (db.select(db.firearmComponents)
          ..orderBy([
            (t) => OrderingTerm(expression: t.manufacturer),
            (t) => OrderingTerm(expression: t.model),
          ]))
        .get();
    return rows.map(_entryFromRow).toList();
  }

  /// All entries of a single kind. Used by each of the seven
  /// autocomplete pickers on the firearm form.
  Future<List<FirearmComponentEntry>> byKind(FirearmComponentKind kind) async {
    final rows = await (db.select(db.firearmComponents)
          ..where((t) => t.kind.equals(kind.wireValue))
          ..orderBy([
            (t) => OrderingTerm(expression: t.manufacturer),
            (t) => OrderingTerm(expression: t.model),
          ]))
        .get();
    return rows.map(_entryFromRow).toList();
  }

  /// Resolve a saved `"Manufacturer Model"` label back to its catalog
  /// entry when one exists. Returns null for free-text values typed
  /// by the user (which are valid — catalog membership is a hint, not
  /// a constraint).
  Future<FirearmComponentEntry?> findByLabel(String label) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return null;
    final everything = await all();
    for (final entry in everything) {
      if (entry.label == trimmed) return entry;
    }
    return null;
  }

  FirearmComponentEntry _entryFromRow(FirearmComponentRow row) {
    Map<String, dynamic> decoded;
    try {
      final raw = json.decode(row.attributesJson);
      decoded = (raw is Map<String, dynamic>)
          ? raw
          : (raw is Map ? raw.cast<String, dynamic>() : <String, dynamic>{});
    } catch (_) {
      // Malformed JSON in the seed file would be caught by the assets
      // test; the catch here is a defence-in-depth so a single bad row
      // can't crash the picker.
      decoded = const <String, dynamic>{};
    }
    return FirearmComponentEntry(
      id: row.id,
      kind: FirearmComponentKind.fromWire(row.kind) ??
          // Defensive default — a kind value we don't know about yet.
          // Bucket into chassis so the picker still has something to
          // render rather than throwing. The seed loader controls
          // which kinds get written, so this branch is unreachable
          // for shipping data.
          FirearmComponentKind.chassis,
      manufacturer: row.manufacturer,
      model: row.model,
      productLine: row.productLine,
      notes: row.notes,
      attributes: decoded,
    );
  }
}
