// FILE: lib/services/common_loads_catalog.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Curated catalog of common factory rifle and handgun loads, exposed
// through a stable Dart API that the Range Day "Pick a common factory
// load" empty-state picker consumes. Defines:
//
//   * `class CommonLoad` — typed record of one factory-load row.
//     Carries cartridge name, manufacturer + bullet name, weight,
//     diameter, ballistic coefficient, drag model the BC is referenced
//     to, typical muzzle velocity, manufacturer-published Standard
//     Deviation (when known), and an optional notes string.
//   * `class CommonLoadsCatalog` — namespace + helpers (`all`,
//     `byCartridge`, `cartridges`, `search`). All four are async and
//     take a [ManufacturedAmmoRepository] so the data comes from the
//     SQLite [ManufacturedAmmo] table (schema v23) rather than a
//     compile-time constant list.
//   * `CommonLoadsCatalog.fromRow(row)` — adapter from a
//     [ManufacturedAmmoRow] to the public [CommonLoad] shape. Picks
//     G7 over G1 when both are present (centerfire convention) and
//     falls back to G1 (rimfire / pistol) when G7 isn't published.
//
// The catalog data was lifted out of the previous hand-coded list
// in this file and into `assets/seed_data/manufactured_ammo.json`
// during the v23 migration so the catalog can be live-updated via
// SeedUpdater without an App Store push.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The Range Day screen's load picker shows "— None —" when the user
// has zero saved recipes, which is unusable for first-launch shooters
// who haven't built up their library yet. Embedding a curated catalog
// of common loads gives the empty-state UX a real starting point — the
// user picks "308 Win → Federal Gold Medal 175 SMK", the picker drops
// a sensible BC + MV into the controllers, and the ballistics solver
// immediately produces a usable solution. The user can then tweak any
// field freely; the selection doesn't create a database row.
//
// The catalog API stays in this file (rather than the Range Day
// screen reading the repository directly) because the picker UI needs
// the search / group helpers below, and putting them in the same
// file as `CommonLoad` keeps the public surface tight and testable
// in isolation.
//
// IMPORTANT: this catalog feeds the Range Day "Pick a Common Load"
// picker ONLY. The Recipes tab does NOT consume this file — recipes
// use the [Bullets] table (powder-required handloading) through
// [ComponentRepository]. The two surfaces are kept separate by
// design (see `database.dart` table-level comment on
// [ManufacturedAmmo]).
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * Drag-model heterogeneity. Most centerfire rifle BCs are published
//     against the G7 reference (boat-tail, VLD-style); rimfire (22 LR)
//     and pistol BCs are typically published only as G1. The adapter
//     `fromRow` picks G7 when present (centerfire convention) and
//     falls back to G1 when G7 is null (rimfire / pistol) so the
//     picker can set the screen's `_dragModel` correctly.
//   * Bullet diameter convention. We store the actual jacket diameter
//     (e.g. 0.264 in for 6.5 mm bullets, 0.224 in for 22 caliber).
//     Don't confuse with cartridge-name diameters — a "30 caliber"
//     bullet is 0.308 in.
//   * BC drift. Published BCs are imperfect approximations and vary by
//     velocity. We store ONE value; the user is expected to override
//     with a trued BC if they have one. The picker copy
//     ("Using <load> defaults — your inputs override") makes this
//     explicit.
//   * Async API. The previous incarnation exposed a `static const`
//     list, so every helper was synchronous. The repo-backed shape
//     makes every helper return a `Future`. Callers that previously
//     read `CommonLoadsCatalog.all` synchronously now have to await
//     `CommonLoadsCatalog.all(repo)`. The picker's bottom sheet does
//     this with a `FutureBuilder`; tests await directly.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   * `lib/screens/range_day/range_day_detail_screen.dart` — the load
//     picker's empty-state bottom sheet renders this catalog and
//     applies the selected entry to the local controllers.
//   * `test/common_loads_catalog_test.dart` — verifies the adapter
//     produces sensible records and the search / group helpers
//     behave.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// Reads from the [ManufacturedAmmo] SQLite table via the supplied
// [ManufacturedAmmoRepository]. No writes, no network, no preferences.

import '../database/database.dart';
import '../repositories/manufactured_ammo_repository.dart';
import 'ballistics/drag_functions.dart';

/// Immutable record of a common factory load. See file header for the
/// drag-model convention (G7 for centerfire rifle, G1 for rimfire /
/// pistol).
class CommonLoad {
  /// Cartridge family ("6.5 Creedmoor", "308 Win", "22 LR", ...). Used
  /// to group entries in the picker bottom sheet.
  final String cartridge;

  /// Display name including manufacturer + bullet. Shown in the picker
  /// list and surfaced in the "Using `<name>` defaults" snackbar.
  final String name;

  final double bulletWeightGr;
  final double bulletDiameterIn;

  /// Ballistic coefficient referenced to [dragModel]. Centerfire rifle
  /// loads use G7 by convention; rimfire and pistol loads only have a
  /// G1 published, so they fall back to G1.
  final double bc;
  final DragModel dragModel;

  /// Typical muzzle velocity for the load out of a representative
  /// barrel. Per-barrel variation is significant — the user is expected
  /// to override with their own chronograph reading.
  final double muzzleVelocityFps;

  /// Manufacturer-published Standard Deviation of muzzle velocity (fps).
  /// Null when the manufacturer doesn't publish it. Drives the WEZ
  /// analysis screen's MV-uncertainty input when present.
  final double? standardDeviationFps;

  /// Optional human-readable note shown beneath the name in the picker
  /// (e.g. "Subsonic — for short / suppressed barrels").
  final String? notes;

  const CommonLoad({
    required this.cartridge,
    required this.name,
    required this.bulletWeightGr,
    required this.bulletDiameterIn,
    required this.bc,
    required this.dragModel,
    required this.muzzleVelocityFps,
    this.standardDeviationFps,
    this.notes,
  });

  /// Adapter from the SQLite [ManufacturedAmmoRow] to the public
  /// [CommonLoad] shape. G7 is preferred when present (centerfire
  /// convention); falls back to G1 when G7 is null (rimfire /
  /// pistol). Returns null when neither BC is populated — the caller
  /// drops rows that lack any drag model rather than rendering them
  /// with an arbitrary BC.
  static CommonLoad? fromRow(ManufacturedAmmoRow row) {
    final bcG7 = row.bcG7;
    final bcG1 = row.bcG1;
    DragModel model;
    double bc;
    if (bcG7 != null) {
      model = DragModel.g7;
      bc = bcG7;
    } else if (bcG1 != null) {
      model = DragModel.g1;
      bc = bcG1;
    } else {
      // No BC at all — caller filters these out.
      return null;
    }
    return CommonLoad(
      cartridge: row.cartridge,
      name: row.name,
      bulletWeightGr: row.bulletWeightGr,
      bulletDiameterIn: row.bulletDiameterIn,
      bc: bc,
      dragModel: model,
      muzzleVelocityFps: row.muzzleVelocityFps,
      standardDeviationFps: row.standardDeviationFps,
      notes: row.notes,
    );
  }
}

/// Namespace + helpers around the [ManufacturedAmmo] table. All
/// methods take a [ManufacturedAmmoRepository] (provided by `app.dart`)
/// and return a `Future` so the underlying SQLite read is honest.
class CommonLoadsCatalog {
  CommonLoadsCatalog._();

  /// Every row in the catalog as [CommonLoad] records, in source
  /// order (the JSON-file order). Soft-fails to an empty list when
  /// the repo read fails; the picker tolerates an empty catalog by
  /// rendering an empty-state hint.
  static Future<List<CommonLoad>> all(
    ManufacturedAmmoRepository repo,
  ) async {
    final rows = await repo.allRows();
    final out = <CommonLoad>[];
    for (final r in rows) {
      final l = CommonLoad.fromRow(r);
      if (l != null) out.add(l);
    }
    return out;
  }

  /// Group [all] by [CommonLoad.cartridge] preserving source order.
  /// Returns `Map<String, List<CommonLoad>>` so the picker can render
  /// one section header per cartridge.
  static Future<Map<String, List<CommonLoad>>> byCartridge(
    ManufacturedAmmoRepository repo,
  ) async {
    final loads = await all(repo);
    final grouped = <String, List<CommonLoad>>{};
    for (final l in loads) {
      grouped.putIfAbsent(l.cartridge, () => <CommonLoad>[]).add(l);
    }
    return grouped;
  }

  /// Distinct cartridge names in catalog order. Used by tests; the
  /// picker uses [byCartridge] directly for the section layout.
  static Future<List<String>> cartridges(
    ManufacturedAmmoRepository repo,
  ) async {
    final loads = await all(repo);
    final seen = <String>{};
    final result = <String>[];
    for (final l in loads) {
      if (seen.add(l.cartridge)) result.add(l.cartridge);
    }
    return result;
  }

  /// Case-insensitive substring search across cartridge name + load
  /// name + notes. Empty / whitespace-only [query] returns the full
  /// catalog. Matches anywhere in the string so a user typing "ELD"
  /// finds every Hornady ELD-Match entry; typing "creedmoor" filters
  /// to both 6mm + 6.5 Creedmoor.
  static Future<List<CommonLoad>> search(
    ManufacturedAmmoRepository repo,
    String query,
  ) async {
    final loads = await all(repo);
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return loads;
    return loads.where((l) {
      if (l.cartridge.toLowerCase().contains(q)) return true;
      if (l.name.toLowerCase().contains(q)) return true;
      final n = l.notes;
      if (n != null && n.toLowerCase().contains(q)) return true;
      return false;
    }).toList(growable: false);
  }
}
