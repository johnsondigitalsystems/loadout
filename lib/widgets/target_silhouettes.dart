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
import 'package:svg_path_parser/svg_path_parser.dart' as svg_strict;
import 'dart:async';

/// Phase 9 Group C.3 — mirror of `_ParsedSvgPath` in
/// `animal_silhouettes.dart`. See that file for full doc; this is the
/// sibling type for non-animal target SVGs (IPSC, popper, etc.).
class _ParsedSvgPath {
  _ParsedSvgPath(this.path, this.fillHex, this.strokeHex, this.dString)
      : bounds = path.getBounds();

  final Path path;
  final String? fillHex;
  final String? strokeHex;
  final String dString;
  final Rect bounds;
}

/// Renders hand-authored SVG silhouettes for competition targets (pepper poppers,
/// IDPA, USPSA classifier, NRA B-27, etc.). Parallel to AnimalSilhouettes.
/// SVGs live in assets/silhouettes/targets/{filename}.svg.
class TargetSilhouettes {
  /// Map of shape_id (from targets.json / target_racks.json) to asset filename.
  static const Map<String, String> _shapeIdToAsset = {
    'pepper_popper': 'assets/silhouettes/targets/pepper_popper.svg',
    // Registered for Phase 6 IPSC dispatch. The asset file
    // `assets/silhouettes/targets/ipsc.svg` is NOT yet on disk;
    // until the operator drops it in (and a `loadTargetPath('ipsc')`
    // call is added to `main.dart`'s boot preload), `cachedScaledPath`
    // returns null for `'ipsc'` and the realistic scene painter
    // falls back to the procedural IPSC drawing via `buildIpscPath`
    // in `_paintTarget`'s `case 'silhouette'` branch. The catalog
    // already carries `shape_id: 'ipsc'` on the 6 IPSC rows so the
    // swap is automatic once the SVG ships.
    'ipsc': 'assets/silhouettes/targets/ipsc.svg',
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

  /// Phase 11 Group A v2 — cache-warmup signal.
  ///
  /// Bumps every time a target SVG completes loading and lands in the
  /// path cache. Consumers that render an SVG-backed silhouette
  /// (`_RealisticScenePainter` via `TargetPlot.build`) subscribe to
  /// this notifier and reconstruct the painter on each bump, which
  /// fires `shouldRepaint` and forces the dispatch to re-call
  /// `cachedScaledPath` — by then the SVG is cached and the path
  /// resolves instead of falling through to the rect placeholder in
  /// `_drawSpecial`.
  ///
  /// Without this signal, the painter renders ONCE at preview build
  /// time, sees `_pathCache['pepper_popper'] == null` (preload still
  /// in flight), draws the rect placeholder, and never repaints
  /// when the cache eventually warms — leaving the user looking at
  /// rectangles forever (or at least until some unrelated repaint
  /// trigger fires, like a mode toggle).
  ///
  /// The int value is just a generation counter — listeners only
  /// care that it CHANGED, not what its value is.
  static final ValueNotifier<int> cacheGeneration = ValueNotifier<int>(0);

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
    // Phase 11 Group A v2 — wake up any painter that already rendered
    // a rect placeholder while this future was in flight.
    cacheGeneration.value++;
    return path;
  }

  static Future<Path> _loadAndParse(String assetPath) async {
    final svgContent = await rootBundle.loadString(assetPath);
    return extractAndCombinePaths(svgContent, assetPath);
  }

  /// Mirror of `AnimalSilhouettes.extractAndCombinePaths` (Phase 9
  /// Group C.3 brought parity). Handles five SVG authoring patterns:
  ///
  ///   * **A — Single solid silhouette path.** Most common (the new
  ///     simplified IPSC SVG, pepper_popper.svg). Combined path
  ///     returns the silhouette directly.
  ///   * **B — Inverted negative-space single-path.** One path's
  ///     `d` traces an outer canvas-cover and an inner silhouette
  ///     hole; non-zero winding from the path's combined geometry
  ///     produces the silhouette via `Path.combine(difference, ...)`.
  ///   * **C — Multi-subpath: canvas-cover + silhouette in one
  ///     `<path>`.** The old complex IPSC SVG pattern. Split the
  ///     `d` string into subpaths; return only the inner subpath.
  ///   * **D — Separate paths: white background + dark silhouette.**
  ///     White-fill filter drops the background path before combine.
  ///   * **E — Stroke-only outline path.** `fill="none"` (or empty
  ///     fill) plus a stroke attribute. Filtered out before combine
  ///     so outline-only paths don't add ghost geometry to the body.
  ///
  /// Public for tests.
  static Path extractAndCombinePaths(String svgContent, String assetPath) {
    final viewBox = _parseViewBox(svgContent);
    final paths = _parseAllPaths(svgContent);

    if (paths.isEmpty) {
      throw StateError('No <path d="..."/> found in $assetPath');
    }

    // Pattern E filter.
    final filledPaths =
        paths.where((p) => !_isStrokeOnly(p)).toList();
    final effectivePaths =
        filledPaths.isNotEmpty ? filledPaths : paths;

    // Pattern B + C — inverted-negative-space dispatch.
    if (_isInvertedNegativeSpaceSvg(effectivePaths, viewBox)) {
      final first = effectivePaths.first;
      final subpaths = _splitSubpaths(first.dString);

      if (subpaths.length >= 2) {
        final innerSubpaths = subpaths.where((s) {
          if (viewBox.width <= 0 || viewBox.height <= 0) return false;
          final coverX = s.bounds.width / viewBox.width;
          final coverY = s.bounds.height / viewBox.height;
          return coverX < 0.8 && coverY < 0.8;
        }).toList();

        if (innerSubpaths.isNotEmpty) {
          final result = Path();
          for (final s in innerSubpaths) {
            result.addPath(s.path, Offset.zero);
          }
          return result;
        }
      }

      final canvasRect = Path()..addRect(viewBox);
      return Path.combine(
        PathOperation.difference,
        canvasRect,
        first.path,
      );
    }

    // Pattern A + D — standard SVG with white-fill filter.
    final combined = Path();
    for (final p in effectivePaths) {
      if (_isWhiteFill(p.fillHex)) continue;
      combined.addPath(p.path, Offset.zero);
    }

    if (combined.getBounds().isEmpty) {
      final fallback = Path();
      for (final p in paths) {
        fallback.addPath(p.path, Offset.zero);
      }
      return fallback;
    }

    return combined;
  }

  /// Mirror of `AnimalSilhouettes._parseAllPaths`.
  static List<_ParsedSvgPath> _parseAllPaths(String svgContent) {
    final pathTagRe = RegExp(
      r'<path\b([^>]*)>',
      multiLine: true,
      dotAll: true,
    );
    final dAttrRe = RegExp(r'\bd\s*=\s*"([^"]+)"');
    final fillAttrRe = RegExp(r'\bfill\s*=\s*"([^"]+)"');
    final strokeAttrRe = RegExp(r'\bstroke\s*=\s*"([^"]+)"');

    final result = <_ParsedSvgPath>[];
    for (final match in pathTagRe.allMatches(svgContent)) {
      final attrs = match.group(1) ?? '';
      final dMatch = dAttrRe.firstMatch(attrs);
      if (dMatch == null) continue;
      final d = dMatch.group(1)!;
      final fillMatch = fillAttrRe.firstMatch(attrs);
      final fillHex = fillMatch?.group(1)?.toLowerCase();
      final strokeMatch = strokeAttrRe.firstMatch(attrs);
      final strokeHex = strokeMatch?.group(1)?.toLowerCase();

      Path? parsed;
      try {
        parsed = svg_strict.parseSvgPath(d);
      } catch (_) {
        try {
          parsed = parseSvgPathData(d);
        } catch (e) {
          debugPrint('target_silhouettes: skipped unparseable path: $e');
          continue;
        }
      }
      result.add(_ParsedSvgPath(parsed, fillHex, strokeHex, d));
    }
    return result;
  }

  /// Mirror of `AnimalSilhouettes._parseViewBox`.
  static Rect _parseViewBox(String svgContent) {
    final svgTagRe = RegExp(
      r'<svg\b([^>]*)>',
      multiLine: true,
      dotAll: true,
    );
    final viewBoxAttrRe = RegExp(r'\bviewBox\s*=\s*"([^"]+)"');
    final svgMatch = svgTagRe.firstMatch(svgContent);
    if (svgMatch == null) {
      return const Rect.fromLTWH(0, 0, 1024, 1024);
    }
    final viewBoxMatch =
        viewBoxAttrRe.firstMatch(svgMatch.group(1) ?? '');
    if (viewBoxMatch == null) {
      final widthRe = RegExp(r'\bwidth\s*=\s*"([\d.]+)');
      final heightRe = RegExp(r'\bheight\s*=\s*"([\d.]+)');
      final w = widthRe.firstMatch(svgMatch.group(1) ?? '');
      final h = heightRe.firstMatch(svgMatch.group(1) ?? '');
      if (w != null && h != null) {
        return Rect.fromLTWH(0, 0, double.parse(w.group(1)!),
            double.parse(h.group(1)!));
      }
      return const Rect.fromLTWH(0, 0, 1024, 1024);
    }
    final parts = viewBoxMatch
        .group(1)!
        .split(RegExp(r'[\s,]+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length != 4) {
      return const Rect.fromLTWH(0, 0, 1024, 1024);
    }
    return Rect.fromLTWH(
      double.parse(parts[0]),
      double.parse(parts[1]),
      double.parse(parts[2]),
      double.parse(parts[3]),
    );
  }

  /// Mirror of `AnimalSilhouettes._isWhiteFill`.
  static bool _isWhiteFill(String? fillHex) {
    if (fillHex == null) return false;
    final f = fillHex.trim().toLowerCase();
    if (f == 'white') return true;
    if (!f.startsWith('#')) return false;
    final hex = f.substring(1);
    if (hex == 'fff' || hex == 'ffffff' || hex == 'ffffffff') return true;
    if (RegExp(r'^[ef]{3}$').hasMatch(hex)) return true;
    if (RegExp(r'^[ef]{6}$').hasMatch(hex)) return true;
    if (RegExp(r'^[ef]{8}$').hasMatch(hex)) return true;
    return false;
  }

  /// Mirror of `AnimalSilhouettes._isInvertedNegativeSpaceSvg`.
  static bool _isInvertedNegativeSpaceSvg(
    List<_ParsedSvgPath> paths,
    Rect viewBox,
  ) {
    if (paths.isEmpty) return false;
    final first = paths.first;
    if (!_isWhiteFill(first.fillHex)) return false;
    if (viewBox.width <= 0 || viewBox.height <= 0) return false;
    final coverageX = first.bounds.width / viewBox.width;
    final coverageY = first.bounds.height / viewBox.height;
    return coverageX >= 0.9 && coverageY >= 0.9;
  }

  /// Mirror of `AnimalSilhouettes._isStrokeOnly`.
  static bool _isStrokeOnly(_ParsedSvgPath p) {
    final fill = p.fillHex;
    final fillEmpty = fill == null || fill.isEmpty || fill == 'none';
    final hasStroke = p.strokeHex != null &&
        p.strokeHex!.isNotEmpty &&
        p.strokeHex != 'none';
    return fillEmpty && hasStroke;
  }

  /// Mirror of `AnimalSilhouettes._splitSubpaths`.
  static List<({Path path, Rect bounds})> _splitSubpaths(String d) {
    final parts = d.split(RegExp(r'(?=[Mm])'));
    final out = <({Path path, Rect bounds})>[];
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      if (!trimmed.startsWith(RegExp(r'[Mm]'))) continue;
      try {
        final p = svg_strict.parseSvgPath(trimmed);
        out.add((path: p, bounds: p.getBounds()));
      } catch (_) {
        try {
          final p = parseSvgPathData(trimmed);
          out.add((path: p, bounds: p.getBounds()));
        } catch (e) {
          debugPrint('target_silhouettes: subpath skip: $e');
        }
      }
    }
    return out;
  }

  /// Synchronous cache-hit accessor for use from `CustomPainter.paint`.
  /// Returns the SVG path scaled to [bounds] when the source path is
  /// already in [_pathCache] (typically because `main.dart` preloaded
  /// it at app boot per Appendix M of the Range Day Realistic v2.3
  /// rewrite). Returns `null` when the cache is cold — callers should
  /// fall back to a procedural shape for that frame; the next repaint
  /// after preload completes will return the real path.
  ///
  /// Synchronous companion to [buildTargetPath]. Use the async variant
  /// from any non-paint codepath.
  ///
  /// [scaleFactor] (v38+) multiplies the natural fit-to-box scale —
  /// symmetric with `AnimalSilhouettes.cachedScaledPath`. Not used
  /// for IPSC / popper today (default 1.0) but plumbed for future
  /// catalog rows that might author oversized SVGs.
  static Path? cachedScaledPath(
    Rect bounds,
    String shapeId, {
    double scaleFactor = 1.0,
  }) {
    final source = _pathCache[shapeId];
    if (source == null) return null;
    return scalePathToBounds(source, bounds, scaleFactor: scaleFactor);
  }

  /// Scale to fit bounds while preserving aspect ratio; bottom-aligned.
  /// (Same algorithm as AnimalSilhouettes.scalePathToBounds.)
  ///
  /// [scaleFactor] (v38+) multiplies the uniform fit-to-box scale.
  /// At 1.0 (default) the silhouette stays inside the rect.
  static Path scalePathToBounds(
    Path source,
    Rect bounds, {
    double scaleFactor = 1.0,
  }) {
    final src = source.getBounds();
    if (src.width <= 0 || src.height <= 0) return source;

    final scaleX = bounds.width / src.width;
    final scaleY = bounds.height / src.height;
    final fitScale = scaleX < scaleY ? scaleX : scaleY;
    final scale = fitScale * scaleFactor;

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
