// FILE: lib/services/watch_payload_projection.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Pure-function projections that translate LoadOut's domain rows
// (UserLoadRow, BallisticProfileRow, UserFirearmRow, CommonLoad, the
// solver's TrajectorySample list) into the typed payloads the
// Apple Watch / Wear OS bridge ships. One projection per push site —
// the Range Day screen calls them, then hands the result to
// [WatchBridgeService.sendActiveLoad] / `sendDope` /
// `sendFirearmGlance`.
//
// Public surface:
//   * `WatchPayloadProjection.activeLoadFromUserLoad(UserLoadRow)`
//   * `WatchPayloadProjection.activeLoadFromBallisticProfile(BallisticProfileRow)`
//   * `WatchPayloadProjection.activeLoadFromCommonLoad(CommonLoad)`
//   * `WatchPayloadProjection.firearmGlanceFromUserFirearm(UserFirearmRow)`
//   * `WatchPayloadProjection.dopeFromSolverOutput(...)` — large
//     parameter list because the solver scatters its inputs across
//     several arg buckets; this is the one place that re-assembles
//     them into the wire payload.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Without this file, the Range Day detail screen would inline the
// projection logic next to the bridge calls, mixing "translate domain
// row to wire shape" with "find context and push" in the same method
// body. That coupling makes the projection logic untestable in
// isolation — every test would have to spin up a widget tree just to
// exercise a static field-mapping.
//
// Pulling the projections out as static functions on a side-effect-free
// class lets the unit tests assert on the wire shape directly, against
// hand-built source rows, without any provider plumbing. The screen
// helpers shrink to "build the snapshot via WatchPayloadProjection,
// hand to context.read<WatchBridgeService>().send*". Easy to read,
// easy to grep when adding a new field.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **Source rows are messy.** UserLoadRow has dozens of nullable
//    columns, of which only a handful matter on the watch glance card.
//    Profiles don't carry a cartridge name at all; common loads carry
//    one as a "family name" field. Each projection has to know which
//    fields are meaningful and which to drop.
//
// 2. **The DOPE projection converts units.** The solver's
//    [TrajectorySample] reports drop and windage in inches; the watch
//    surface speaks mils. Conversion uses
//    [bu.inchesToMilAtYards] (small-angle approximation) and rounds to
//    two decimals on the wire to keep the payload under the 16 KiB
//    transport budget. Stay consistent with the convention here — if
//    the watch starts wanting MOA, change the conversion in ONE place.
//
// 3. **Pure functions only.** No `BuildContext`, no `Provider.read`,
//    no I/O, no clock reads other than the explicit `generatedAtMs`
//    arg. This is what makes them unit-testable. Keep it that way.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/range_day/range_day_detail_screen.dart — the only
//   call site today; the four `_pushXxxToWatch...` helpers each
//   delegate to one of these static methods.
// - test/watch_payload_projection_test.dart — round-trip tests
//   against hand-built source rows.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Every method is `static`, no I/O, no globals.

import '../database/database.dart';
import '../models/watch_payloads.dart';
import '../services/ballistics/drag_functions.dart';
import '../services/ballistics/projectile.dart';
import '../services/ballistics/solver.dart';
import '../services/ballistics/units.dart' as bu;
import '../services/common_loads_catalog.dart';

class WatchPayloadProjection {
  const WatchPayloadProjection._();

  /// Project a saved [UserLoadRow] into the watch's "active load"
  /// glance card. Cartridge name falls back to empty string when the
  /// recipe has no caliber set — the watch's glance UI hides the
  /// cartridge line in that case.
  static ActiveLoadSnapshot activeLoadFromUserLoad(UserLoadRow r) {
    return ActiveLoadSnapshot(
      name: r.name,
      cartridgeName: r.caliber ?? '',
      powderName: r.powder,
      powderChargeGr: r.powderChargeGr,
      bulletName: r.bullet,
      bulletWeightGr: r.bulletWeightGr,
      primer: r.primer,
      brass: r.brass,
      coalIn: r.coalIn,
      cbtoIn: r.cbtoIn,
    );
  }

  /// Project a [BallisticProfileRow] into the active-load glance card.
  /// Profiles don't carry recipe specifics (powder, primer, brass,
  /// COAL/CBTO) — they're closer to "ballistic parameters in the
  /// abstract" — so most fields are null. Cartridge name is the empty
  /// string because profiles don't have one.
  static ActiveLoadSnapshot activeLoadFromBallisticProfile(
    BallisticProfileRow p,
  ) {
    return ActiveLoadSnapshot(
      name: p.name,
      cartridgeName: '',
      bulletWeightGr: p.bulletWeightGr,
    );
  }

  /// Project a [CommonLoad] (the canned factory-load picker rows)
  /// into the active-load glance card. The common-load entry's
  /// `cartridge` is the cartridge family ("6.5 Creedmoor"); `name`
  /// includes the manufacturer + bullet ("Hornady ELD-M 140 gr").
  static ActiveLoadSnapshot activeLoadFromCommonLoad(CommonLoad load) {
    return ActiveLoadSnapshot(
      name: load.name,
      cartridgeName: load.cartridge,
      bulletName: load.name,
      bulletWeightGr: load.bulletWeightGr,
    );
  }

  /// Project a [UserFirearmRow] into the watch's firearm-glance card.
  /// `barrelLifeRemainingPct` is null because LoadOut doesn't track
  /// expected barrel life today — the watch UI shows just the running
  /// `shotsFired` counter when no expected life is known.
  static FirearmGlanceSnapshot firearmGlanceFromUserFirearm(
    UserFirearmRow f,
  ) {
    return FirearmGlanceSnapshot(
      name: f.name,
      shotsFired: f.shotsFired,
      caliber: f.caliber,
    );
  }

  /// Project the solver's output into a wire-format DOPE snapshot.
  ///
  /// Conversion notes:
  ///   * `dropInches` / `windDriftInches` → mils via
  ///     [bu.inchesToMilAtYards]. The watch trusts the values verbatim.
  ///   * `rangeYards` is rounded to the nearest integer because the
  ///     ladder in the wire payload is integer-keyed (saves bytes,
  ///     and the watch's glance UI groups by yard anyway).
  ///   * Drag model maps to lower-case 'g1' / 'g7' on the wire.
  ///   * Cartridge / bullet / firearm / profile names default to
  ///     empty string when the caller doesn't supply a hint —
  ///     CLAUDE.md § 0a allows empty strings to surface as "hidden
  ///     line" in the watch glance UI.
  static DopeSnapshot dopeFromSolverOutput({
    required List<TrajectorySample> samples,
    required Projectile projectile,
    required ShotInputs shot,
    required double windSpeedMph,
    required double windFromDeg,
    required int generatedAtMs,
    String cartridgeName = '',
    String bulletName = '',
    String? profileName,
    String? firearmName,
  }) {
    final dragModel = projectile.dragModel == DragModel.g7 ? 'g7' : 'g1';
    final rows = <DopeRow>[
      for (final s in samples)
        DopeRow(
          rangeYd: s.rangeYards.round(),
          dropMil: bu.inchesToMilAtYards(s.dropInches, s.rangeYards),
          windMil: bu.inchesToMilAtYards(s.windDriftInches, s.rangeYards),
          velocityFps: s.velocityFps,
          timeOfFlightSec: s.timeSec,
        ),
    ];
    return DopeSnapshot(
      cartridgeName: cartridgeName,
      bulletGr: projectile.weightGr,
      bulletName: bulletName,
      muzzleVelocityFps: shot.muzzleVelocityFps,
      zeroRangeYd: shot.zeroRangeYards.round(),
      windSpeedMph: windSpeedMph,
      windFromDeg: windFromDeg,
      dragModel: dragModel,
      bc: projectile.bc,
      rows: rows,
      generatedAtMs: generatedAtMs,
      profileName: profileName,
      firearmName: firearmName,
    );
  }
}
