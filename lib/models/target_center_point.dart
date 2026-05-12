// FILE: lib/models/target_center_point.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Value class for the per-target geometric "center point" — a 2D
// fractional anchor inside a target's bounding rect, used by the
// Range Day Realistic scene painter to know where on the target to
// anchor the pole top, and reserved for future visual-anchoring needs
// (dispersion centroid for hit-probability overlays, drag pivot for
// reticle placement, animation pivot, etc.).
//
// Both fractions are in `0.0..1.0`:
//   * `verticalFromTop`: 0.0 = top edge of the rect, 1.0 = bottom.
//   * `horizontalFromLeft`: 0.0 = left edge, 1.0 = right.
// Defaults are `0.5 / 0.5` (= geometric center of the rect), which
// matches the Phase 5 painter's hardcoded `targetRect.center` anchor.
// Pre-v37 catalog rows seed with these defaults, so existing scenes
// render identically until per-row tuning is authored.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Animal silhouettes don't have their visual center at their
// geometric center. A deer's "core" (the mass of the body where a
// pole would naturally mount) sits below the head + antlers and to
// the rear of the body. Hardcoding `targetRect.center` puts the pole
// through the deer's head. Per-target tuning via this value class
// lets the catalog author say "anchor the pole at 65% down, 40%
// right" for a deer and have it Just Work.
//
// Plumbed through:
//   * `assets/seed_data/targets.json` — `center_point` block on
//     each entry.
//   * `lib/database/database.dart` `Targets` table — two RealColumn
//     fields (`verticalCenterPctFromTop`, `horizontalCenterPctFromLeft`)
//     added in schema v37.
//   * `lib/database/seed_loader.dart` `_seedTargets` — reads the
//     JSON block and writes both columns.
//   * `lib/screens/range_day/widgets/target_plot.dart` `TargetSpec`
//     — surfaces `centerPoint`; `_RealisticScenePainter` consumes
//     it in `paint()` for pole anchoring.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * The drift column defaults (0.5 / 0.5) MUST match the
//     `defaultCenter` static here. If they drift, a row inserted
//     without an explicit value would render at one anchor while a
//     row inserted with explicit-default would render at another —
//     a confusing edge case to debug.
//   * `fromJson` is null-safe at every layer because legacy catalog
//     entries written before v37 lack the field entirely. The seed
//     loader passes `null` for missing blocks and gets back
//     `defaultCenter`.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   * `/Users/general/Development/Applications/LoadOut/lib/database/seed_loader.dart`
//   * `/Users/general/Development/Applications/LoadOut/lib/screens/range_day/widgets/target_plot.dart`
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure value class.

class TargetCenterPoint {
  final double verticalFromTop;
  final double horizontalFromLeft;

  const TargetCenterPoint({
    this.verticalFromTop = 0.5,
    this.horizontalFromLeft = 0.5,
  });

  static const TargetCenterPoint defaultCenter = TargetCenterPoint();

  factory TargetCenterPoint.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaultCenter;
    return TargetCenterPoint(
      verticalFromTop:
          (json['vertical_from_top'] as num?)?.toDouble() ?? 0.5,
      horizontalFromLeft:
          (json['horizontal_from_left'] as num?)?.toDouble() ?? 0.5,
    );
  }
}
