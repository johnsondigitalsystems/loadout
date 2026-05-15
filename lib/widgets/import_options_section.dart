// FILE: lib/widgets/import_options_section.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// A reusable, collapsed-by-default `ExpansionTile` that surfaces
// "bring data in" affordances on the Quick Add and full Recipe
// form screens. Phase One Group 5 (2026-05-14) collapsed every
// "import a recipe" affordance behind a single canonical entry
// point — `RecipeImportLandingScreen` — so this widget now ships
// ONE recipe-import tile that pushes the landing screen, plus the
// AI Smart Import settings deep-link and cloud-restore rows that
// serve different purposes from recipe import.
//
// Surface (in order):
//
//   1. Import a Recipe                  → RecipeImportLandingScreen
//      (which handles spreadsheet, photo, file, clipboard, QR, and
//       the Coming Soon Word / OneNote / Garmin Xero photo tiles)
//   2. AI Smart Import (Pro)            → routes to AI settings
//      (improves a low-confidence parse — separate concept from
//       bringing a recipe in)
//   3. Import from iCloud / Google Drive / OneDrive → cloud restore
//      (full-DB restore from an encrypted backup — separate concept
//       from per-recipe import)
//
// The widget itself is stateless on the data side — it constructs
// each row from the current platform / Pro state and delegates the
// actual import work to the landing screen / restore services via
// callbacks (so the parent can decide whether to pop after a
// successful insert, refresh its list stream, etc.). The
// collapse/expand state survives layout rebuilds via a
// `PageStorageKey`.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Pre-launch UX feedback was that the imports were buried in three
// different surfaces (the Recipes list FAB sheet, the Quick Add card
// list, the photo-import direct entry) with overlapping subtitles and
// inconsistent ordering. Putting every import path behind one
// collapsible section keeps the form's first-paint clean while making
// it discoverable in one tap on either form.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **Cross-platform rendering.** Photo import is mobile-only (ML Kit
//    has no web / desktop). The spreadsheet picker uses `file_picker`,
//    which is universally supported. The cloud-restore options gate on
//    each provider's `isAvailable()`, which is itself a platform check
//    (iCloud → iOS only, OneDrive → not until the operator activates
//    the Azure AD client id, etc.). The widget hides each row whose
//    transport isn't usable so we never offer a path that will fail.
// 2. **Soft failure.** Every import path runs inside a `safeAsync` so
//    a thrown exception never reaches the user as a red screen — the
//    SnackBar is the only signal of trouble. The caller passes a
//    callback that fires after a successful import; the widget itself
//    doesn't know how the parent wants to react to "imported N rows".
// 3. **Clipboard CSV vs. another-app CSV.** Both end up routing
//    through `SpreadsheetImportScreen` because that screen already handles
//    fuzzy header detection, mapping confirmation, and validation.
//    The "another app" path differs only in the AppBar title and a
//    little intro copy via `titleOverride`.
// 4. **Pro gate placement.** AI Smart Import routes through the AI
//    settings screen (where the master toggle and BYOK input live)
//    rather than firing the proxy directly — that respects the
//    "off by default, opt-in per import" privacy posture.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/recipes/quick_add_recipe_screen.dart
// - lib/screens/recipes/recipe_form_screen.dart
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Each row pushes its own route via `Navigator.of(context).push`.
// - The "Paste from clipboard" row reads the OS clipboard via
//   `Clipboard.getData` and writes a temp `.csv` file via
//   `path_provider.getTemporaryDirectory`.
// - The "Import from file" row reads the file the user picks; soft-fails
//   on any error. SnackBar feedback only — never throws.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../repositories/recipe_repository.dart';
import '../screens/recipes/recipe_import_landing_screen.dart';
import '../screens/settings/ai_settings_screen.dart';
import '../services/cloud_backup.dart';
import '../services/drive_backup_service.dart';
import '../services/icloud_backup_service.dart';
import '../services/loadout_file_import_service.dart';
import '../services/onedrive_backup_service.dart';
import '../services/onedrive_config.dart';
import 'range_day_safety.dart';

/// Re-usable "Import recipes" collapsible section. Collapsed by default.
///
/// Drop into either form's body inside its existing scroll view — the
/// widget itself is a `Card` so it sits well next to other Material
/// surfaces.
class ImportOptionsSection extends StatelessWidget {
  const ImportOptionsSection({
    super.key,
    this.onImported,
  });

  /// Optional callback fired after a successful "Import from file"
  /// inserts at least one recipe. Lets the caller pop, refresh, or
  /// otherwise reflect the new rows. The other paths push their own
  /// review screen and don't return here.
  final ValueChanged<int>? onImported;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        // Use a stable PageStorageKey so a parent ListView's scrolling
        // doesn't forget the collapse/expand state on rebuilds.
        key: const PageStorageKey<String>('recipe_import_options_section'),
        initiallyExpanded: false,
        leading: Icon(
          Icons.download_outlined,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          'Import recipes',
          style: theme.textTheme.titleSmall,
        ),
        subtitle: const Text(
          'Bring in loads from spreadsheets, photos, files, the '
          'cloud, or another LoadOut device',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
        children: [
          // Phase One Group 5 (2026-05-14): single canonical entry
          // point that owns the source-detection logic. The landing
          // screen surfaces every recipe-import source — spreadsheet,
          // photo, file, clipboard, QR, plus Coming Soon tiles for
          // Word / OneNote / Garmin Xero photo. See
          // `recipe_import_landing_screen.dart` and
          // `recipe_import_source.dart`.
          _ImportRow(
            icon: Icons.download_outlined,
            title: 'Import a Recipe',
            subtitle:
                'Spreadsheet, photo, file, clipboard, or QR. The '
                'landing screen detects the source from your input.',
            onTap: () => _openRecipeImportLanding(context),
          ),
          _ImportRow(
            icon: Icons.auto_awesome_outlined,
            title: 'AI Smart Import (Pro)',
            subtitle:
                'Improve a low-confidence parse by asking the AI to '
                'translate OCR text into clean fields.',
            onTap: () => _openAiSmartImport(context),
          ),
          _CloudImportRow(
            icon: Icons.cloud_outlined,
            title: 'Import from iCloud Drive',
            subtitle:
                'Open a LoadOut export saved to your iCloud Drive.',
            providerFactory: (_) => ICloudBackupService(),
            onImported: onImported,
          ),
          _CloudImportRow(
            icon: Icons.cloud_outlined,
            title: 'Import from Google Drive',
            subtitle:
                'Open a LoadOut export saved to your Google Drive.',
            providerFactory: (_) => DriveBackupService(),
            onImported: onImported,
          ),
          if (!OneDriveConfig.isPlaceholder)
            _CloudImportRow(
              icon: Icons.cloud_outlined,
              title: 'Import from OneDrive',
              subtitle:
                  'Open a LoadOut export saved to your OneDrive.',
              providerFactory: (_) => OneDriveBackupService(),
              onImported: onImported,
            ),
        ],
      ),
    );
  }

  // ─────────────── route handlers ───────────────

  /// Push the canonical "Import a Recipe" landing screen.
  ///
  /// All six recipe-import paths that used to live as separate
  /// tiles on this widget (spreadsheet, photo, QR, LoadOut JSON,
  /// another-app CSV, clipboard) are now routed from the landing
  /// screen. Forward [onImported] so the QR + JSON paths can
  /// trigger a host-list refresh on success.
  Future<void> _openRecipeImportLanding(BuildContext context) async {
    await RecipeImportLandingScreen.push(
      context,
      onImported: onImported,
    );
  }

  Future<void> _openAiSmartImport(BuildContext context) async {
    // Routes through the AI settings screen so the user can confirm /
    // enable the master toggle and pick BYOK vs hosted. The actual
    // "Improve with AI" action lives on the photo-import review path.
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
    );
  }
}

/// Plain Material list-tile shape used for every static (non-cloud)
/// row. Cloud rows share the visuals but compute availability up front
/// so they can hide themselves on platforms where the provider isn't
/// usable.
class _ImportRow extends StatelessWidget {
  const _ImportRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Cloud-specific row. Probes the provider's `isAvailable()` once on
/// build and renders the row only when it is — otherwise returns a
/// `SizedBox.shrink` so the section stays clean.
///
/// Tapping the row pulls the latest backup, decrypts it (no — the
/// encrypted flow lives in the Backup screen), and routes to the
/// regular file-import path. To keep the implementation honest we
/// instead surface a hand-off SnackBar pointing the user at the
/// Backup screen — encrypted blobs require a passphrase the user
/// owns and we don't want to fork that flow into this widget.
class _CloudImportRow extends StatefulWidget {
  const _CloudImportRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.providerFactory,
    this.onImported,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final CloudBackupProvider Function(BuildContext) providerFactory;
  final ValueChanged<int>? onImported;

  @override
  State<_CloudImportRow> createState() => _CloudImportRowState();
}

class _CloudImportRowState extends State<_CloudImportRow> {
  // Tri-state availability: null (loading), true (visible), false (hide).
  bool? _available;

  @override
  void initState() {
    super.initState();
    // Soft-probe: any failure inside `isAvailable()` falls through to
    // hiding the row.
    // ignore: discarded_futures
    _probe();
  }

  Future<void> _probe() async {
    try {
      final ok = await widget.providerFactory(context).isAvailable();
      if (!mounted) return;
      setState(() => _available = ok);
    } catch (_) {
      if (!mounted) return;
      setState(() => _available = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_available == null || _available == false) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(widget.icon, color: theme.colorScheme.primary),
      title: Text(widget.title),
      subtitle: Text(widget.subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _runCloudImport(context),
    );
  }

  Future<void> _runCloudImport(BuildContext context) async {
    final repo = context.read<RecipeRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final provider = widget.providerFactory(context);

    final blobs = await safeAsync<List<CloudBackupMetadata>?>(
      context,
      body: () async => provider.list(),
      userMessage: "Couldn't list backups in this provider.",
    );
    if (blobs == null) return;
    if (blobs.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'No backups found in ${provider.displayName}. '
            'For encrypted backups, use Settings → Backup.',
          ),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    final picked = await showModalBottomSheet<CloudBackupMetadata>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text(
                  'Pick a file from ${provider.displayName}',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: blobs.length,
                  itemBuilder: (_, i) {
                    final m = blobs[i];
                    final stamp = m.modifiedAt?.toLocal().toString() ?? '';
                    return ListTile(
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text(m.filename),
                      subtitle: Text(
                        '${(m.size / 1024).toStringAsFixed(1)} KB '
                        '${stamp.isEmpty ? '' : '· $stamp'}',
                      ),
                      onTap: () => Navigator.of(ctx).pop(m),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    if (!context.mounted) return;

    final blob = await safeAsync<List<int>?>(
      context,
      body: () async => provider.download(picked),
      userMessage: 'Could not download that file.',
    );
    if (blob == null) return;

    // Encrypted backups land here with the `.lo1` extension — those
    // require the user's passphrase, which lives on the Backup
    // screen's restore flow. Surface a helpful hand-off rather than
    // forking the encryption UI into this widget.
    final filename = picked.filename.toLowerCase();
    if (filename.endsWith('.lo1')) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Encrypted backup detected. Open Settings → Backup '
            'and use Restore to enter your passphrase.',
          ),
        ),
      );
      return;
    }

    if (!context.mounted) return;

    // Plain JSON / .loadout export — feed straight through the file
    // importer for the soft-fail summary semantics.
    final summaryFn = LoadoutFileImportService(repo).importFromJson;
    final result = await safeAsync<LoadoutFileImportResult?>(
      context,
      body: () async {
        final text = String.fromCharCodes(blob);
        return summaryFn(text);
      },
      userMessage: 'That file did not look like a LoadOut export.',
    );
    if (result == null) return;
    final summary = result.snackbarSummary();
    if (summary.isNotEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(summary)));
    }
    if (result.imported > 0) {
      widget.onImported?.call(result.imported);
    }
  }
}
