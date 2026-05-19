// FILE: lib/services/asset_updater_config.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Value types for the generic `AssetUpdater` (lib/services/
// asset_updater.dart): the per-content-type `AssetUpdaterConfig`,
// the parsed-manifest types (`AssetEntry`, `AssetManifest`), the
// `WriteStrategy` enum, and `AssetValidationException`.
//
// VFP Phase 4 Groups C+D refactor `SeedUpdater` into ONE generic
// `AssetUpdater` configured per content type (seed-catalog JSON in
// Group C; binary photo assets in Group D) — composition over
// subclassing. This file is the configuration surface.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Splitting the config into its own file lets the generic updater,
// the two concrete configs (`asset_updater_configs.dart`), and the
// tests all import the value types without dragging the
// FirebaseStorage-touching updater along.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS (§0.5 corrections vs. the spec)
// ============================================================================
//   * C-c (load-bearing): the real seed flow sets TWO SharedPrefs
//     keys per applied file — `seed_version_<key>` AND
//     `seed_needs_reseed_<key>=true` (the latter is what
//     `seed_loader.dart` reads to trigger the deferred DB re-seed).
//     The revised spec's config modelled only the version prefix;
//     implementing it literally would DROP the reseed flag and
//     regress the launch-critical hot-fix path. Hence
//     [AssetUpdaterConfig.onAssetApplied] — a per-config post-apply
//     hook. Seed config sets the reseed flag here; the photo config
//     (Group D) invalidates `PhotoAssetLoader` here instead.
//   * C-b: `filenameValidator` is the FULL `_isSafeManifestFilename`
//     logic for the seed config (path-traversal / backslash / hidden
//     / shell-metachar defenses), NOT the spec's `.endsWith('.json')`
//     one-liner — that one-liner would remove a security boundary in
//     a launch-critical path.
//   * C-a: the seed config's manifest + per-file Firebase paths are
//     `seed_data/manifest.json` / `seed_data/<filename>` (the real
//     live bucket layout, CLAUDE.md §28), NOT the spec's example
//     `manifests/seed.json`. Modelled here as
//     [manifestStoragePath] + [storagePathForFile].
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   * lib/services/asset_updater.dart — the generic updater.
//   * lib/services/asset_updater_configs.dart — seed + photo configs.
//   * test/asset_updater_allowlist_test.dart (flat test/ — the
//     spec's `test/services/...` is stale-convention, D-8 class).
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
//   * None. Pure value types + function-typed config fields.

import 'dart:async' show FutureOr;
import 'dart:io' show Directory;
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// Encoding contract for the on-disk write. Both strategies route
/// through the SAME atomic temp-then-rename byte pipeline in
/// `AssetUpdater._writeAtomic`; this only records whether callers
/// (and the optional [AssetUpdaterConfig.contentDecoder]) treat the
/// bytes as UTF-8 text (seed JSON) or opaque binary (photo assets).
enum WriteStrategy { text, binary }

/// One entry from a remote manifest's `files` object:
/// `"<key>": { "version": <int>, "filename": "<path>", ... }`.
/// [expectedSha256] is non-null only for content types whose
/// manifest carries per-file digests (photo assets, Group D); the
/// seed catalog manifest has none.
class AssetEntry {
  const AssetEntry({
    required this.key,
    required this.version,
    required this.filename,
    this.expectedSha256,
  });

  final String key;
  final int version;
  final String filename;
  final String? expectedSha256;
}

/// A parsed remote manifest: the validated `files` map, key → entry.
/// (Mirrors the real SeedUpdater shape — `manifest['files']` is a
/// `Map<String,dynamic>` of key → `{version,filename}` — NOT a list.)
class AssetManifest {
  const AssetManifest(this.entries);
  final Map<String, AssetEntry> entries;
}

/// Thrown by a config's `contentValidator` when downloaded bytes
/// fail validation (bad JSON shape; SHA-256 mismatch). The updater
/// catches it, logs, and keeps the existing local copy — never a
/// partial overwrite.
class AssetValidationException implements Exception {
  AssetValidationException(this.message);
  final String message;
  @override
  String toString() => 'AssetValidationException: $message';
}

/// Per-content-type configuration for [AssetUpdater]. Captures every
/// behaviour that differs between the seed-catalog JSON path and the
/// photo-asset binary path so the updater itself stays generic.
class AssetUpdaterConfig {
  AssetUpdaterConfig({
    required this.allowlist,
    required this.filenameValidator,
    required this.contentValidator,
    required this.storageRootProvider,
    required this.storagePathForFile,
    required this.versionTrackerPrefix,
    required this.manifestStoragePath,
    required this.writeStrategy,
    required this.maxFileBytes,
    this.contentDecoder,
    this.onAssetApplied,
  });

  /// Allowed manifest keys. The load-bearing security boundary —
  /// keys outside this set are ignored so a tampered/ future-shape
  /// manifest cannot write to unexpected paths.
  final Set<String> allowlist;

  /// True iff [filename] is safe to write for this content type.
  /// Seed config = the FULL `_isSafeManifestFilename` logic
  /// (path-traversal / backslash / leading-slash / hidden / depth /
  /// shell-metachar / `.json`), NOT a bare extension check.
  final bool Function(String filename) filenameValidator;

  /// Validates downloaded bytes for [entry]. Throws
  /// [AssetValidationException] on failure (the updater then keeps
  /// the local copy — never a partial overwrite). Seed = JSON
  /// top-level shape (synchronous, throws sync). Photo (Group D) =
  /// SHA-256 vs the manifest digest.
  ///
  /// §0.5 D-d: the return type is `FutureOr<void>`, not bare `void`,
  /// because the photo SHA-256 path hashes via `package:cryptography`
  /// (`Sha256().hash(...)` is async — `crypto` is NOT a project
  /// dependency; C-e). `AssetUpdater._downloadAndValidate` `await`s
  /// it, so a sync validator (seed — throws synchronously, the firm
  /// regression test stays verbatim) and an async one (photo) are
  /// both supported with no behaviour change to the seed path.
  final FutureOr<void> Function(Uint8List bytes, AssetEntry entry)
      contentValidator;

  /// Resolves the on-device directory for a manifest [key]'s
  /// category. Seed = `<appDocuments>/seed_data`; photo (Group D) =
  /// `<appSupport>/<category>`.
  final Future<Directory> Function(String key) storageRootProvider;

  /// The Firebase Storage path for an individual asset [filename].
  /// Seed = `seed_data/<filename>` (real live bucket layout, §28).
  final String Function(String filename) storagePathForFile;

  /// SharedPrefs key prefix for per-key version tracking. Seed =
  /// `seed_version_` (MUST stay verbatim — field-installed apps key
  /// off this; drift orphans version tracking on upgrade).
  final String versionTrackerPrefix;

  /// Firebase Storage path of this content type's manifest. Seed =
  /// `seed_data/manifest.json` (real live path — NOT the spec's
  /// illustrative `manifests/seed.json`).
  final String manifestStoragePath;

  /// Encoding contract (see [WriteStrategy]).
  final WriteStrategy writeStrategy;

  /// Max bytes for a single downloaded asset (defence against an
  /// unbounded write). §0.5 C-f: SeedUpdater hardcoded 8 MB, right
  /// for JSON but too small for photo backdrops/sprites — so it is
  /// config-driven. Seed config MUST keep `8 * 1024 * 1024`
  /// verbatim; photo config (Group D) sets a larger cap.
  final int maxFileBytes;

  /// Optional decoder for callers/validators that want String
  /// content. Seed = `utf8.decode`; photo = null (binary).
  final String Function(Uint8List bytes)? contentDecoder;

  /// Post-apply side effect, run AFTER the file is written and the
  /// version bumped, with the live [SharedPreferences]. This is the
  /// §0.5 C-c correction: the seed config sets
  /// `seed_needs_reseed_<key>=true` here (the launch-critical
  /// deferred-re-seed trigger the spec's config omitted); the photo
  /// config (Group D) invalidates the decode cache here. Null = no
  /// post-apply effect.
  final Future<void> Function(
    String key,
    int version,
    SharedPreferences prefs,
  )? onAssetApplied;
}
