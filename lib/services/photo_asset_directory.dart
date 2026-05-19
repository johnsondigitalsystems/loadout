// FILE: lib/services/photo_asset_directory.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// VFP Phase 4 Group B — the on-device filesystem layout for
// downloaded photo assets, plus the production `CdnResolver` that
// VFP Phase 4 Group A's `PhotoAssetLoader` consumes (it was left an
// injected seam in Group A specifically so this file owns the
// `dart:io` / `path_provider` concern).
//
// Public surface:
//   * `PhotoAssetCategory` — the six asset categories (one
//     directory each, names verbatim from VFP §10 Phase 4 Group B):
//     `photo_backdrops`, `photo_sprites`, `photo_animals`,
//     `photo_iron_sights`, `photo_effects`, `photo_3d_models`.
//   * `PhotoAssetDirectory` — resolves `<appSupport>/<category>/…`,
//     creates directories on first use, exposes:
//       - `cdnResolver` — the `CdnResolver` for `PhotoAssetLoader`
//         (returns the downloaded bytes for a relative path, or null
//         → bundle fallback). Null-returning on web/macOS.
//       - `clearCategory()` / `clearAll()` — Settings → Storage →
//         Clear Cached Assets.
//       - `categorySizeBytes()` — per-category cache size for the UI.
//   * `photoAssetFilesystemCacheSupported` — `!(kIsWeb ||
//     Platform.isMacOS)`. Web AND macOS are bundle-only (VFP §4.18):
//     no filesystem cache, no CDN downloads, the resolver always
//     returns null so the loader uses the bundled asset.
//
// The OS base directory is an injected seam (`baseDirProvider`) so
// tests run against a temp dir without `path_provider`'s
// MissingPluginException — the same testability discipline Group A
// used for its loader seams.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// VFP §10 sequences Group A (loader, seam-based, no filesystem) →
// Group B (this: the real filesystem + cache UI) → Group C
// (SeedUpdater populates these directories). Centralising the path
// layout + platform guard here means the loader stays portable, the
// Settings UI has one place to query/clear, and Group C has one
// place to write downloads into.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * `getApplicationSupportDirectory()` is iOS/Android/macOS only
//     and throws on web. The web/macOS guard MUST short-circuit
//     BEFORE any `path_provider` call (`kIsWeb` first, then
//     `Platform.isMacOS` — `kIsWeb` alone is false on macOS, the
//     §4.18 footgun). On guarded platforms every method is a no-op:
//     the resolver returns null (→ bundle), clear/size return
//     empty/zero.
//   * Phase 4's cache root is `getApplicationSupportDirectory()`,
//     DELIBERATELY different from `SeedUpdater`'s
//     `getApplicationDocumentsDirectory()/seed_data` (small JSON).
//     Photo assets are large binaries on a separate root — Group C
//     must reconcile SeedUpdater's manifest/allowedKeys machinery
//     with this layout (flagged P4-4; concrete at Group C).
//   * Directory creation races: `create(recursive: true)` is
//     idempotent and safe to call on every resolve; we do NOT cache
//     a "created" flag (a user clearing the cache mid-session would
//     stale it).
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   * `lib/services/photo_asset_loader.dart` — wired via
//     `PhotoAssetLoader.cdnResolver = PhotoAssetDirectory.instance
//     .cdnResolver` at app start (Group B integration).
//   * `lib/screens/settings/storage_settings_screen.dart` — the
//     Clear-Cached-Assets UI (size + clear per category).
//   * VFP Phase 4 Group C — SeedUpdater writes downloads into
//     `dirFor(category)`.
//   * `test/photo_asset_directory_test.dart`.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
//   * Creates directories under `getApplicationSupportDirectory()`
//     (guarded platforms only). Reads/deletes files there on
//     resolve / clear. No network (Group C owns downloads). All
//     I/O is no-op on web/macOS.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import 'photo_asset_loader.dart' show CdnResolver;

/// True iff this platform keeps a filesystem photo-asset cache.
/// `false` on web AND macOS (bundle-only, VFP §4.18). `kIsWeb` is
/// evaluated first so `Platform` is never touched on web.
///
/// NOTE: this is the SAME set as `scenicPhotographicSupported`
/// (visual_tier_platform.dart) — web/macOS get Stylized only AND no
/// filesystem cache — but it is a DISTINCT concept (tier
/// availability vs cache availability) kept as its own predicate so
/// each guard's intent reads clearly at its call site. Both
/// centralise the one `kIsWeb || Platform.isMacOS` rule.
bool get photoAssetFilesystemCacheSupported =>
    !(kIsWeb || Platform.isMacOS);

/// The six downloaded-photo-asset categories. Directory names are
/// verbatim from VFP §10 Phase 4 Group B.
enum PhotoAssetCategory {
  backdrops('photo_backdrops'),
  sprites('photo_sprites'),
  animals('photo_animals'),
  ironSights('photo_iron_sights'),
  effects('photo_effects'),
  models3d('photo_3d_models');

  const PhotoAssetCategory(this.dirName);

  /// On-disk subdirectory name under the app-support root.
  final String dirName;
}

/// Resolves [category] → `<base>/dirName` and returns the directory,
/// creating it (recursively, idempotently) on first use. Injected so
/// tests supply a temp dir instead of `path_provider`.
typedef BaseDirProvider = Future<Directory> Function();

class PhotoAssetDirectory {
  PhotoAssetDirectory({
    BaseDirProvider? baseDirProvider,
    bool Function()? cacheSupported,
  })  : _baseDirProvider =
            baseDirProvider ?? getApplicationSupportDirectory,
        // Injectable so tests exercise the FS logic deterministically
        // regardless of host OS. The real predicate is
        // `Platform.isMacOS`-sensitive, so on a macOS test host the
        // production default would no-op every method and the
        // functional tests would (host-dependently) fail. Default =
        // the real §4.18 guard for production.
        _cacheSupported =
            cacheSupported ?? (() => photoAssetFilesystemCacheSupported);

  /// App-wide instance (production: real `getApplicationSupportDirectory`
  /// + the real §4.18 platform guard).
  static final PhotoAssetDirectory instance = PhotoAssetDirectory();

  final BaseDirProvider _baseDirProvider;
  final bool Function() _cacheSupported;

  /// The directory for [category], created on first use. Throws via
  /// the caller-visible no-op contract only if invoked on a guarded
  /// platform — callers should gate on
  /// [photoAssetFilesystemCacheSupported] first; the public methods
  /// below already do.
  Future<Directory> dirFor(PhotoAssetCategory category) async {
    final base = await _baseDirProvider();
    final dir = Directory('${base.path}/${category.dirName}');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// The production [CdnResolver] for `PhotoAssetLoader`. Returns the
  /// downloaded bytes for [relativePath] (interpreted as
  /// `<category.dirName>/<rest…>`), or null when there is no
  /// downloaded copy (→ the loader falls back to the bundled asset)
  /// or the platform is bundle-only (web/macOS).
  CdnResolver get cdnResolver => _resolve;

  Future<Uint8List?> _resolve(String relativePath) async {
    if (!_cacheSupported()) return null;
    final category = _categoryForPath(relativePath);
    if (category == null) return null;
    try {
      final dir = await dirFor(category);
      // relativePath is "<dirName>/<sub...>"; strip the leading
      // category segment since dirFor already points at it.
      final sub = relativePath.substring(category.dirName.length + 1);
      final file = File('${dir.path}/$sub');
      if (!file.existsSync()) return null;
      return await file.readAsBytes();
    } catch (_) {
      // Any FS error → behave as "no cached copy" so the loader
      // bundle-fallbacks rather than throwing into a paint path.
      return null;
    }
  }

  static PhotoAssetCategory? _categoryForPath(String relativePath) {
    for (final c in PhotoAssetCategory.values) {
      if (relativePath == c.dirName ||
          relativePath.startsWith('${c.dirName}/')) {
        return c;
      }
    }
    return null;
  }

  /// Total bytes cached for [category] (0 on guarded platforms /
  /// missing dir). Used by the Storage settings UI.
  Future<int> categorySizeBytes(PhotoAssetCategory category) async {
    if (!_cacheSupported()) return 0;
    try {
      final base = await _baseDirProvider();
      final dir = Directory('${base.path}/${category.dirName}');
      if (!dir.existsSync()) return 0;
      var total = 0;
      await for (final e in dir.list(recursive: true, followLinks: false)) {
        if (e is File) total += await e.length();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Delete every cached file for [category] (the directory itself
  /// is left in place, recreated lazily). No-op on guarded platforms.
  Future<void> clearCategory(PhotoAssetCategory category) async {
    if (!_cacheSupported()) return;
    try {
      final base = await _baseDirProvider();
      final dir = Directory('${base.path}/${category.dirName}');
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {
      // Best-effort — a locked file should not crash the UI.
    }
  }

  /// Clear every category.
  Future<void> clearAll() async {
    for (final c in PhotoAssetCategory.values) {
      await clearCategory(c);
    }
  }
}
