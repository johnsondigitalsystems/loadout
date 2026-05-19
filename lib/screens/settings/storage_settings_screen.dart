// FILE: lib/screens/settings/storage_settings_screen.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// VFP Phase 4 Group B — Settings → Storage. Surfaces the downloaded
// photo-asset cache: one row per `PhotoAssetCategory` showing its
// on-disk size with a per-category "Clear" button, plus a
// "Clear All Cached Assets" action. Reads / clears through
// `PhotoAssetDirectory.instance` (the single owner of the
// app-support filesystem layout).
//
// On web / macOS the app is bundle-only (VFP §4.18 —
// `photoAssetFilesystemCacheSupported == false`): there is no
// filesystem cache, so the screen shows a single explanatory
// empty-state instead of clear buttons (clearing nothing would be
// confusing).
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The plan (VFP §10 Phase 4 Group B task 3) requires "Settings →
// Storage → Clear Cached Assets (one button per category)". No
// "Storage" settings surface existed; this screen is created per
// that task and registered as a `_SettingsTileSpec` in
// `settings_screen.dart`. It is the user's only handle on the
// (potentially 100+ MB once Scenic/Photographic assets land) photo
// cache.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * Sizes are async + change after a clear, so the screen is
//     stateful and re-queries (`_reload()`) after every mutation.
//   * Clearing is best-effort in the service (a locked file won't
//     crash); the UI re-reads the true size afterward rather than
//     assuming zero.
//   * The web/macOS guard must drive the WHOLE screen body, not
//     just hide buttons — querying sizes there is a guaranteed 0
//     and the clear actions are no-ops; showing them would imply a
//     cache that does not exist.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   * `lib/screens/settings/settings_screen.dart` — the "Storage"
//     `_SettingsTileSpec` routes here.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
//   * Reads photo-asset cache sizes from disk; deletes cached files
//     on user action (via `PhotoAssetDirectory`). No-op on web/macOS.

import 'package:flutter/material.dart';

import '../../services/photo_asset_directory.dart';
import '../../services/photo_asset_loader.dart';

class StorageSettingsScreen extends StatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  State<StorageSettingsScreen> createState() =>
      _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends State<StorageSettingsScreen> {
  final _dir = PhotoAssetDirectory.instance;
  Future<Map<PhotoAssetCategory, int>>? _sizes;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _sizes = _loadSizes();
    });
  }

  Future<Map<PhotoAssetCategory, int>> _loadSizes() async {
    final out = <PhotoAssetCategory, int>{};
    for (final c in PhotoAssetCategory.values) {
      out[c] = await _dir.categorySizeBytes(c);
    }
    return out;
  }

  static String _human(int bytes) {
    if (bytes <= 0) return 'Empty';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  static String _label(PhotoAssetCategory c) => switch (c) {
        PhotoAssetCategory.backdrops => 'Backdrops',
        PhotoAssetCategory.sprites => 'Sprites',
        PhotoAssetCategory.animals => 'Animals',
        PhotoAssetCategory.ironSights => 'Iron Sights',
        PhotoAssetCategory.effects => 'Effects',
        PhotoAssetCategory.models3d => '3D Models',
      };

  Future<void> _clear(PhotoAssetCategory? category) async {
    final messenger = ScaffoldMessenger.of(context);
    if (category == null) {
      await _dir.clearAll();
    } else {
      await _dir.clearCategory(category);
    }
    // The loader's in-memory LRU may hold decoded copies; drop them
    // so a re-render re-resolves (and now misses → bundle/redownload).
    PhotoAssetLoader.instance.clearCache();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(category == null
            ? 'Cleared all cached photo assets.'
            : 'Cleared ${_label(category)} cache.'),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Storage')),
      body: SafeArea(
        child: !photoAssetFilesystemCacheSupported
            ? _bundleOnlyState(theme)
            : _cacheList(theme),
      ),
    );
  }

  Widget _bundleOnlyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sd_storage_outlined,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'No cached assets on this platform',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'On this platform LoadOut renders from the app bundle '
              'and never downloads or caches photo assets, so there '
              'is nothing to clear. Scenic and Photographic assets '
              'are downloaded only on iOS and Android.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _cacheList(ThemeData theme) {
    return FutureBuilder<Map<PhotoAssetCategory, int>>(
      future: _sizes,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final sizes = snap.data ?? const {};
        final total =
            sizes.values.fold<int>(0, (a, b) => a + b);
        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Cached Photo Assets',
                style: theme.textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Scenic and Photographic visual tiers download photo '
                'assets on demand. Clearing a category frees space; '
                'assets re-download the next time that tier needs '
                'them.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final c in PhotoAssetCategory.values)
              ListTile(
                title: Text(_label(c)),
                subtitle: Text(_human(sizes[c] ?? 0)),
                trailing: TextButton(
                  onPressed: (sizes[c] ?? 0) <= 0
                      ? null
                      : () => _clear(c),
                  child: const Text('Clear'),
                ),
              ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.tonalIcon(
                onPressed:
                    total <= 0 ? null : () => _clear(null),
                icon: const Icon(Icons.delete_sweep_outlined),
                label: Text(
                  total <= 0
                      ? 'Nothing Cached'
                      : 'Clear All Cached Assets '
                          '(${_human(total)})',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
