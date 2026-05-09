// FILE: lib/services/common_loads_catalog.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// A small, hand-curated catalog of common factory rifle and handgun loads
// the average LoadOut user is likely to want as a starting point for the
// Range Day ballistics defaults BEFORE they have any saved recipes of
// their own. Defines:
//
//   * `class CommonLoad` — typed record of a factory load. Carries
//     cartridge name, manufacturer + bullet name, weight, diameter,
//     ballistic coefficient (G7 for centerfire rifle, G1 for rimfire and
//     pistol), drag model the BC is referenced to, typical muzzle
//     velocity from a representative barrel, and an optional notes
//     string. `apply()` is a UI-friendly hook callers can use, but the
//     fields are immutable and safe to read directly.
//   * `class CommonLoadsCatalog` — namespace + helpers (`all`,
//     `byCartridge`, `cartridges`, `search`). The catalog itself is a
//     compile-time constant list so it has zero startup cost and works
//     anywhere in the app — including unit tests where there's no
//     SharedPreferences / database wired up.
//
// The data was lifted from manufacturer websites (Hornady, Berger,
// Federal, Sierra) on 2026-05-08. BCs are the published values for the
// reference bullets; muzzle velocities are typical values from a 24"
// rifle barrel (or shorter where noted, e.g. 22 LR / 9mm). These are
// REASONABLE STARTING DEFAULTS the user can override on the Range Day
// screen before solving — they are not advertised as "true" values, and
// the picker copy makes that explicit.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The Range Day screen's load picker used to show only "— None —" when
// the user had zero saved recipes, which is unusable for first-launch
// shooters who haven't built up their library yet. Embedding a curated
// catalog of common loads lets the empty-state UX offer a real starting
// point — the user picks "308 Win → Federal Gold Medal 175 SMK", the
// picker drops a sensible BC + MV into the controllers, and the
// ballistics solver immediately produces a usable solution. The user
// can then tweak any field freely; the selection doesn't create a
// database row.
//
// Putting this in a service file (rather than inlining the list in the
// Range Day screen) keeps the data testable in isolation and lets the
// same catalog feed any future "quick-fill" affordance — for example,
// a future Recipes "Pick a common factory load" stub.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * Drag-model heterogeneity. Most centerfire rifle BCs are published
//     against the G7 reference (boat-tail, VLD-style); rimfire (22 LR)
//     and pistol BCs are typically published only as G1. Rather than
//     converting between the two (which is lossy), each load carries
//     its OWN drag model so the picker can set the screen's `_dragModel`
//     correctly when the user picks a 22 LR.
//   * Bullet diameter convention. We store the actual jacket diameter
//     (e.g. 0.264 in for 6.5 mm bullets, 0.224 in for 22 caliber).
//     Don't confuse with cartridge-name diameters — a "30 caliber"
//     bullet is 0.308 in.
//   * BC drift. Published BCs are imperfect approximations and vary by
//     velocity. We store ONE value; the user is expected to override
//     with a trued BC if they have one. The picker copy
//     ("Using <load> defaults — your inputs override") makes this
//     explicit.
//   * No "this is the right answer" claim. A curated list will always
//     leave somebody's pet load out. The catalog deliberately covers
//     the most-shot competition / hunting cartridges in 2026 and
//     leaves the long tail to the user's own recipes. Adding new
//     entries is a one-line change.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   * `lib/screens/range_day/range_day_detail_screen.dart` — the load
//     picker's empty-state bottom sheet renders this catalog and
//     applies the selected entry to the local controllers.
//   * `test/common_loads_catalog_test.dart` — verifies the catalog is
//     non-empty, every entry has sensible-looking values, and the
//     search / group helpers behave.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure data + pure helpers. No I/O, no database, no preferences.

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
    this.notes,
  });
}

/// Namespace + helpers around the [CommonLoad] table. The data itself
/// is the [all] list; everything else is a derived helper.
class CommonLoadsCatalog {
  CommonLoadsCatalog._();

  /// The full curated catalog. Order is rough cartridge-popularity-first
  /// for centerfire rifle, then rimfire, then pistol. Entries within a
  /// cartridge are ordered by bullet weight (lightest first) to match
  /// what shooters scanning a manufacturer page would expect.
  ///
  /// Adding a new entry: append to this list (the bottom sheet groups
  /// by cartridge automatically) and bump the test in
  /// `test/common_loads_catalog_test.dart` if it changes the cartridge
  /// count. BCs are the manufacturer's published value; muzzle
  /// velocities are typical 24" barrel numbers (or shorter where
  /// flagged). G7 for centerfire rifle, G1 elsewhere.
  static const List<CommonLoad> all = <CommonLoad>[
    // ─── 6.5 Creedmoor ───
    CommonLoad(
      cartridge: '6.5 Creedmoor',
      name: 'Hornady 140gr ELD-Match',
      bulletWeightGr: 140,
      bulletDiameterIn: 0.264,
      bc: 0.315,
      dragModel: DragModel.g7,
      muzzleVelocityFps: 2710,
    ),
    CommonLoad(
      cartridge: '6.5 Creedmoor',
      name: 'Berger 140gr Hybrid Target',
      bulletWeightGr: 140,
      bulletDiameterIn: 0.264,
      bc: 0.319,
      dragModel: DragModel.g7,
      muzzleVelocityFps: 2750,
    ),

    // ─── 6.5 PRC ───
    CommonLoad(
      cartridge: '6.5 PRC',
      name: 'Hornady 147gr ELD-Match',
      bulletWeightGr: 147,
      bulletDiameterIn: 0.264,
      bc: 0.351,
      dragModel: DragModel.g7,
      muzzleVelocityFps: 2910,
    ),
    CommonLoad(
      cartridge: '6.5 PRC',
      name: 'Berger 156gr EOL Elite Hunter',
      bulletWeightGr: 156,
      bulletDiameterIn: 0.264,
      bc: 0.362,
      dragModel: DragModel.g7,
      muzzleVelocityFps: 2780,
    ),

    // ─── 308 Win ───
    CommonLoad(
      cartridge: '308 Win',
      name: 'Federal Gold Medal 168gr SMK',
      bulletWeightGr: 168,
      bulletDiameterIn: 0.308,
      bc: 0.218,
      dragModel: DragModel.g7,
      muzzleVelocityFps: 2650,
    ),
    CommonLoad(
      cartridge: '308 Win',
      name: 'Federal Gold Medal 175gr SMK',
      bulletWeightGr: 175,
      bulletDiameterIn: 0.308,
      bc: 0.243,
      dragModel: DragModel.g7,
      muzzleVelocityFps: 2600,
    ),
    CommonLoad(
      cartridge: '308 Win',
      name: 'Hornady 178gr ELD-Match',
      bulletWeightGr: 178,
      bulletDiameterIn: 0.308,
      bc: 0.275,
      dragModel: DragModel.g7,
      muzzleVelocityFps: 2600,
    ),
    CommonLoad(
      cartridge: '308 Win',
      name: 'Subsonic 220gr SMK',
      bulletWeightGr: 220,
      bulletDiameterIn: 0.308,
      bc: 0.310,
      dragModel: DragModel.g7,
      muzzleVelocityFps: 1050,
      notes: 'Subsonic — for short / suppressed barrels',
    ),

    // ─── 6mm Creedmoor ───
    CommonLoad(
      cartridge: '6mm Creedmoor',
      name: 'Hornady 108gr ELD-Match',
      bulletWeightGr: 108,
      bulletDiameterIn: 0.243,
      bc: 0.273,
      dragModel: DragModel.g7,
      muzzleVelocityFps: 2960,
    ),

    // ─── 6mm Dasher ───
    CommonLoad(
      cartridge: '6mm Dasher',
      name: 'Berger 105gr Hybrid Target',
      bulletWeightGr: 105,
      bulletDiameterIn: 0.243,
      bc: 0.275,
      dragModel: DragModel.g7,
      muzzleVelocityFps: 2950,
    ),

    // ─── 6.5 Grendel ───
    CommonLoad(
      cartridge: '6.5 Grendel',
      name: 'Hornady 123gr ELD-Match',
      bulletWeightGr: 123,
      bulletDiameterIn: 0.264,
      bc: 0.255,
      dragModel: DragModel.g7,
      muzzleVelocityFps: 2580,
    ),

    // ─── 7mm Rem Mag ───
    CommonLoad(
      cartridge: '7mm Rem Mag',
      name: 'Hornady 180gr ELD-Match',
      bulletWeightGr: 180,
      bulletDiameterIn: 0.284,
      bc: 0.358,
      dragModel: DragModel.g7,
      muzzleVelocityFps: 2900,
    ),

    // ─── 300 Win Mag ───
    CommonLoad(
      cartridge: '300 Win Mag',
      name: 'Federal 190gr SMK',
      bulletWeightGr: 190,
      bulletDiameterIn: 0.308,
      bc: 0.286,
      dragModel: DragModel.g7,
      muzzleVelocityFps: 2950,
    ),
    CommonLoad(
      cartridge: '300 Win Mag',
      name: 'Berger 215gr Hybrid Target',
      bulletWeightGr: 215,
      bulletDiameterIn: 0.308,
      bc: 0.340,
      dragModel: DragModel.g7,
      muzzleVelocityFps: 2820,
    ),

    // ─── 224 Valkyrie ───
    CommonLoad(
      cartridge: '224 Valkyrie',
      name: 'Federal 90gr SMK',
      bulletWeightGr: 90,
      bulletDiameterIn: 0.224,
      bc: 0.274,
      dragModel: DragModel.g7,
      muzzleVelocityFps: 2700,
    ),

    // ─── 223 Rem ───
    CommonLoad(
      cartridge: '223 Rem',
      name: 'Hornady 75gr ELD-Match',
      bulletWeightGr: 75,
      bulletDiameterIn: 0.224,
      bc: 0.193,
      dragModel: DragModel.g7,
      muzzleVelocityFps: 2790,
    ),
    CommonLoad(
      cartridge: '223 Rem',
      name: 'Federal Gold Medal 77gr SMK',
      bulletWeightGr: 77,
      bulletDiameterIn: 0.224,
      bc: 0.198,
      dragModel: DragModel.g7,
      muzzleVelocityFps: 2750,
    ),

    // ─── Rimfire ───
    CommonLoad(
      cartridge: '22 LR',
      name: 'CCI Standard Velocity 40gr',
      bulletWeightGr: 40,
      bulletDiameterIn: 0.224,
      bc: 0.115,
      dragModel: DragModel.g1,
      muzzleVelocityFps: 1070,
      notes: 'BC is G1 — typical for rimfire',
    ),

    // ─── Pistol ───
    CommonLoad(
      cartridge: '9mm Luger',
      name: 'Federal HST 124gr',
      bulletWeightGr: 124,
      bulletDiameterIn: 0.355,
      bc: 0.150,
      dragModel: DragModel.g1,
      muzzleVelocityFps: 1150,
      notes: 'BC is G1 — typical for pistol',
    ),
  ];

  /// Group [all] by [CommonLoad.cartridge] preserving the catalog's
  /// order. Returns a `Map<String, List<CommonLoad>>` so the picker can
  /// render one section header per cartridge.
  static Map<String, List<CommonLoad>> byCartridge() {
    final grouped = <String, List<CommonLoad>>{};
    for (final l in all) {
      grouped.putIfAbsent(l.cartridge, () => <CommonLoad>[]).add(l);
    }
    return grouped;
  }

  /// Distinct cartridge names in catalog order. Used by tests; the
  /// picker uses [byCartridge] directly for the section layout.
  static List<String> cartridges() {
    final seen = <String>{};
    final result = <String>[];
    for (final l in all) {
      if (seen.add(l.cartridge)) result.add(l.cartridge);
    }
    return result;
  }

  /// Case-insensitive substring search across cartridge name + load
  /// name + notes. Empty / whitespace-only [query] returns the full
  /// catalog. Matches anywhere in the string so a user typing "ELD"
  /// finds every Hornady ELD-Match entry; typing "creedmoor" filters
  /// to both 6mm + 6.5 Creedmoor.
  static List<CommonLoad> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((l) {
      if (l.cartridge.toLowerCase().contains(q)) return true;
      if (l.name.toLowerCase().contains(q)) return true;
      final n = l.notes;
      if (n != null && n.toLowerCase().contains(q)) return true;
      return false;
    }).toList(growable: false);
  }
}
