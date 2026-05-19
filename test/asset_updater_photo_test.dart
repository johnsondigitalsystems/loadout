// FILE: test/asset_updater_photo_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// VFP Phase 4 Group D — the mock-Firebase end-to-end flow suite for
// `AssetUpdater(photoAssetConfig)` (spec §4 Task 5 + the V6.11 §10
// Phase 4 Group C original exit criteria). It drives the GENERIC
// `AssetUpdater` through a fake Firebase Storage and a temp-dir
// storage root, asserting the photo path's observable behaviour:
//
//   * manifest fetch + parse (a JSON photo manifest → AssetEntry map)
//   * per-asset binary download + atomic write to disk
//   * SHA-256 corruption rejection (wrong digest → NOT written; never
//     a partial overwrite; version NOT bumped)
//   * atomic temp-then-rename (target has exact bytes; no leftover
//     `.tmp`)
//   * anti-downgrade (manifest vN when local pref is vN+1 → skipped)
//   * version-tracking persistence across a simulated app restart
//     (a second run does not re-download)
//   * allowlist rejection (unknown category key → ignored)
//   * malformed / object-not-found manifest → silent no-op (never
//     throws — a background update must never sink the app)
//
// ============================================================================
// WHY IT EXISTS
// ============================================================================
// The seed path is covered by the firm `asset_updater_allowlist_test
// .dart`; the photo path is new (Group D) and binary, with a
// mandatory-SHA-256 + atomic-write contract that a predicate test
// cannot exercise. A regression here (a corrupt asset written, a
// downgrade applied, a re-download every launch) is silent until a
// user sees a broken/stale image, so it is pinned at test time.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * §0.5 D-g: there is NO mock library in this repo (no mocktail /
//     mockito / firebase_storage_mocks) and the Firebase Storage
//     plugin classes are not conveniently subclassable, so the fake
//     is a hand-rolled `implements`+`noSuchMethod` pair against the
//     EXISTING `FirebaseStorage? storage` seam — zero production
//     change; the launch-critical seed path is untouched.
//   * The config under test reuses every REAL `photoAssetConfig`
//     behaviour (filename validator, mandatory-SHA-256 validator,
//     allowlist, paths, the PhotoAssetLoader cache-drop hook) and
//     only swaps `storageRootProvider` for a temp dir — the one
//     field that would otherwise need `path_provider`. So this
//     tests the real photo config, not a stand-in.
//   * `contentValidator` is `FutureOr<void>` (D-d, async SHA-256 via
//     `package:cryptography`); the updater `await`s it, so these
//     tests assert the async rejection lands as a skipped write.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// Creates + deletes a system temp directory per test. No network
// (the fake Storage is in-memory). SharedPreferences uses the test
// mock store. `PhotoAssetLoader.instance.clearCache()` runs via the
// real `onAssetApplied` hook (a no-op dispose over an empty cache).

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart' show Sha256;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/services/asset_updater.dart';
import 'package:loadout/services/asset_updater_config.dart';
import 'package:loadout/services/asset_updater_configs.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Hand-rolled Firebase Storage fake (§0.5 D-g). AssetUpdater only ever
// calls `_storage.ref(path)` then `ref.getData(maxBytes)`; everything
// else routes to a throwing noSuchMethod so an unexpected call is a
// loud test failure, not a silent stub.
// ---------------------------------------------------------------------------

class _FakeStorage implements FirebaseStorage {
  _FakeStorage(this.responses);

  /// Storage path → bytes. A path absent from the map makes
  /// `getData` throw `object-not-found` (the real pre-populated-bucket
  /// state the updater silences).
  final Map<String, Uint8List> responses;

  /// Per-path getData call counter — proves "downloaded once".
  final Map<String, int> getDataCalls = {};

  @override
  Reference ref([String? path]) => _FakeReference(path ?? '', this);

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError(
      'unexpected FirebaseStorage.${i.memberName} in test');
}

class _FakeReference implements Reference {
  _FakeReference(this.path, this.harness);

  final String path;
  // Named `harness` deliberately: `Reference` already declares BOTH
  // `storage` and `parent` getters, so either name would be read as
  // a (type-incompatible) override. This back-reference is test
  // plumbing, not part of the Reference API (those getters route to
  // the throwing noSuchMethod and are never called by AssetUpdater).
  final _FakeStorage harness;

  @override
  Future<Uint8List?> getData([int maxSize = 10 * 1024 * 1024]) async {
    harness.getDataCalls[path] =
        (harness.getDataCalls[path] ?? 0) + 1;
    final bytes = harness.responses[path];
    if (bytes == null) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'object-not-found',
        message: 'no object at $path',
      );
    }
    return bytes;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError(
      'unexpected Reference.${i.memberName} in test');
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

Future<String> _sha256(Uint8List b) async {
  final d = await Sha256().hash(b);
  return d.bytes.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
}

/// A photo manifest JSON byte payload for one entry.
Uint8List _manifest({
  required String key,
  required int version,
  required String filename,
  String? sha256,
}) =>
    _bytes(json.encode({
      'files': {
        key: {
          'version': version,
          'filename': filename,
          'sha256': ?sha256,
        },
      },
    }));

/// `photoAssetConfig` with ONLY `storageRootProvider` swapped for
/// [root] (the single field that would otherwise need path_provider).
/// Every other field is the real production config.
AssetUpdaterConfig _photoConfigAt(Directory root) => AssetUpdaterConfig(
      allowlist: photoAssetConfig.allowlist,
      filenameValidator: photoAssetConfig.filenameValidator,
      contentValidator: photoAssetConfig.contentValidator,
      storageRootProvider: (_) async => root,
      storagePathForFile: photoAssetConfig.storagePathForFile,
      versionTrackerPrefix: photoAssetConfig.versionTrackerPrefix,
      manifestStoragePath: photoAssetConfig.manifestStoragePath,
      writeStrategy: photoAssetConfig.writeStrategy,
      maxFileBytes: photoAssetConfig.maxFileBytes,
      contentDecoder: photoAssetConfig.contentDecoder,
      onAssetApplied: photoAssetConfig.onAssetApplied,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  const manifestPath = 'photo_assets/manifest.json';
  const key = 'photo_backdrops';
  const filename = 'photo_backdrops/range_dawn.webp';
  const assetPath = 'photo_assets/photo_backdrops/range_dawn.webp';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('au_photo_test_');
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  File outFile() => File('${root.path}/$filename');

  test('happy path: fetch → SHA-256 ok → atomic write → version bump',
      () async {
    final payload = _bytes('the-real-backdrop-bytes');
    final sha = await _sha256(payload);
    final storage = _FakeStorage({
      manifestPath: _manifest(
          key: key, version: 2, filename: filename, sha256: sha),
      assetPath: payload,
    });

    await AssetUpdater(config: _photoConfigAt(root), storage: storage)
        .fetchAndApply();

    expect(outFile().existsSync(), isTrue, reason: 'asset written');
    expect(outFile().readAsBytesSync(), payload,
        reason: 'exact bytes on disk');
    // Atomic temp-then-rename consumed the .tmp.
    expect(File('${outFile().path}.tmp').existsSync(), isFalse,
        reason: 'no leftover .tmp');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('photo_asset_version_$key'), 2,
        reason: 'version tracked');
    expect(storage.getDataCalls[assetPath], 1);
  });

  test('SHA-256 mismatch → asset NOT written, version NOT bumped',
      () async {
    final good = _bytes('intended-bytes');
    final corrupt = _bytes('tampered-in-transit');
    final storage = _FakeStorage({
      // Manifest advertises the digest of `good`…
      manifestPath: _manifest(
          key: key,
          version: 2,
          filename: filename,
          sha256: await _sha256(good)),
      // …but Storage serves `corrupt`.
      assetPath: corrupt,
    });

    await AssetUpdater(config: _photoConfigAt(root), storage: storage)
        .fetchAndApply();

    expect(outFile().existsSync(), isFalse,
        reason: 'rejected — never a partial overwrite');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('photo_asset_version_$key'), isNull,
        reason: 'version not bumped on a rejected asset');
  });

  test('missing sha256 in manifest → mandatory-digest rejection',
      () async {
    final payload = _bytes('no-digest-declared');
    final storage = _FakeStorage({
      manifestPath: _manifest(key: key, version: 2, filename: filename),
      assetPath: payload,
    });

    await AssetUpdater(config: _photoConfigAt(root), storage: storage)
        .fetchAndApply();

    expect(outFile().existsSync(), isFalse,
        reason: 'binary asset without a digest is rejected (§28)');
  });

  test('anti-downgrade: manifest vN skipped when local pref is vN+1',
      () async {
    SharedPreferences.setMockInitialValues(
        {'photo_asset_version_$key': 9});
    final payload = _bytes('older-version-payload');
    final storage = _FakeStorage({
      manifestPath: _manifest(
          key: key,
          version: 3,
          filename: filename,
          sha256: await _sha256(payload)),
      assetPath: payload,
    });

    await AssetUpdater(config: _photoConfigAt(root), storage: storage)
        .fetchAndApply();

    expect(outFile().existsSync(), isFalse,
        reason: 'older remote never overwrites a newer local copy');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('photo_asset_version_$key'), 9,
        reason: 'local version untouched');
    expect(storage.getDataCalls[assetPath], isNull,
        reason: 'anti-downgrade short-circuits before download');
  });

  test('version persists across a simulated restart → no re-download',
      () async {
    final payload = _bytes('persisted-payload');
    final manifest = _manifest(
        key: key,
        version: 2,
        filename: filename,
        sha256: await _sha256(payload));

    final storage1 = _FakeStorage(
        {manifestPath: manifest, assetPath: payload});
    await AssetUpdater(config: _photoConfigAt(root), storage: storage1)
        .fetchAndApply();
    expect(storage1.getDataCalls[assetPath], 1);

    // Simulated restart: same SharedPreferences store, fresh updater +
    // fresh fake. The persisted version must short-circuit Gate 3.
    final storage2 = _FakeStorage(
        {manifestPath: manifest, assetPath: payload});
    await AssetUpdater(config: _photoConfigAt(root), storage: storage2)
        .fetchAndApply();
    expect(storage2.getDataCalls[assetPath], isNull,
        reason: 'already at v2 — must not re-download');
  });

  test('allowlist: unknown category key is ignored', () async {
    final payload = _bytes('rogue');
    final storage = _FakeStorage({
      manifestPath: _manifest(
          key: 'not_a_real_category',
          version: 2,
          filename: 'not_a_real_category/x.webp',
          sha256: await _sha256(payload)),
      'photo_assets/not_a_real_category/x.webp': payload,
    });

    await AssetUpdater(config: _photoConfigAt(root), storage: storage)
        .fetchAndApply();

    expect(
        File('${root.path}/not_a_real_category/x.webp').existsSync(),
        isFalse,
        reason: 'key outside the allowlist never writes');
  });

  test('object-not-found manifest → silent no-op (never throws)',
      () async {
    // Empty responses → manifest fetch throws object-not-found, which
    // the updater swallows (the expected pre-populated-bucket state).
    final storage = _FakeStorage({});
    await expectLater(
      AssetUpdater(config: _photoConfigAt(root), storage: storage)
          .fetchAndApply(),
      completes,
    );
    expect(outFile().existsSync(), isFalse);
  });

  test('malformed manifest JSON → silent no-op (never throws)',
      () async {
    final storage = _FakeStorage({manifestPath: _bytes('{not valid')});
    await expectLater(
      AssetUpdater(config: _photoConfigAt(root), storage: storage)
          .fetchAndApply(),
      completes,
    );
    expect(outFile().existsSync(), isFalse);
  });

  test('suspicious filename in manifest is rejected pre-download',
      () async {
    final payload = _bytes('evil');
    final storage = _FakeStorage({
      manifestPath: _manifest(
          key: key,
          version: 2,
          filename: 'photo_backdrops/../escape.webp',
          sha256: await _sha256(payload)),
    });

    await AssetUpdater(config: _photoConfigAt(root), storage: storage)
        .fetchAndApply();

    expect(File('${root.path}/escape.webp').existsSync(), isFalse);
    expect(storage.getDataCalls.containsKey(assetPath), isFalse,
        reason: 'filename gate short-circuits before any download');
  });
}
