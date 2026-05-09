// FILE: lib/data/reticle_seed_defaults.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Hard-coded fallback library of reticle definitions to seed into the
// `Reticles` SQLite table when no `reticles.json` is present in
// `assets/seed_data/`. Without it the dropdown in the Range Day picker
// would be empty on a fresh install -- instead we ship a small set of
// LoadOut-original archetype patterns plus a couple of public-domain
// staples so the picker has something useful from minute one.
//
// `seedDefaultReticlesIfEmpty(db)` is idempotent: it only writes when
// `db.reticlesAreEmpty` is true. Callers can fire-and-forget on app
// start (or lazily on first picker open).
//
// The actual definition data lives in `_defaultDefinitions` below. Each
// entry is a [ReticleDefinition] built directly in code -- no JSON
// round-trip -- because the structures are tiny.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The full canonical catalog ships in `assets/seed_data/reticles.json`
// (legacy shape) and `assets/seed_data/reticles_v2.json` (verified shape
// with provenance fields). When the seed-loader pipeline runs without
// access to those JSON files (e.g. a unit test that builds an in-memory
// AppDatabase, or a future surgical regression that strips the assets),
// this fallback catches the empty-table case so the picker never opens
// onto an empty list. The five entries below are deliberately the
// LoadOut "default" archetypes for mil and MOA plus the most universal
// public-domain patterns, so even the fallback path covers the four
// most common reticle categories: precision mil, precision MOA, simple
// crosshair / mil-dot ranging, and hunting plex.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * The renderer can only paint elements from the small vocabulary in
//     `lib/data/reticle_library.dart` (`crosshair`, `hash`, `dot`,
//     `number`, `holdover`). New shapes (arcs, polygons) are NOT
//     supported here -- approximations like the horseshoe in the full
//     catalog use clusters of small filled dots. Keep the fallback set
//     to patterns the renderer can already draw faithfully.
//   * The ratio between `maxExtentUnits` and individual element
//     coordinates governs the on-canvas size. A reticle with
//     `maxExtentUnits = 5` and elements out to +/-5 fills the canvas
//     border-to-border; a reticle with elements at +/-2 in a
//     5-unit-extent canvas leaves a generous border. Mil reticles
//     mostly use 5 or 10 unit extent; MOA reticles 15-30.
//   * Each entry passes `verified: false` (the schema default) because
//     the in-code fallback does not cite a `sourceUrl`. The picker UI
//     must hide unverified rows or show an "unverified" guard for
//     rows that are NOT recognized LoadOut archetypes -- but the
//     LoadOut archetype rows are first-class verified data; the JSON
//     catalog drives the picker on a real install. This file is a
//     last-resort fallback only.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `lib/main.dart` calls `seedDefaultReticlesIfEmpty(db)` on launch
//   AFTER the JSON-driven seed pipeline has run. If the JSON pipeline
//   already populated the table, this no-ops.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Writes rows to the `Reticles` table when the table is empty.
// - No network, no logging.

import 'package:drift/drift.dart';

import '../database/database.dart';
import 'reticle_library.dart';

/// Idempotently seed the LoadOut fallback reticle archetypes into the
/// `Reticles` table. Returns immediately if any rows already exist.
Future<void> seedDefaultReticlesIfEmpty(AppDatabase db) async {
  if (!await db.reticlesAreEmpty) return;
  await db.batch((b) {
    for (final def in _defaultDefinitions) {
      b.insert(
        db.reticles,
        ReticlesCompanion.insert(
          manufacturerId: def.manufacturer,
          model: def.model,
          family: Value(def.family),
          type: _typeText(def.type),
          nativeUnit: _unitText(def.nativeUnit),
          maxExtentUnits: def.maxExtentUnits,
          definitionJson: def.elementsAsJson(),
          notes: Value(def.notes),
        ),
      );
    }
  });
}

String _typeText(ReticleType t) {
  switch (t) {
    case ReticleType.firstFocalPlane:
      return 'ffp';
    case ReticleType.secondFocalPlane:
      return 'sfp';
    case ReticleType.fixed:
      return 'fixed';
  }
}

String _unitText(ReticleNativeUnit u) {
  switch (u) {
    case ReticleNativeUnit.mil:
      return 'mil';
    case ReticleNativeUnit.moa:
      return 'moa';
    case ReticleNativeUnit.ipsc:
      return 'ipsc';
    case ReticleNativeUnit.bdc:
      return 'bdc';
  }
}

/// Build a centred horizontal + vertical crosshair list with hash marks
/// every `step` native units out to +/-extent. The major-tick rule
/// doubles the tick length on every other hash (so a 0.5-mil step has
/// double-length ticks every 1 mil); `labelMajor` adds a small floating
/// number next to each major tick.
List<ReticleElement> _hashGrid({
  required double extent,
  required double step,
  double tickLen = 0.4,
  double thickness = 0.04,
  bool labelMajor = true,
}) {
  final out = <ReticleElement>[];
  // Crosshairs.
  out.add(CrosshairLine(
    startX: -extent,
    startY: 0,
    endX: extent,
    endY: 0,
    thicknessMil: thickness,
  ));
  out.add(CrosshairLine(
    startX: 0,
    startY: -extent,
    endX: 0,
    endY: extent,
    thicknessMil: thickness,
  ));
  // Center dot.
  out.add(const CenterDot(radiusUnits: 0.06));

  for (var i = 1; i * step <= extent + 0.001; i++) {
    final v = (i * step).toDouble();
    final isMajor = i % 2 == 0;
    out.add(HashMark(
      x: v,
      y: 0,
      lengthUnits: tickLen * (isMajor ? 1.4 : 1.0),
      thicknessUnits: thickness,
      axis: HashAxis.horizontal,
    ));
    out.add(HashMark(
      x: -v,
      y: 0,
      lengthUnits: tickLen * (isMajor ? 1.4 : 1.0),
      thicknessUnits: thickness,
      axis: HashAxis.horizontal,
    ));
    out.add(HashMark(
      x: 0,
      y: v,
      lengthUnits: tickLen * (isMajor ? 1.4 : 1.0),
      thicknessUnits: thickness,
      axis: HashAxis.vertical,
    ));
    out.add(HashMark(
      x: 0,
      y: -v,
      lengthUnits: tickLen * (isMajor ? 1.4 : 1.0),
      thicknessUnits: thickness,
      axis: HashAxis.vertical,
    ));
    if (labelMajor && isMajor) {
      out.add(FloatingNumber(
        x: v + tickLen,
        y: -tickLen,
        text: i.toString(),
        fontSizeUnits: 0.55,
      ));
      out.add(FloatingNumber(
        x: -tickLen,
        y: -v - tickLen,
        text: i.toString(),
        fontSizeUnits: 0.55,
      ));
    }
  }
  return out;
}

/// LoadOut fallback reticle archetypes. These mirror the canonical
/// versions in `assets/seed_data/reticles_v2.json` but are intentionally
/// simpler -- the fallback is only for the empty-DB / asset-stripped
/// case; the JSON-driven seed pipeline drives the real picker.
final List<ReticleDefinition> _defaultDefinitions = [
  // LoadOut Default - Mil Tree (the picker's recommended starting
  // point for any precision mil scope).
  ReticleDefinition(
    id: 'loadout_default_mil_tree',
    manufacturer: 'LoadOut',
    model: 'LoadOut Default - Mil Tree',
    family: 'LoadOut Mil reticles',
    type: ReticleType.firstFocalPlane,
    nativeUnit: ReticleNativeUnit.mil,
    maxExtentUnits: 5,
    elements: _hashGrid(extent: 5, step: 0.5),
    notes: 'LoadOut default mil reticle. Mil cross + 0.5-mil hashes '
        '+/-5 mil with numbered labels every 2 mil. Original LoadOut '
        'design.',
    designer: 'LoadOut',
  ),
  // LoadOut Default - MOA Tree (the picker's recommended starting
  // point for any precision MOA scope).
  ReticleDefinition(
    id: 'loadout_default_moa_tree',
    manufacturer: 'LoadOut',
    model: 'LoadOut Default - MOA Tree',
    family: 'LoadOut MOA reticles',
    type: ReticleType.firstFocalPlane,
    nativeUnit: ReticleNativeUnit.moa,
    maxExtentUnits: 30,
    elements: _hashGrid(extent: 30, step: 2.0, tickLen: 1.0, thickness: 0.12),
    notes: 'LoadOut default MOA reticle. MOA cross + 1-MOA hashes '
        '+/-30 MOA with labels every 5 MOA. Original LoadOut design.',
    designer: 'LoadOut',
  ),
  // Public-domain mil-dot pattern (USMC).
  ReticleDefinition(
    id: 'pd_mil_dot_usmc',
    manufacturer: 'Public domain',
    model: 'Mil-Dot (USMC)',
    family: 'Public-domain reticles',
    type: ReticleType.secondFocalPlane,
    nativeUnit: ReticleNativeUnit.mil,
    maxExtentUnits: 5,
    elements: const [
      CrosshairLine(
          startX: -5, startY: 0, endX: 5, endY: 0, thicknessMil: 0.05),
      CrosshairLine(
          startX: 0, startY: -5, endX: 0, endY: 5, thicknessMil: 0.05),
      CenterDot(radiusUnits: 0.08),
      // 0.75 MOA-like dots at every mil out to 4 mil per side.
      CenterDot(x: 1, y: 0, radiusUnits: 0.11),
      CenterDot(x: -1, y: 0, radiusUnits: 0.11),
      CenterDot(x: 2, y: 0, radiusUnits: 0.11),
      CenterDot(x: -2, y: 0, radiusUnits: 0.11),
      CenterDot(x: 3, y: 0, radiusUnits: 0.11),
      CenterDot(x: -3, y: 0, radiusUnits: 0.11),
      CenterDot(x: 4, y: 0, radiusUnits: 0.11),
      CenterDot(x: -4, y: 0, radiusUnits: 0.11),
      CenterDot(x: 0, y: 1, radiusUnits: 0.11),
      CenterDot(x: 0, y: -1, radiusUnits: 0.11),
      CenterDot(x: 0, y: 2, radiusUnits: 0.11),
      CenterDot(x: 0, y: -2, radiusUnits: 0.11),
      CenterDot(x: 0, y: 3, radiusUnits: 0.11),
      CenterDot(x: 0, y: -3, radiusUnits: 0.11),
      CenterDot(x: 0, y: 4, radiusUnits: 0.11),
      CenterDot(x: 0, y: -4, radiusUnits: 0.11),
    ],
    notes: 'Original USMC mil-dot pattern (public domain). Mil cross + '
        '0.75-MOA dots at every mil.',
    designer: 'Public domain',
  ),
  // Public-domain plex (the universal hunting reticle).
  ReticleDefinition(
    id: 'pd_plex',
    manufacturer: 'Public domain',
    model: 'Plex',
    family: 'Public-domain reticles',
    type: ReticleType.secondFocalPlane,
    nativeUnit: ReticleNativeUnit.moa,
    maxExtentUnits: 24,
    elements: const [
      CrosshairLine(
          startX: -6, startY: 0, endX: 6, endY: 0, thicknessMil: 0.08),
      CrosshairLine(
          startX: 0, startY: -6, endX: 0, endY: 6, thicknessMil: 0.08),
      CrosshairLine(
          startX: -24,
          startY: 0,
          endX: -6,
          endY: 0,
          thicknessMil: 0.6),
      CrosshairLine(
          startX: 6, startY: 0, endX: 24, endY: 0, thicknessMil: 0.6),
      CrosshairLine(
          startX: 0,
          startY: -24,
          endX: 0,
          endY: -6,
          thicknessMil: 0.6),
      CrosshairLine(
          startX: 0, startY: 6, endX: 0, endY: 24, thicknessMil: 0.6),
      CenterDot(radiusUnits: 0.05),
    ],
    notes: 'Classic four-quadrant hunting plex reticle. Public domain.',
    designer: 'Public domain',
  ),
];
