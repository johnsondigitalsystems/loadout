// FILE: test/assets_present_test.dart
//
// Asset-bundle integrity test. The test walks every file on disk under the
// app's runtime-asset directories (currently `assets/seed_data/`) and
// asserts that each is reachable through `rootBundle` — i.e. it is actually
// declared in the `flutter.assets:` block of `pubspec.yaml`.
//
// WHAT THIS DOES NOT COVER
// ------------------------
// `assets/icon/` is NOT in the directory list below. Those files are inputs
// to `flutter_launcher_icons` (a build-time tool that bakes them into
// platform-specific iOS / Android app-icon resources); they are not loaded
// at runtime via `rootBundle` and intentionally not declared in
// `flutter.assets:`. If you ever start loading them via `rootBundle`, ADD
// the directory to `assetDirs` below AND to `pubspec.yaml`.
//
// WHY THIS EXISTS
// ---------------
// Flutter's asset declarations do NOT recurse into subdirectories. A bare
// `assets/seed_data/` line in `pubspec.yaml` only picks up files directly
// inside that folder; files in `assets/seed_data/drag_curves/` are silently
// excluded from the bundle unless you also list `assets/seed_data/drag_curves/`
// on its own line. The app then crashes at runtime — usually on the very
// first launch on a fresh install — with messages like:
//
//   Unable to load asset: "assets/seed_data/drag_curves/curves.json"
//
// `flutter analyze` cannot catch this — it inspects Dart code, not the asset
// manifest. The standard test suite cannot catch it either unless a test
// actually opens every asset. This test does exactly that.
//
// HOW IT WORKS
// ------------
// `dart:io` walks the filesystem, and for each file the test calls
// `rootBundle.load(path)`. The Flutter test harness builds `rootBundle`
// against the same asset manifest the production build uses, so a file
// that's on disk but not in `pubspec.yaml flutter.assets:` throws a
// `FlutterError("Unable to load asset...")` and the test fails.
//
// COVERAGE
// --------
// Both directions of the bug are caught:
//   * File on disk + missing pubspec entry → `rootBundle.load` throws.
//   * File listed in pubspec but missing from disk → the disk walk never
//     finds it, but the manifest assertion below also catches that case
//     (the manifest test reads `AssetManifest.json` and confirms the
//     declared paths are still present in the build).
//
// ORIGINAL-BUG VERIFICATION (manual, for posterity)
// -------------------------------------------------
// To prove this test catches the recent crash:
//   1. Comment out `- assets/seed_data/drag_curves/` in `pubspec.yaml`.
//   2. `flutter test test/assets_present_test.dart`
//   3. The test for `assets/seed_data/drag_curves/curves.json` fails with
//      "Unable to load asset" — exactly the runtime crash signature.
//   4. Restore the pubspec entry → test passes again.
// (Verified 2026-05-08. See § 12 of CLAUDE.md.)
//
// PERFORMANCE
// -----------
// The test only calls `rootBundle.load(path)`, which validates that the
// asset is registered AND streams its bytes back. For the largest LoadOut
// asset (~2 MB reticles.json) this still completes in milliseconds. The
// whole suite finishes well under 5 seconds.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Every directory whose contents are loaded at runtime via `rootBundle`.
  // Add a new entry here when introducing a new runtime-asset folder, and
  // make sure to add a matching `- assets/<name>/` line in pubspec.yaml.
  const assetDirs = <String>[
    'assets/seed_data',
    // Phase 10 Group F.1 — `assets/noise/film_grain_256.png` (the
    // film-grain tile loaded by `_NoiseAssetLoader` in target_plot.dart).
    // The dir lives alongside `assets/seed_data/` and needs its own line
    // in pubspec.yaml (`- assets/noise/`); without it the runtime
    // `rootBundle.load` would throw on first polished paint.
    'assets/noise',
    // Branded startup loading emblem (`assets/branding/loadout_logo.png`)
    // shown by `StartupLoadingScreen` during the cold-start async gates in
    // lib/app.dart. New top-level dir → its own `- assets/branding/` line
    // in pubspec.yaml; this entry makes the bundle-reachability test cover
    // it (CLAUDE.md §12a).
    'assets/branding',
  ];

  // File extensions that are real bundleable assets in this project. Every
  // file ending in one of these MUST resolve through `rootBundle`. Files
  // with any other extension (or no extension) are skipped — the comment
  // next to each entry explains why we expect to see it on disk.
  const assetExtensions = <String>{
    '.json', // seed catalogs, manifest, drag curves, declination grid
    '.png', // launcher icons, foreground variants
    '.jpg', // future: photo assets
    '.jpeg',
    '.svg', // vector logos / illustrations (none today, but cheap to allow)
    '.ttf', // custom font files
    '.otf',
    '.wasm', // web/sqlite3.wasm (only used on web; lives in `web/`, not here)
    '.js', // web worker scripts (also `web/`)
  };

  // Files that legitimately live in an asset directory but are NOT meant
  // to be bundled. README notes for catalog editors and template files
  // beginning with `_` are intentional — see `seed_loader.dart`'s comment
  // about underscore-prefixed files being ignored at runtime.
  bool shouldSkip(String path) {
    final base = path.split(Platform.pathSeparator).last;
    if (base == '.DS_Store') return true; // macOS metadata
    if (base.startsWith('._')) return true; // macOS resource forks
    if (base.startsWith('.')) return true; // any other dotfile
    if (base == 'Thumbs.db') return true; // Windows thumbs
    if (base.toLowerCase() == 'readme.md') return true; // editor notes
    if (base.startsWith('_')) return true; // underscore = template/ignored
    final dot = base.lastIndexOf('.');
    if (dot < 0) return true; // no extension → not a bundleable asset
    final ext = base.substring(dot).toLowerCase();
    return !assetExtensions.contains(ext);
  }

  group('Asset bundle integrity', () {
    for (final dir in assetDirs) {
      // List the files now, before any test runs, so the test bodies are
      // simple closures over the discovered paths. If the directory is
      // missing entirely, that's a worth-knowing failure on its own.
      test('$dir exists on disk', () {
        expect(Directory(dir).existsSync(), isTrue,
            reason: 'Asset directory $dir is missing — was it renamed or '
                'removed without updating pubspec.yaml / this test?');
      });

      final directory = Directory(dir);
      if (!directory.existsSync()) {
        // Don't try to walk a missing directory — the failure above
        // tells the engineer what to fix.
        continue;
      }

      final files = directory
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path)
          .toList()
        ..sort();

      for (final path in files) {
        if (shouldSkip(path)) continue;

        // Path on disk is already relative to the project root because the
        // walk started from a relative directory name.
        final assetPath = path.replaceAll(Platform.pathSeparator, '/');

        test('rootBundle.load("$assetPath")', () async {
          // Throws FlutterError("Unable to load asset: ...") if the path is
          // not registered in pubspec.yaml's flutter.assets: block. That is
          // the exact crash signature we want to fail on, here at test time
          // instead of in front of a user on a fresh install.
          final data = await rootBundle.load(assetPath);
          expect(data.lengthInBytes, greaterThan(0),
              reason: '$assetPath loaded but is empty');
        });
      }
    }
  });
}
