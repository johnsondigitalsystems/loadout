// FILE: test/photo_asset_directory_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// VFP Phase 4 Group B coverage for `PhotoAssetDirectory`
// (lib/services/photo_asset_directory.dart): the six category
// directory names (verbatim from VFP §10), create-on-first-use, the
// production `CdnResolver` (downloaded-file hit / miss / non-category
// path), per-category size, clear-one / clear-all, and the §4.18
// bundle-only guard no-op.
//
// Both platform-coupled concerns are injected seams so the suite is
// host-OS-independent:
//   * `baseDirProvider` → a per-test temp dir (no `path_provider`).
//   * `cacheSupported` → `() => true` to exercise FS logic on ANY
//     host (the real predicate is `Platform.isMacOS`-sensitive, so
//     without this seam these tests would no-op + fail on a macOS
//     CI/dev host), and `() => false` to assert the guard no-op.
//
// Flat `test/` — the plan's `test/services/...` path is
// stale-convention (D-8 class); this project has no `test/services/`.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// Creates + deletes a temp directory per test. No network, no
// path_provider, no real app-support dir.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/services/photo_asset_directory.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('passet_test_');
  });
  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  PhotoAssetDirectory dir({bool cacheSupported = true}) =>
      PhotoAssetDirectory(
        baseDirProvider: () async => tmp,
        cacheSupported: () => cacheSupported,
      );

  group('category directory names (verbatim VFP §10)', () {
    test('the six names', () {
      expect(
        PhotoAssetCategory.values.map((c) => c.dirName).toList(),
        const [
          'photo_backdrops',
          'photo_sprites',
          'photo_animals',
          'photo_iron_sights',
          'photo_effects',
          'photo_3d_models',
        ],
      );
    });
  });

  group('dirFor — create on first use', () {
    test('creates <base>/<dirName> recursively', () async {
      final d = await dir().dirFor(PhotoAssetCategory.backdrops);
      expect(d.existsSync(), isTrue);
      expect(d.path, '${tmp.path}/photo_backdrops');
    });
  });

  group('cdnResolver', () {
    test('returns bytes for an existing downloaded file', () async {
      final pad = dir();
      final bd = await pad.dirFor(PhotoAssetCategory.sprites);
      await File('${bd.path}/sky/100yd.bin')
          .create(recursive: true);
      await File('${bd.path}/sky/100yd.bin')
          .writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

      final bytes =
          await pad.cdnResolver('photo_sprites/sky/100yd.bin');
      expect(bytes, isNotNull);
      expect(bytes, Uint8List.fromList([1, 2, 3, 4]));
    });

    test('null when the file is not downloaded (→ bundle fallback)',
        () async {
      final bytes = await dir()
          .cdnResolver('photo_sprites/sky/missing.bin');
      expect(bytes, isNull);
    });

    test('null for a path that matches no category', () async {
      expect(await dir().cdnResolver('not_a_category/x.bin'), isNull);
      expect(await dir().cdnResolver(''), isNull);
    });
  });

  group('categorySizeBytes', () {
    test('sums file sizes; 0 for empty/missing', () async {
      final pad = dir();
      expect(
        await pad.categorySizeBytes(PhotoAssetCategory.effects),
        0,
      );
      final ed = await pad.dirFor(PhotoAssetCategory.effects);
      await File('${ed.path}/a.bin')
          .writeAsBytes(Uint8List(10));
      await File('${ed.path}/sub/b.bin')
          .create(recursive: true);
      await File('${ed.path}/sub/b.bin')
          .writeAsBytes(Uint8List(25));
      expect(
        await pad.categorySizeBytes(PhotoAssetCategory.effects),
        35,
      );
    });
  });

  group('clear', () {
    test('clearCategory removes that category only', () async {
      final pad = dir();
      final a = await pad.dirFor(PhotoAssetCategory.animals);
      final b = await pad.dirFor(PhotoAssetCategory.backdrops);
      await File('${a.path}/x.bin').writeAsBytes(Uint8List(50));
      await File('${b.path}/y.bin').writeAsBytes(Uint8List(50));

      await pad.clearCategory(PhotoAssetCategory.animals);

      expect(
          await pad.categorySizeBytes(PhotoAssetCategory.animals), 0);
      expect(
          await pad.categorySizeBytes(PhotoAssetCategory.backdrops),
          50,
          reason: 'other categories untouched');
    });

    test('clearAll empties every category', () async {
      final pad = dir();
      for (final c in PhotoAssetCategory.values) {
        final cd = await pad.dirFor(c);
        await File('${cd.path}/f.bin').writeAsBytes(Uint8List(8));
      }
      await pad.clearAll();
      for (final c in PhotoAssetCategory.values) {
        expect(await pad.categorySizeBytes(c), 0, reason: c.name);
      }
    });
  });

  group('§4.18 bundle-only guard (cacheSupported == false)', () {
    test('resolver → null, size → 0, clear → no-op (files survive)',
        () async {
      // Pre-create a real cached file via a cache-ON instance.
      final on = dir();
      final sd = await on.dirFor(PhotoAssetCategory.sprites);
      await File('${sd.path}/keep.bin').writeAsBytes(Uint8List(99));

      final off = dir(cacheSupported: false);
      expect(
          await off.cdnResolver('photo_sprites/keep.bin'), isNull);
      expect(
          await off.categorySizeBytes(PhotoAssetCategory.sprites), 0);
      await off.clearCategory(PhotoAssetCategory.sprites);
      await off.clearAll();
      // The guard made clear a no-op — the file is still there.
      expect(File('${sd.path}/keep.bin').existsSync(), isTrue);
    });
  });

  group('photoAssetFilesystemCacheSupported (platform — smoke only)',
      () {
    test('is a stable bool (value is a platform/integration concern)',
        () {
      final a = photoAssetFilesystemCacheSupported;
      expect(a, isA<bool>());
      expect(a, photoAssetFilesystemCacheSupported);
    });
  });
}
