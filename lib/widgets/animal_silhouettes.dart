// FILE: lib/widgets/animal_silhouettes.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Loads, parses, caches, and rescales hand-authored SVG silhouettes for the
// 16 animal targets shipped with the Range Day v2.3 catalog (deer, mule deer,
// elk, moose, pronghorn, bear, boar, mountain lion, coyote, fox, rabbit,
// groundhog, prairie dog, wild turkey, pheasant, and a novelty bigfoot).
//
// Public surface on the static class `AnimalSilhouettes`:
//   * `isAnimalShape(shapeId)` — true when the supplied `shape_id` from
//     `targets.json` resolves to one of the 16 known assets.
//   * `loadAnimalPath(shapeId)` — returns the cached or newly-parsed
//     `Path` in source SVG coordinates. First call pays the rootBundle read
//     + parse cost (~5ms); subsequent calls are O(1) cache hits.
//   * `scalePathToBounds(source, bounds)` — uniformly scales a source path
//     to fit a destination Rect while preserving aspect ratio and bottom-
//     aligning the silhouette (feet rest on the bottom of the rect, which
//     is the post connection point on a real range target).
//   * `buildAnimalPath(bounds, shapeId)` — convenience: load + scale in
//     one async call.
//
// The class is purely static; there is no constructor / instance.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Range Day's target picker and on-screen target widget need to render
// animal silhouettes that look like real game animals — not crude wireframes
// drawn from primitives. Hand-authored SVGs deliver that fidelity, but
// Flutter's `Canvas` API draws `Path` objects, not raw SVG XML. This file
// is the bridge: read the SVG once, extract every `<path d="..."/>` blob,
// parse them through the `path_drawing` package, fold them into a single
// `Path`, then cache the result so subsequent picker / preview / range
// renderings cost nothing.
//
// If this file were deleted, every place that renders an animal target
// would have to repeat the rootBundle.loadString + regex + parse dance,
// and the picker would visibly stutter as the user scrolls through the
// 16 entries. Caching is the headline reason the file is a separate
// service rather than inline parse calls.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * SVG `<path>` elements come in singletons AND clusters. prairie_dog
//     ships as 4 sibling `<path>` elements; the parser must combine them
//     into one Path via `Path.addPath(subpath, Offset.zero)` so a single
//     `canvas.drawPath` call renders the full silhouette. The regex is
//     deliberately permissive about attribute order and whitespace inside
//     the opening tag (`<path  fill="..." d=" ... "/>` parses).
//   * The cache uses two maps: `_pathCache` for completed loads and
//     `_loadFutures` for in-flight ones. The in-flight map prevents the
//     same SVG from being parsed twice when two widgets simultaneously
//     request it on first launch (race condition before the preload
//     `Future.wait` completes).
//   * Bottom-alignment is load-bearing for the post-mounted target
//     visualization. The math: scale uniformly to whichever axis is the
//     binding constraint, then translate so the source's bottom edge
//     lines up with `bounds.bottom`. Translating by `bounds.bottom -
//     scaledHeight - src.top * scale` looks unintuitive but it correctly
//     accounts for SVGs whose bounding box doesn't start at (0, 0).
//   * `Path.transform` takes a 16-element `Float64List` from `Matrix4.storage`,
//     not a `Matrix4` object directly.
//   * `parseSvgPathData` from `path_drawing` does NOT raise on malformed
//     input — it returns an empty `Path`. We rely on visual review of
//     the 16 shipped SVGs during this phase; a malformed file would render
//     as an empty silhouette rather than throwing.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   * `lib/main.dart` — preloads all 16 paths fire-and-forget after Firebase
//     initialization (per Appendix H.4 of the Range Day Realistic v2.3
//     rewrite).
//   * `lib/widgets/target_silhouettes.dart` — sibling file for non-animal
//     silhouettes, parallel design with shared parsing strategy.
//   * Range Day target picker + on-screen target widget (consume via
//     `buildAnimalPath` once those screens are wired in subsequent phases
//     of the v2.3 rewrite).
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
//   * Reads asset files from `assets/silhouettes/animals/*.svg` via
//     Flutter's `rootBundle.loadString`. No filesystem writes, no network
//     calls, no native channels.
//   * Caches parsed `Path` objects in process memory for the lifetime of
//     the app process. Total cache size is bounded by the 16 silhouettes
//     (~250 KB of SVG source, smaller after parse).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_drawing/path_drawing.dart';
import 'dart:async';

/// Renders hand-authored SVG silhouettes for animal targets.
/// SVGs live in assets/silhouettes/animals/{filename}.svg.
class AnimalSilhouettes {
  /// Map of shape_id (from targets.json) to asset filename.
  static const Map<String, String> _shapeIdToAsset = {
    'deer_profile':           'assets/silhouettes/animals/deer.svg',
    'mule_deer_profile':      'assets/silhouettes/animals/mule_deer.svg',
    'elk_profile':            'assets/silhouettes/animals/elk.svg',
    'moose_profile':          'assets/silhouettes/animals/moose.svg',
    'pronghorn_profile':      'assets/silhouettes/animals/pronghorn.svg',
    'bear_profile':           'assets/silhouettes/animals/bear.svg',
    'boar_profile':           'assets/silhouettes/animals/boar.svg',
    'mountain_lion_profile':  'assets/silhouettes/animals/mountain_lion.svg',
    'coyote_profile':         'assets/silhouettes/animals/coyote.svg',
    'fox_profile':            'assets/silhouettes/animals/fox.svg',
    'rabbit_profile':         'assets/silhouettes/animals/rabbit.svg',
    'groundhog_profile':      'assets/silhouettes/animals/groundhog.svg',
    'prairie_dog_profile':    'assets/silhouettes/animals/prairie_dog_standing.svg',
    'wild_turkey_profile':    'assets/silhouettes/animals/wild_turkey.svg',
    'pheasant_profile':       'assets/silhouettes/animals/pheasant.svg',
    'bigfoot_profile':        'assets/silhouettes/animals/bigfoot.svg',
  };

  /// Cache of parsed Path objects keyed by shape_id.
  /// First use of each shape pays the SVG parse cost; subsequent uses are free.
  static final Map<String, Path> _pathCache = {};
  static final Map<String, Future<Path>> _loadFutures = {};

  static bool isAnimalShape(String shapeId) => _shapeIdToAsset.containsKey(shapeId);

  /// Loads and parses the SVG path for [shapeId]. Cached after first call.
  static Future<Path> loadAnimalPath(String shapeId) async {
    final cached = _pathCache[shapeId];
    if (cached != null) return cached;

    final inFlight = _loadFutures[shapeId];
    if (inFlight != null) return inFlight;

    final assetPath = _shapeIdToAsset[shapeId];
    if (assetPath == null) {
      throw StateError('Unknown animal shape_id: $shapeId');
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

  /// Extracts ALL <path d="..."/> attributes from the SVG and combines them
  /// into a single Path. Each path's geometry becomes a subpath of the result.
  ///
  /// Multi-path SVG support is important: some authored silhouettes (e.g.
  /// prairie_dog_standing.svg with 4 paths) contain multiple sibling <path>
  /// elements. Concatenating their geometries into one Path correctly renders
  /// the full silhouette via a single canvas.drawPath call.
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

  /// Returns a Path that fits [bounds] while preserving the source SVG's
  /// aspect ratio. The silhouette is centered horizontally and bottom-aligned
  /// (feet rest at the bottom of the rect, matching the post connection point).
  static Path scalePathToBounds(Path source, Rect bounds) {
    final src = source.getBounds();
    if (src.width <= 0 || src.height <= 0) return source;

    final scaleX = bounds.width / src.width;
    final scaleY = bounds.height / src.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;  // uniform scale

    final scaledWidth = src.width * scale;
    final scaledHeight = src.height * scale;
    final dx = bounds.left + (bounds.width - scaledWidth) / 2 - src.left * scale;
    final dy = bounds.bottom - scaledHeight - src.top * scale;  // bottom-align

    final matrix = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale, scale);
    return source.transform(matrix.storage);
  }

  /// Convenience: load + scale in one call.
  static Future<Path> buildAnimalPath(Rect bounds, String shapeId) async {
    final source = await loadAnimalPath(shapeId);
    return scalePathToBounds(source, bounds);
  }
}
