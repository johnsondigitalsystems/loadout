// FILE: test/asset_updater_allowlist_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// FIRM regression test for the seed-catalog live-update path,
// migrated verbatim from the former `seed_updater_allowlist_test.dart`
// (VFP Phase 4 Group C — `SeedUpdater` → `AssetUpdater(
// seedCatalogConfig)`). It guards TWO things:
//
//   1. (preserved verbatim) the bundled `assets/seed_data/
//      manifest.json` declares only keys `allowedKeys` recognises,
//      every `allowedKeys` entry has a manifest row, and every
//      manifest filename resolves through `rootBundle`.
//   2. (added — §3 Task 2 / §5 backward-compat constraints) the
//      `seedCatalogConfig` reproduces the former `SeedUpdater`
//      behaviour BIT-FOR-BIT: the `seed_version_` /
//      `seed_needs_reseed_` SharedPrefs prefixes, the
//      `seed_data/manifest.json` + `seed_data/<file>` Storage paths,
//      the COMPLETE filename security boundary (not a bare
//      `.endsWith('.json')`), and the `_validateShape` content
//      contract. Drift in any of these orphans field-installed
//      caches or weakens a launch-critical security boundary.
//
// ============================================================================
// WHY IT EXISTS
// ============================================================================
// A missed allowlist key, a changed SharedPrefs prefix, a moved
// storage path, or a softened filename guard are all
// silent-until-a-user-reports-it failures in the launch-critical
// catalog hot-fix path. CI catches them. This test stays FIRM — the
// seed assertions must pass verbatim against any future refactor.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Reads the bundled manifest from the asset bundle; exercises
// pure config predicates.

import 'dart:convert';

import 'package:cryptography/cryptography.dart' show Sha256;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/services/asset_updater_config.dart';
import 'package:loadout/services/asset_updater_configs.dart';
import 'package:loadout/services/photo_asset_directory.dart'
    show PhotoAssetCategory;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // -------------------------------------------------------------------------
  // Preserved verbatim from seed_updater_allowlist_test.dart — only the
  // `allowedKeys` source moved (now asset_updater_configs.dart) and the
  // prose says AssetUpdater. Assertions UNCHANGED.
  // -------------------------------------------------------------------------
  group('AssetUpdater(seedCatalogConfig) allowlist <-> bundled manifest',
      () {
    test('every manifest key is in allowedKeys', () async {
      final raw =
          await rootBundle.loadString('assets/seed_data/manifest.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final files = decoded['files'] as Map<String, dynamic>;
      final missing = <String>[];
      for (final key in files.keys) {
        if (!allowedKeys.contains(key)) {
          missing.add(key);
        }
      }
      expect(missing, isEmpty,
          reason:
              'These manifest keys are not in `allowedKeys` in '
              'lib/services/asset_updater_configs.dart — the runtime '
              'would silently drop their updates:\n  '
              '${missing.join("\n  ")}');
    });

    test('every allowedKeys entry is in the bundled manifest', () async {
      final raw =
          await rootBundle.loadString('assets/seed_data/manifest.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final files =
          (decoded['files'] as Map<String, dynamic>).keys.toSet();
      final orphans = <String>[];
      for (final key in allowedKeys) {
        if (!files.contains(key)) {
          orphans.add(key);
        }
      }
      expect(orphans, isEmpty,
          reason:
              'These `allowedKeys` entries have no matching row in '
              'assets/seed_data/manifest.json — either add the file '
              'and bump the manifest, or remove the orphan from '
              '`allowedKeys`:\n  ${orphans.join("\n  ")}');
    });

    test('every manifest filename points at a file that exists in the bundle',
        () async {
      final raw =
          await rootBundle.loadString('assets/seed_data/manifest.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final files = decoded['files'] as Map<String, dynamic>;
      final missing = <String>[];
      for (final entry in files.entries) {
        final spec = entry.value as Map<String, dynamic>;
        final filename = spec['filename'] as String;
        try {
          await rootBundle.load('assets/seed_data/$filename');
        } catch (_) {
          missing.add('${entry.key} → $filename');
        }
      }
      expect(missing, isEmpty,
          reason:
              'These manifest entries point at files that are not '
              'reachable through rootBundle. Either the file is '
              'missing from disk, or pubspec.yaml is missing the '
              "asset declaration (CLAUDE.md § 12a):\n"
              '  ${missing.join("\n  ")}');
    });
  });

  // -------------------------------------------------------------------------
  // ADDED — bit-for-bit backward-compat constants (§3 Task 2 / §5 risks).
  // These pin the exact values whose drift would orphan field-installed
  // caches or weaken the launch-critical security boundary.
  // -------------------------------------------------------------------------
  group('seedCatalogConfig — bit-for-bit former-SeedUpdater contract', () {
    test('SharedPrefs prefixes are exactly the legacy values', () {
      expect(seedVersionPrefix, 'seed_version_');
      expect(seedNeedsReseedPrefix, 'seed_needs_reseed_');
      expect(seedCatalogConfig.versionTrackerPrefix, 'seed_version_');
    });

    test('Storage paths are the real live bucket layout (§0.5 C-a)', () {
      expect(seedCatalogConfig.manifestStoragePath,
          'seed_data/manifest.json');
      expect(seedCatalogConfig.storagePathForFile('cartridges.json'),
          'seed_data/cartridges.json');
      expect(seedCatalogConfig.storagePathForFile('components/chassis.json'),
          'seed_data/components/chassis.json');
    });

    test('write strategy + size cap preserved (§0.5 C-f)', () {
      expect(seedCatalogConfig.writeStrategy, WriteStrategy.text);
      expect(seedCatalogConfig.maxFileBytes, 8 * 1024 * 1024);
      expect(seedCatalogConfig.contentDecoder, isNotNull);
    });

    test('filename validator is the FULL guard, not just .json (§0.5 C-b)',
        () {
      final f = seedCatalogConfig.filenameValidator;
      // Accept: simple basename + one subdir level.
      expect(f('cartridges.json'), isTrue);
      expect(f('components/chassis.json'), isTrue);
      // Reject: the security boundary the spec one-liner would lose.
      expect(f('evil.txt'), isFalse, reason: 'non-.json');
      expect(f('..//etc/passwd.json'), isFalse, reason: 'traversal');
      expect(f('../secrets.json'), isFalse, reason: 'parent-traversal');
      expect(f('a/b/c.json'), isFalse, reason: 'depth > 1 subdir');
      expect(f('\\windows\\x.json'), isFalse, reason: 'backslash');
      expect(f('/abs/x.json'), isFalse, reason: 'absolute');
      expect(f('.hidden.json'), isFalse, reason: 'hidden');
      expect(f('a b.json'), isFalse, reason: 'whitespace metachar');
      expect(f('x;rm -rf.json'), isFalse, reason: 'shell metachar');
      expect(f(''), isFalse);
    });

    test('content validator preserves _validateShape (both shapes)', () {
      final v = seedCatalogConfig.contentValidator;
      Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));
      const flat = AssetEntry(
          key: 'cartridges', version: 2, filename: 'cartridges.json');
      const mfr =
          AssetEntry(key: 'powders', version: 2, filename: 'powders.json');
      const comp = AssetEntry(
          key: 'firearm_components_barrels',
          version: 2,
          filename: 'components/barrels.json');

      // Flat-array keys: top-level must be a List.
      expect(() => v(b('[]'), flat), returnsNormally);
      expect(() => v(b('[{"a":1}]'), flat), returnsNormally);
      expect(() => v(b('{}'), flat),
          throwsA(isA<AssetValidationException>()));
      // firearm_components_* are flat-array too.
      expect(() => v(b('[]'), comp), returnsNormally);
      expect(() => v(b('{}'), comp),
          throwsA(isA<AssetValidationException>()));
      // Manufacturer-shape keys: {manufacturers:[...]}.
      expect(() => v(b('{"manufacturers":[]}'), mfr), returnsNormally);
      expect(() => v(b('[]'), mfr),
          throwsA(isA<AssetValidationException>()));
      expect(() => v(b('{"x":1}'), mfr),
          throwsA(isA<AssetValidationException>()));
      // Garbage JSON → rejected (not a partial overwrite).
      expect(() => v(b('not json'), flat),
          throwsA(isA<AssetValidationException>()));
    });

    test('post-apply hook exists (the §0.5 C-c re-seed trigger)', () {
      // The hook is what sets seed_needs_reseed_<key>; its absence
      // would silently regress the launch-critical re-seed path.
      expect(seedCatalogConfig.onAssetApplied, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // ADDED — Group D photo-asset configuration contract. Predicate-level
  // (like the seed bit-for-bit group); the actual appSupport filesystem
  // write is exercised by the mock-Firebase flow suite
  // (asset_updater_photo_test.dart) with an injected temp dir, the same
  // split the seed bit-for-bit test uses (asserts paths, not the real
  // _seedRoot FS call).
  // -------------------------------------------------------------------------
  group('photoAssetConfig — Group D photo-asset contract', () {
    test('allowlist is exactly the 6 PhotoAssetCategory dir names (D-a)',
        () {
      final fromEnum = <String>{
        for (final c in PhotoAssetCategory.values) c.dirName,
      };
      // Derived single source of truth — allowlist can never drift
      // from the on-disk directory layout.
      expect(photoAssetConfig.allowlist, fromEnum);
      expect(photoAssetConfig.allowlist, kPhotoAssetCategories);
      expect(photoAssetConfig.allowlist, <String>{
        'photo_backdrops',
        'photo_sprites',
        'photo_animals',
        'photo_iron_sights',
        'photo_effects',
        'photo_3d_models',
      });
    });

    test('SharedPrefs prefix + real Storage paths (D-e)', () {
      expect(
          photoAssetConfig.versionTrackerPrefix, 'photo_asset_version_');
      expect(photoAssetVersionPrefix, 'photo_asset_version_');
      expect(photoAssetConfig.manifestStoragePath,
          'photo_assets/manifest.json');
      expect(
        photoAssetConfig.storagePathForFile('photo_backdrops/dawn.webp'),
        'photo_assets/photo_backdrops/dawn.webp',
      );
    });

    test('binary write strategy + 64 MB cap + no decoder (D-f)', () {
      expect(photoAssetConfig.writeStrategy, WriteStrategy.binary);
      expect(photoAssetConfig.maxFileBytes, 64 * 1024 * 1024);
      expect(photoAssetConfig.contentDecoder, isNull);
      // The §0.5 D-c PhotoAssetLoader cache-drop hook must exist.
      expect(photoAssetConfig.onAssetApplied, isNotNull);
    });

    test('filename validator is the FULL guard + category + ext (D-b)',
        () {
      final f = photoAssetConfig.filenameValidator;
      // Accept: every allowed extension; nesting deeper than seed's
      // 2-level cap is allowed for photo subtrees.
      expect(f('photo_backdrops/range_dawn.webp'), isTrue);
      expect(f('photo_sprites/tree/oak_01.png'), isTrue);
      expect(f('photo_animals/whitetail.ktx2'), isTrue);
      expect(f('photo_3d_models/popper.glb'), isTrue);
      expect(f('photo_effects/heat_shimmer.jpg'), isTrue);
      expect(f('photo_iron_sights/post.jpeg'), isTrue);
      expect(f('photo_backdrops/scene.gltf'), isTrue);
      // Reject — the security boundary must NOT soften (C-b carried
      // into the binary path).
      expect(f('photo_backdrops/evil.txt'), isFalse, reason: 'non-asset');
      expect(f('not_a_category/x.png'), isFalse, reason: 'bad category');
      expect(f('range_dawn.webp'), isFalse, reason: 'no category prefix');
      expect(f('photo_backdrops/../secrets.png'), isFalse,
          reason: 'parent traversal');
      expect(f('photo_backdrops/./x.png'), isFalse, reason: 'dot seg');
      expect(f('photo_backdrops/.hidden.png'), isFalse, reason: 'hidden');
      expect(f('/photo_backdrops/x.png'), isFalse, reason: 'absolute');
      expect(f(r'photo_backdrops\x.png'), isFalse, reason: 'backslash');
      expect(f('photo_backdrops/a b.png'), isFalse, reason: 'whitespace');
      expect(f('photo_backdrops/x;rm.png'), isFalse, reason: 'metachar');
      expect(f('photo_backdrops/'), isFalse, reason: 'empty basename');
      expect(f(''), isFalse);
    });

    test('content validator: mandatory SHA-256, async (D-d)', () async {
      final v = photoAssetConfig.contentValidator;
      final bytes = Uint8List.fromList(utf8.encode('photo-payload'));
      final digest = await Sha256().hash(bytes);
      final hex = digest.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      // contentValidator is FutureOr<void> (D-d) — coerce to Future.
      Future<void> run(Uint8List b, AssetEntry e) async => v(b, e);

      // Correct digest → passes (no exception).
      await expectLater(
        run(
          bytes,
          AssetEntry(
            key: 'photo_backdrops',
            version: 2,
            filename: 'photo_backdrops/x.webp',
            expectedSha256: hex,
          ),
        ),
        completes,
      );
      // Wrong digest → rejected, local copy kept.
      await expectLater(
        run(
          bytes,
          const AssetEntry(
            key: 'photo_backdrops',
            version: 2,
            filename: 'photo_backdrops/x.webp',
            expectedSha256: 'deadbeefdeadbeef',
          ),
        ),
        throwsA(isA<AssetValidationException>()),
      );
      // Missing digest → rejected (mandatory for binary, CLAUDE §28).
      await expectLater(
        run(
          bytes,
          const AssetEntry(
            key: 'photo_backdrops',
            version: 2,
            filename: 'photo_backdrops/x.webp',
          ),
        ),
        throwsA(isA<AssetValidationException>()),
      );
    });
  });
}
