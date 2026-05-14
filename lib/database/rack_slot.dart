// FILE: lib/database/rack_slot.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Defines the [RackSlot] value class — one element in a target rack's slot
// list. A "slot" is a single shootable target inside a multi-target rack
// (a popper in a popper rack, a plate on a KYL rail, a member plate on a
// Texas Star). Plus the [RackSlotsConverter] drift TypeConverter that
// (de)serialises a `List<RackSlot>` as JSON in the
// `TargetRacks.slotsJson` text column.
//
// Public surface:
//   * `RackSlot` — immutable value type. Carries position, the category
//     enum (`circle | square | rectangle | ipsc | animal | special`),
//     optional `shapeId` for SVG dispatch on `special` apparatus
//     (pepper_popper / texas_star), inch-denominated dimensions and
//     offsets, sizeRank (KYL stepping order), and hex color.
//   * `RackSlot.fromJson(map)` / `toJson()` — round-trip for the seed
//     loader and the TypeConverter alike.
//   * `RackSlotsConverter` — `TypeConverter<List<RackSlot>, String>`.
//     `fromSql` parses, validates, and sorts by `position` so the
//     repository never has to re-sort. `toSql` JSON-encodes the list
//     verbatim (preserves the in-memory order).
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Phase 9.5 Group C replaced the two-table parent+child rack model
// (`TargetRacks` + `TargetRackChildren` with an FK) with a single-table
// model where each rack carries its slots inline as a JSON array. The
// new arrangement matches how the rack actually behaves in the app
// (the slot list is always read as a whole, never individually) and
// drops a join + a whole drift table from the schema.
//
// Putting [RackSlot] in its own file (rather than inside
// `database.dart`) lets the painter, repository, seed loader, and
// schema converter all import it without circular drift dependencies.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * The JSON key names use snake_case (`shape_id`, `width_in`,
//     `x_offset_in`, `size_rank`, `color_hex`) to match the seed file
//     convention. The Dart field names are camelCase. `fromJson` and
//     `toJson` bridge the two — DO NOT rename the JSON keys without
//     also rewriting every seed payload, every Cloud Sync export, and
//     every Cloud Sync import path.
//   * `category` is required (no default) because Phase 9.5 Group A
//     made every target row carry a category enum value. A slot
//     missing `category` is a malformed seed payload, not a missing
//     optional field — `fromJson` will throw a `TypeError` on `as
//     String` mid-list rather than silently accepting `null`.
//   * `RackSlotsConverter.fromSql` sorts by `position` defensively.
//     The seed file is authored in position order (and the converter
//     writes back in that order), so the sort is a belt-and-braces
//     fallback against a hand-edited DB or a Cloud Sync restore that
//     somehow shuffled the JSON array.
//   * `RackSlotsConverter.fromSql` returns an UNMODIFIABLE list. Any
//     caller that mutates it (e.g. by `.add(...)`) throws at runtime
//     — that's deliberate; rack slots are read-only reference data.
//   * Empty-string fromSql input returns `const []` (not throws).
//     This handles a degenerate seed (rack with zero slots) without
//     crashing the picker. Real seeds always ship ≥1 slot.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   * `lib/database/database.dart` — `TargetRacks.slotsJson` column
//     `.map(const RackSlotsConverter())()`.
//   * `lib/database/seed_loader.dart` — parses each rack's `children`
//     array as `List<RackSlot>` and passes to `TargetRacksCompanion.insert`.
//   * `lib/repositories/target_repository.dart` — `childrenOf(rackId)`
//     returns the list verbatim from the loaded `TargetRackRow`.
//   * `lib/screens/range_day/widgets/target_plot.dart` — the rack
//     painter reads `RackSlot.category` / `shapeId` / dimensions /
//     offsets to position each shootable.
//   * `lib/screens/range_day/range_day_detail_screen.dart` — picker
//     + active-slot logic reads from the in-memory list.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
//   * None. Pure value class + pure JSON (de)serialisation. The
//     TypeConverter is called by drift inside its database transaction;
//     this file doesn't open a connection itself.

import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:drift/drift.dart' show TypeConverter;

/// One shootable target inside a multi-target rack.
///
/// Immutable. Author-time order is significant — `position` is the
/// engagement order (left-to-right for KYL / equal racks, near-to-far
/// for some PRS racks, custom for IDPA stages). The repository hands
/// the slot list back in position order; consumers (painter, picker,
/// active-slot index) treat that as canonical.
class RackSlot {
  const RackSlot({
    required this.position,
    this.shapeId,
    required this.name,
    required this.category,
    required this.widthIn,
    required this.heightIn,
    required this.offsetXIn,
    required this.offsetYIn,
    required this.sizeRank,
    required this.colorHex,
  });

  /// 0-indexed engagement order. The detail-screen picker uses this
  /// as the array index into the in-memory slot list, AND as the
  /// integer stored in `RangeDaySessions.rackChildPosition`.
  final int position;

  /// Optional SVG dispatch key. Populated for `special`-category
  /// apparatus (`pepper_popper`, `texas_star` etc.) so the painter
  /// can route to the per-shape geometry. Plain circles / squares /
  /// rectangles leave it null.
  final String? shapeId;

  /// Display label in the active-slot picker (e.g. `Plate 1 (5 in dia)`).
  final String name;

  /// Phase 9.5 — closed enum: `circle | square | rectangle | ipsc |
  /// animal | special`. Drives painter dispatch the same way the
  /// top-level `Targets.category` column does for single targets.
  final String category;

  final double widthIn;
  final double heightIn;

  /// Per-slot offset from the rack center, in inches. Positive X is
  /// right of center; positive Y is above center.
  final double offsetXIn;
  final double offsetYIn;

  /// Stepping rank for KYL-style racks (smaller plate = higher rank).
  /// Used by the painter for size-rank-aware highlighting tints.
  /// Defaults to 1 (no stepping) for racks where every plate is the
  /// same size.
  final int sizeRank;

  /// Hex color string (`#rrggbb`). Defaults to `#ffffff` (white steel
  /// plate) when the seed file leaves it unset.
  final String colorHex;

  factory RackSlot.fromJson(Map<String, dynamic> m) => RackSlot(
        position: m['position'] as int,
        shapeId: m['shape_id'] as String?,
        name: m['name'] as String,
        category: m['category'] as String,
        widthIn: (m['width_in'] as num).toDouble(),
        heightIn: (m['height_in'] as num).toDouble(),
        offsetXIn: (m['x_offset_in'] as num).toDouble(),
        offsetYIn: (m['y_offset_in'] as num).toDouble(),
        sizeRank: m['size_rank'] as int? ?? 1,
        colorHex: m['color_hex'] as String? ?? '#ffffff',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'position': position,
        if (shapeId != null) 'shape_id': shapeId,
        'name': name,
        'category': category,
        'width_in': widthIn,
        'height_in': heightIn,
        'x_offset_in': offsetXIn,
        'y_offset_in': offsetYIn,
        'size_rank': sizeRank,
        'color_hex': colorHex,
      };

  @override
  String toString() => 'RackSlot(#$position $category "$name" '
      '$widthIn x $heightIn in @ ($offsetXIn, $offsetYIn))';
}

/// drift TypeConverter for the `TargetRacks.slotsJson` column.
///
/// `fromSql` parses the JSON, builds typed `RackSlot` objects, sorts
/// defensively by `position`, and returns an `UnmodifiableListView`
/// so callers can't accidentally mutate cached reference data.
///
/// `toSql` is the inverse — preserves the in-memory order verbatim
/// (the round-trip-through-sort happens in `fromSql`, not here).
class RackSlotsConverter extends TypeConverter<List<RackSlot>, String> {
  const RackSlotsConverter();

  @override
  List<RackSlot> fromSql(String fromDb) {
    if (fromDb.isEmpty) return const <RackSlot>[];
    final decoded = jsonDecode(fromDb);
    if (decoded is! List) {
      throw StateError(
          'RackSlotsConverter.fromSql: expected JSON list, got '
          '${decoded.runtimeType}');
    }
    final slots = decoded
        .cast<Map<String, dynamic>>()
        .map(RackSlot.fromJson)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return List<RackSlot>.unmodifiable(slots);
  }

  @override
  String toSql(List<RackSlot> value) =>
      jsonEncode(value.map((s) => s.toJson()).toList());
}
