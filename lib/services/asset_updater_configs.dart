// FILE: lib/services/asset_updater_configs.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// The concrete [AssetUpdaterConfig] instances + the relocated public
// constants that other code imports. VFP Phase 4 Groups C+D ship TWO:
//
//   * `seedCatalogConfig` (Group C) — reproduces the entire former
//     `SeedUpdater` behaviour BIT-FOR-BIT (same manifest path, same
//     allowlist, same full filename security boundary, same
//     `_validateShape`, same `<docs>/seed_data/` storage root, same
//     `seed_version_` prefix, same 8 MB cap, AND the
//     `seed_needs_reseed_<key>=true` post-apply trigger that
//     `seed_loader.dart` reads to perform the deferred DB re-seed).
//
//   * `photoAssetConfig` (Group D) — the binary photo/3D-asset
//     live-update path the Scenic/Photographic tiers (VFP Phase 6+)
//     consume. Allowlist = the six `PhotoAssetCategory` dir names
//     (Group B); content validation is mandatory SHA-256 vs the
//     manifest digest; writes land at `<appSupport>/<category>/<sub>`
//     (byte-identical to where `PhotoAssetDirectory.cdnResolver`
//     reads); the post-apply hook drops the `PhotoAssetLoader`
//     decode cache so an update applied this launch is never served
//     stale.
//
// The public consts `allowedKeys`, `seedVersionPrefix`,
// `seedNeedsReseedPrefix` are RELOCATED here verbatim from the
// deleted `seed_updater.dart` so existing importers
// (`seed_loader.dart`, the regression test) keep the SAME VALUES —
// only the import path moves (value-preserving relocation is
// behaviourally inert; the §412 risk is about changing the value,
// which we do not).
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * `allowedKeys` MUST stay the exact set the bundled manifest
//     uses — `asset_updater_allowlist_test.dart` asserts the
//     bundled manifest's keys are a subset. No add/remove here.
//   * `_isSafeSeedFilename` is the COMPLETE former
//     `_isSafeManifestFilename` (path-traversal / backslash /
//     leading-slash / depth / hidden / shell-metachar / `.json`) —
//     §0.5 C-b: NOT a bare `.endsWith('.json')`. The regression
//     test pins this boundary; it must not soften.
//   * `seedCatalogConfig.storageRootProvider` ignores its `key`
//     arg and returns the ONE shared `<docs>/seed_data` dir
//     (SeedUpdater used a single dir for every key — preserved).
//     The photo config (Group D) is per-category instead.
//   * `manifestStoragePath` = `seed_data/manifest.json` and
//     `storagePathForFile` = `seed_data/<filename>` — the real
//     live bucket layout (CLAUDE.md §28), §0.5 C-a (NOT the spec's
//     illustrative `manifests/seed.json`).
//
// Group D §0.5 reconciliations (spec illustrative code vs the real
// Group A/B contracts — resolved by following the spec PRINCIPLE
// over its EXAMPLE, the same discipline as C-a..C-f; surfaced for
// operator ratification in the Group D halt-report):
//   * D-a: `kPhotoAssetCategories` is DERIVED from Group B's
//     `PhotoAssetCategory` enum, not a standalone const. The spec's
//     standalone const would duplicate the enum and risk drift; one
//     source of truth (the photo analogue of `allowedKeys`). The
//     spec's "grep 6 photo_* literals in this file" check therefore
//     finds them via the enum, not literals here — deliberate.
//   * D-b/contract: the photo manifest `filename` is
//     `<categoryDir>/<sub>` (the exact `relativePath` shape Group A's
//     `PhotoAssetLoader.load` + Group B's `PhotoAssetDirectory`
//     already expect). `storageRootProvider` returns the appSupport
//     BASE (key ignored, like `_seedRoot`), so AssetUpdater writes
//     `<appSupport>/<categoryDir>/<sub>` — byte-identical to the
//     cdnResolver read path. `_isSafePhotoFilename` keeps the FULL
//     seed-grade hardening (NOT softened — C-b discipline), plus a
//     required known-category first segment and a photo/3D extension.
//   * D-c: Group A's loader invalidates BY CONSTRUCTION (version-
//     keyed cache). The spec's callback/stream subscription is
//     superseded; `onAssetApplied` calls the existing public
//     `PhotoAssetLoader.clearCache()` (belt-and-suspenders for an
//     in-session update) — no new pub/sub infra.
//   * D-d: SHA-256 via `package:cryptography` (async; `crypto` is
//     NOT a dep — C-e). `contentValidator` is `FutureOr<void>`;
//     seed stays sync-throwing (firm test verbatim).
//   * D-e: photo bucket paths are `photo_assets/manifest.json` /
//     `photo_assets/<category>/<sub>` — greenfield (photo assets are
//     not yet in the live bucket), aligned to the §28 `seed_data/`
//     convention rather than the spec's illustrative
//     `manifests/photo_assets.json`.
//   * D-f: production firing of `AssetUpdater(photoAssetConfig)` +
//     its web/macOS bundle-only guard is NOT in Group D scope (spec
//     §4 is config + SHA-256 + cache hook + tests). Photo assets are
//     authored Phase 6+; firing now would just hit a non-existent
//     manifest (silent `object-not-found`). Wiring + guard land with
//     Phase 6.
//   * D-g: no mock library exists (no mocktail/mockito/
//     firebase_storage_mocks) and Firebase plugin classes are not
//     subclassable, so the Group D flow test uses hand-rolled
//     `implements`+`noSuchMethod` fakes against the EXISTING
//     `FirebaseStorage? storage` seam — zero production change, the
//     launch-critical seed path is untouched.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   * lib/main.dart — `AssetUpdater(config: seedCatalogConfig)`
//     (the `photoAssetConfig` firing is Phase 6+, D-f).
//   * lib/database/seed_loader.dart — `show seedNeedsReseedPrefix`.
//   * lib/services/photo_asset_directory.dart — `PhotoAssetCategory`
//     (the derived `kPhotoAssetCategories` allowlist source).
//   * lib/services/photo_asset_loader.dart — `PhotoAssetLoader`
//     (the post-apply decode-cache drop).
//   * test/asset_updater_allowlist_test.dart +
//     test/asset_updater_photo_test.dart.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
//   * `seedCatalogConfig.storageRootProvider` creates
//     `<applicationDocumentsDirectory>/seed_data/` if missing
//     (exactly as the former `_ensureSeedDataDir`).
//   * `seedCatalogConfig.onAssetApplied` writes
//     `seed_needs_reseed_<key>` to SharedPreferences.
//   * `photoAssetConfig.storageRootProvider` resolves
//     `<applicationSupportDirectory>` (the per-category subdir is
//     created by `AssetUpdater._writeAtomic`).
//   * `photoAssetConfig.contentValidator` computes a SHA-256 over
//     the downloaded bytes (`package:cryptography`).
//   * `photoAssetConfig.onAssetApplied` calls
//     `PhotoAssetLoader.instance.clearCache()` (disposes cached
//     `ui.Image`s).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show Sha256;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'asset_updater_config.dart';
import 'photo_asset_directory.dart' show PhotoAssetCategory;
import 'photo_asset_loader.dart' show PhotoAssetLoader;

// ---------------------------------------------------------------------------
// Relocated public constants (verbatim values from the deleted
// seed_updater.dart — only the home moves; values are preserved).
// ---------------------------------------------------------------------------

/// SharedPreferences key prefix for per-file seed version tracking
/// (e.g. `seed_version_cartridges`). MUST stay `'seed_version_'` —
/// field-installed apps key off this; drift orphans tracking.
const String seedVersionPrefix = 'seed_version_';

/// SharedPreferences key prefix for the deferred-re-seed flag
/// (e.g. `seed_needs_reseed_cartridges`). Set true on a successful
/// download; `SeedLoader` reads + clears it on the next launch.
const String seedNeedsReseedPrefix = 'seed_needs_reseed_';

/// Logical manifest keys recognised for the seed catalog. Anything
/// outside this set is ignored — the load-bearing security boundary.
/// Every entry lines up with a `seed_loader.dart` reseed branch.
/// `asset_updater_allowlist_test.dart` asserts the bundled
/// manifest's keys are a subset of this. VERBATIM from the former
/// `SeedUpdater.allowedKeys` — no additions/removals in the refactor.
const Set<String> allowedKeys = <String>{
  // Bundled-since-v1 reference tables.
  'cartridges',
  'powders',
  'bullets',
  'primers',
  'brass',
  'firearms',
  'firearm_parts',
  // 'optics' removed in v2.3 (merged into scopes.json).
  // v8 onwards.
  'targets',
  'reticles',
  // v12 — measured drag curves.
  'drag_curves',
  // v14 — factory loads supplement.
  'factory_loads',
  // v19 — target racks reference catalog.
  'target_racks',
  // v22 — verified scope + reticle catalog (v2.3 merged).
  'scopes_v2',
  'scope_reticle_options',
  // v23 — curated manufactured-ammo catalog.
  'manufactured_ammo',
  // v33 — custom-build component catalogs (one file per kind).
  'firearm_components_chassis',
  'firearm_components_barrels',
  'firearm_components_triggers',
  'firearm_components_buttstocks',
  'firearm_components_muzzle_brakes',
  'firearm_components_suppressors',
  'firearm_components_bipods',
  // v41 — recipe templates seeded reference table.
  'recipe_templates',
  // v42 — recipe Status + Use Case seeded reference tables.
  'recipe_statuses',
  'recipe_use_cases',
};

/// Manifest keys whose payload is a flat JSON array (vs the legacy
/// `{manufacturers:[...]}` shape). VERBATIM from the former
/// `SeedUpdater._flatArrayKeys`.
const Set<String> _flatArrayKeys = <String>{
  'cartridges',
  'targets',
  'reticles',
  'drag_curves',
  'factory_loads',
  'target_racks',
  'scopes_v2',
  'reticles_v2',
  'scope_reticle_options',
  'manufactured_ammo',
};

// ---------------------------------------------------------------------------
// seedCatalogConfig — bit-for-bit former SeedUpdater behaviour.
// ---------------------------------------------------------------------------

/// COMPLETE former `_isSafeManifestFilename` (§0.5 C-b — NOT a bare
/// extension check). Allows simple basenames + one subdirectory
/// level; rejects backslashes, leading slash, `..`/`.`, hidden
/// files, deeper nesting, shell metacharacters, non-`.json`.
bool _isSafeSeedFilename(String filename) {
  if (filename.isEmpty) return false;
  if (filename.contains('\\')) return false;
  if (filename.startsWith('/')) return false;
  if (!filename.endsWith('.json')) return false;
  final parts = filename.split('/');
  if (parts.length > 2) return false;
  for (final part in parts) {
    if (part.isEmpty) return false;
    if (part == '.' || part == '..') return false;
    if (part.startsWith('.')) return false;
    if (part.contains(RegExp(r'[\s\x00\$`;<>]'))) return false;
  }
  return true;
}

/// Former `_validateShape`, as a throwing `contentValidator`. Decodes
/// the bytes as UTF-8 JSON and asserts the top-level structure for
/// `entry.key`. Throws [AssetValidationException] on mismatch (the
/// updater then keeps the local copy — never a partial overwrite).
void _validateSeedShape(List<int> bytes, AssetEntry entry) {
  final Object? decoded;
  try {
    decoded = json.decode(utf8.decode(bytes));
  } on FormatException catch (e) {
    throw AssetValidationException('${entry.filename}: bad JSON ($e)');
  }
  if (_flatArrayKeys.contains(entry.key) ||
      entry.key.startsWith('firearm_components_')) {
    if (decoded is! List) {
      throw AssetValidationException(
          '${entry.filename}: expected a top-level JSON array');
    }
    return;
  }
  if (decoded is! Map<String, dynamic> || decoded['manufacturers'] is! List) {
    throw AssetValidationException(
        '${entry.filename}: expected {manufacturers:[...]}');
  }
}

/// Ensures `<applicationDocumentsDirectory>/seed_data/` exists and
/// returns it — exactly the former `_ensureSeedDataDir`. The `key`
/// is ignored: every seed file shares this one directory (the photo
/// config is per-category instead).
Future<Directory> _seedRoot(String key) async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'seed_data'));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

/// The seed-catalog live-update configuration. Reproduces the former
/// `SeedUpdater` observable behaviour bit-for-bit (see file header).
final AssetUpdaterConfig seedCatalogConfig = AssetUpdaterConfig(
  allowlist: allowedKeys,
  filenameValidator: _isSafeSeedFilename,
  contentValidator: _validateSeedShape,
  storageRootProvider: _seedRoot,
  storagePathForFile: (filename) => 'seed_data/$filename',
  versionTrackerPrefix: seedVersionPrefix, // 'seed_version_' — verbatim
  manifestStoragePath: 'seed_data/manifest.json', // real live path
  writeStrategy: WriteStrategy.text,
  maxFileBytes: 8 * 1024 * 1024, // former _maxSeedBytes — verbatim
  contentDecoder: utf8.decode,
  // §0.5 C-c — the launch-critical deferred-re-seed trigger the
  // revised spec's config omitted. Former SeedUpdater set this
  // immediately after the version bump (seed_updater.dart:285).
  onAssetApplied: (key, version, prefs) async {
    await prefs.setBool('$seedNeedsReseedPrefix$key', true);
  },
);

// ---------------------------------------------------------------------------
// photoAssetConfig — binary photo/3D-asset live-update (Group D).
// ---------------------------------------------------------------------------

/// SharedPreferences key prefix for per-category photo-asset version
/// tracking (e.g. `photo_asset_version_photo_backdrops`). Distinct
/// from `seed_version_` — photo assets are an independent content
/// type on a separate storage root and version namespace.
const String photoAssetVersionPrefix = 'photo_asset_version_';

/// The six photo-asset categories — `photoAssetConfig`'s allowlist
/// and load-bearing security boundary. §0.5 D-a: DERIVED from Group
/// B's `PhotoAssetCategory` enum (photo_asset_directory.dart) so the
/// updater allowlist and the on-disk directory layout can NEVER
/// drift apart — one source of truth, the photo analogue of seed's
/// `allowedKeys`. (The revised spec declared a standalone
/// `kPhotoAssetCategories` const; deriving prevents the duplicate
/// from silently diverging from the directory enum.)
final Set<String> kPhotoAssetCategories = <String>{
  for (final c in PhotoAssetCategory.values) c.dirName,
};

/// Accepted photo / 3D-asset extensions (lower-cased compare).
const Set<String> _photoAssetExtensions = <String>{
  '.png',
  '.webp',
  '.jpg',
  '.jpeg',
  '.ktx2',
  '.gltf',
  '.glb',
};

/// Photo filename safety. §0.5 C-b discipline carried into Group D:
/// this is the FULL seed-grade hardening (backslash / leading-slash
/// / `.`/`..` / hidden / shell-metachar / control-char), NOT the
/// spec's bare extension check — the security boundary must not
/// soften on the binary path either. EXTENDED for the photo
/// contract (D-b): the filename is `<categoryDir>/<sub…>`, so the
/// first segment MUST be a known category and the path MUST end in
/// a photo/3D extension. Deeper nesting than seed's 2-level cap is
/// allowed (photo subtrees may nest) but every segment is still
/// hardened.
bool _isSafePhotoFilename(String filename) {
  if (filename.isEmpty) return false;
  if (filename.contains('\\')) return false;
  if (filename.startsWith('/')) return false;
  final lower = filename.toLowerCase();
  if (!_photoAssetExtensions.any(lower.endsWith)) return false;
  final parts = filename.split('/');
  // Must be `<category>/<file…>` — at least a category + a basename.
  if (parts.length < 2) return false;
  if (!kPhotoAssetCategories.contains(parts.first)) return false;
  for (final part in parts) {
    if (part.isEmpty) return false;
    if (part == '.' || part == '..') return false;
    if (part.startsWith('.')) return false;
    if (part.contains(RegExp(r'[\s\x00\$`;<>]'))) return false;
  }
  return true;
}

/// Lower-case hex SHA-256 of [bytes] via `package:cryptography`
/// (§0.5 C-e/D-d: `crypto` is NOT a project dependency; this is the
/// async path the `FutureOr<void>` contentValidator contract exists
/// for). Mirrors `photo_asset_loader.dart`'s `_defaultSha256Hex`.
Future<String> _sha256Hex(Uint8List bytes) async {
  final digest = await Sha256().hash(bytes);
  return digest.bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}

/// Mandatory SHA-256 integrity check for a downloaded photo asset.
/// A binary manifest entry MUST carry a digest — a missing one is a
/// rejection, not a skip (defense-in-depth, CLAUDE.md §28). Throws
/// [AssetValidationException] on a missing or mismatched digest; the
/// updater then keeps the local copy (never a partial overwrite).
Future<void> _validatePhotoSha256(
  Uint8List bytes,
  AssetEntry entry,
) async {
  final expected = entry.expectedSha256;
  if (expected == null || expected.isEmpty) {
    throw AssetValidationException(
      '${entry.filename}: photo manifest entry is missing its '
      'sha256 digest (integrity verification is mandatory for '
      'binary assets)',
    );
  }
  final actual = await _sha256Hex(bytes);
  if (actual.toLowerCase() != expected.toLowerCase()) {
    throw AssetValidationException(
      '${entry.filename}: SHA-256 mismatch — expected $expected, '
      'got $actual',
    );
  }
}

/// Photo-asset storage root. §0.5 D-b: ignores `key` (exactly like
/// `_seedRoot`) and returns the appSupport BASE. The photo manifest
/// `filename` is `<categoryDir>/<sub>`, so
/// `AssetUpdater._writeAtomic` writes
/// `<appSupport>/<categoryDir>/<sub>` (creating the category subdir
/// recursively) — byte-identical to where Group B's
/// `PhotoAssetDirectory.cdnResolver` reads it back.
Future<Directory> _photoAssetRoot(String key) =>
    getApplicationSupportDirectory();

/// The photo/3D-asset live-update configuration (Group D). See the
/// file header's "Group D §0.5 reconciliations" for D-a..D-g.
final AssetUpdaterConfig photoAssetConfig = AssetUpdaterConfig(
  allowlist: kPhotoAssetCategories,
  filenameValidator: _isSafePhotoFilename,
  contentValidator: _validatePhotoSha256,
  storageRootProvider: _photoAssetRoot,
  storagePathForFile: (filename) => 'photo_assets/$filename',
  versionTrackerPrefix: photoAssetVersionPrefix,
  manifestStoragePath: 'photo_assets/manifest.json', // D-e
  writeStrategy: WriteStrategy.binary,
  // D-f: photo backdrops / sprites / .glb models dwarf the 8 MB JSON
  // cap; 64 MB is a generous-but-bounded ceiling against an
  // unbounded write. Tune when Phase 6 asset measurement lands.
  maxFileBytes: 64 * 1024 * 1024,
  contentDecoder: null, // opaque binary — no String view
  // §0.5 D-c: Group A's PhotoAssetLoader invalidates BY CONSTRUCTION
  // (version-keyed cache `<key>@v<version>`), so the spec's
  // callback/stream subscription is unnecessary. Belt-and-suspenders
  // for an update applied THIS launch (before any version-keyed
  // miss): drop the decode cache via the existing public API
  // (intended for exactly "assets changed / tier teardown"). No new
  // pub/sub infra over the deliberate Group A design.
  onAssetApplied: (key, version, prefs) async {
    PhotoAssetLoader.instance.clearCache();
  },
);
