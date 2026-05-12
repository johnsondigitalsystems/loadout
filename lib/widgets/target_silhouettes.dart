// FILE: lib/widgets/target_silhouettes.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Sibling of `lib/widgets/animal_silhouettes.dart`, but for the non-animal
// competition silhouettes — pepper poppers today, with reserved slots for
// IDPA, USPSA, NRA B-27, NRA B-21, steel C/D zones, three-gun rifle, and
// hostage targets as those SVGs land in subsequent waves.
//
// Public surface on the static class `TargetSilhouettes`:
//   * `isTargetShape(shapeId)` — true when the supplied `shape_id` resolves
//     to one of the known assets in `assets/silhouettes/targets/`.
//   * `loadTargetPath(shapeId)` — returns the cached or newly-parsed
//     `Path` in source SVG coordinates.
//   * `scalePathToBounds(source, bounds)` — uniformly scales a source path
//     to fit a destination Rect while preserving aspect ratio and bottom-
//     aligning the silhouette (poppers and IPSC silhouettes both sit on
//     a base, same as animals on a post).
//   * `buildTargetPath(bounds, shapeId)` — convenience: load + scale in
//     one async call.
//
// The class is purely static; there is no constructor / instance.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Animal silhouettes and competition silhouettes share the same parsing,
// caching, and scaling strategy but live under separate asset directories
// and have separate `shape_id` namespaces. Splitting the two surfaces into
// parallel classes keeps each registry tightly focused — adding a new
// pepper-popper variant doesn't pollute the animal-shape switch, and the
// preload list in `main.dart` reads as two clear groups (animals, then
// competition targets).
//
// If this file were folded into `AnimalSilhouettes`, the `_shapeIdToAsset`
// map would grow into a 25+ entry blob mixing biology with cardboard, and
// the "what category does this shape belong to?" question would have no
// clear answer at the API level.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * The parser is intentionally a copy of `AnimalSilhouettes._extract...`
//     rather than a shared helper. Reason: both classes are static and
//     having one depend on the other creates an import direction that
//     becomes painful when either side ships independently. The cost is
//     ~30 duplicated lines.
//   * The reserved slots in the asset map (commented `// 'ipsc_open_stage':
//     ...` etc.) are documentation, not dead code — they remind the
//     engineer who lands the next SVG of the established `shape_id`
//     naming convention.
//   * Bottom-alignment matters as much for poppers as animals: a popper
//     mounted on a falling-target base should pivot at the bottom of
//     the rendered rect, which is also where the user expects to drag-
//     drop it onto a virtual target stand.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   * `lib/main.dart` — preloads the pepper popper SVG fire-and-forget
//     during boot (per Appendix M of the Range Day Realistic v2.3 rewrite).
//   * Range Day target picker + on-screen target widget (consume via
//     `buildTargetPath` once those screens are wired in subsequent phases).
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
//   * Reads asset files from `assets/silhouettes/targets/*.svg` via
//     Flutter's `rootBundle.loadString`. No filesystem writes, no network
//     calls, no native channels.
//   * Caches parsed `Path` objects in process memory for the lifetime of
//     the app process. Current footprint is one SVG (~2 KB); footprint
//     grows linearly as reserved slots are filled.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_drawing/path_drawing.dart';
import 'dart:async';

/// Renders hand-authored SVG silhouettes for competition targets (pepper poppers,
/// IDPA, USPSA classifier, NRA B-27, etc.). Parallel to AnimalSilhouettes.
/// SVGs live in assets/silhouettes/targets/{filename}.svg.
class TargetSilhouettes {
  /// Map of shape_id (from targets.json / target_racks.json) to asset filename.
  static const Map<String, String> _shapeIdToAsset = {
    'pepper_popper': 'assets/silhouettes/targets/pepper_popper.svg',
    // Future additions per docs/ROADMAP.md "Competition target SVGs":
    // 'ipsc_open_stage':    'assets/silhouettes/targets/ipsc_open_stage.svg',
    // 'uspsa_classifier_b': 'assets/silhouettes/targets/uspsa_classifier_b.svg',
    // 'nra_b27':            'assets/silhouettes/targets/nra_b27.svg',
    // 'nra_b21':            'assets/silhouettes/targets/nra_b21.svg',
    // 'steel_c_zone':       'assets/silhouettes/targets/steel_c_zone.svg',
    // 'steel_d_zone':       'assets/silhouettes/targets/steel_d_zone.svg',
    // 'three_gun_rifle':    'assets/silhouettes/targets/three_gun_rifle.svg',
    // 'hostage_target':     'assets/silhouettes/targets/hostage_target.svg',
  };

  static final Map<String, Path> _pathCache = {};
  static final Map<String, Future<Path>> _loadFutures = {};

  static bool isTargetShape(String shapeId) => _shapeIdToAsset.containsKey(shapeId);

  static Future<Path> loadTargetPath(String shapeId) async {
    final cached = _pathCache[shapeId];
    if (cached != null) return cached;

    final inFlight = _loadFutures[shapeId];
    if (inFlight != null) return inFlight;

    final assetPath = _shapeIdToAsset[shapeId];
    if (assetPath == null) {
      throw StateError('Unknown target shape_id: $shapeId');
    }

    final future = _loadAndParse(assetPath);
    _loadFutures[shapeId] = future;
    final path = await future;
    _pathCache[shapeId] = path;
    _loadFutures.remove(shapeId);
    return path;
  }

  static Future<Path> _loadAndParse(String assetPath) async {
    final svgContent = await rootBundle.loadString(assetPath);
    return _extractAndCombinePaths(svgContent, assetPath);
  }

  /// Same multi-path extraction logic as AnimalSilhouettes.
  static Path _extractAndCombinePaths(String svgContent, String assetPath) {
    final matches = RegExp(
      r'<path\b[^>]*\bd\s*=\s*"([^"]+)"',
      multiLine: true,
    ).allMatches(svgContent);

    if (matches.isEmpty) {
      throw StateError('No <path d="..."/> found in $assetPath');
    }

    final combined = Path();
    for (final match in matches) {
      final d = match.group(1)!;
      final subpath = parseSvgPathData(d);
      combined.addPath(subpath, Offset.zero);
    }
    return combined;
  }

  /// Scale to fit bounds while preserving aspect ratio; bottom-aligned.
  /// (Same algorithm as AnimalSilhouettes.scalePathToBounds.)
  static Path scalePathToBounds(Path source, Rect bounds) {
    final src = source.getBounds();
    if (src.width <= 0 || src.height <= 0) return source;

    final scaleX = bounds.width / src.width;
    final scaleY = bounds.height / src.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final scaledWidth = src.width * scale;
    final scaledHeight = src.height * scale;
    final dx = bounds.left + (bounds.width - scaledWidth) / 2 - src.left * scale;
    final dy = bounds.bottom - scaledHeight - src.top * scale;

    final matrix = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale, scale);
    return source.transform(matrix.storage);
  }

  static Future<Path> buildTargetPath(Rect bounds, String shapeId) async {
    final source = await loadTargetPath(shapeId);
    return scalePathToBounds(source, bounds);
  }
}
