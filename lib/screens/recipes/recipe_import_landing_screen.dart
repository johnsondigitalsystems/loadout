// FILE: lib/screens/recipes/recipe_import_landing_screen.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Single canonical entry point for "import a recipe." Replaces the
// scattered set of import tiles that used to live inside
// `ImportOptionsSection` with one screen showing every supported
// source, plus a Coming Soon block listing sources we'll wire later.
//
// The user picks the SOURCE (photo, file, clipboard, QR); the
// screen resolves the source kind by examining the input (file
// extension for the file picker, MIME for photos, clipboard
// content shape for paste). Per-source flows are unchanged — this
// screen is a router, not a rewrite. Spreadsheet picks push
// [SpreadsheetImportScreen], photo picks push [PhotoImportScreen]
// → [PhotoImportReviewScreen], QR picks push
// [RecipeQrScanScreen], etc.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Before Phase One Group 5, every "import a recipe" affordance had
// its own tile inside `ImportOptionsSection`, which itself was
// dropped into both Quick Add and the full recipe form. That gave
// us seven tile entries per screen, overlapping subtitles, and a
// growth problem — every new import source needed a parallel tile
// added to the section. Three pairs of eyes (chat-Claude,
// operator, Claude Code) converged on the same fix: collapse the
// affordances behind a single canonical entry point, surface
// every source on ONE screen, and detect the source from the
// input rather than the menu pick.
//
// The shape buys us:
//   - Discoverability (every supported source is on one screen).
//   - Honest "Coming Soon" surface (Word, OneNote, Garmin Xero
//     photo) instead of pretending those don't exist.
//   - One place to add a new source: append to the
//     [RecipeImportSourceKind] enum, add a case in `_routeFor`,
//     update the source-taxonomy table in Engineering.md § 19.4.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// - **Photo tiles are platform-conditional.** ML Kit text
//   recognition is iOS/Android only. The tiles render only when
//   `PhotoImportScreen.isSupportedPlatform` is true; on macOS /
//   web the user sees the file / clipboard / QR tiles but no
//   photo path.
// - **Source detection from input, not menu picks.** A file picker
//   round-trips through `detectKindFromFileExtension` — `.csv` /
//   `.xlsx` / `.xls` route to the spreadsheet wizard, `.json`
//   routes to the LoadOut JSON re-import, `.fit` is informational
//   today (the live route lives on the recipe form's Pro Tools
//   section). Coming Soon extensions (`.docx`, `.one`) match the
//   helper but `_routeFor` shows a "we're working on it" snackbar
//   rather than pretending to import.
// - **Coming Soon tiles render visible-but-disabled.** A user
//   browsing the screen sees what we plan to add next; tap is a
//   no-op (`onTap: null`). This is deliberate per spec —
//   discoverability beats surprise.
// - **Garmin .fit landing-screen route is deferred.** The recipe
//   form's inline `_onImportGarminFit` is heavily entangled with
//   form state (notes controller, chronograph controller,
//   autosave wiring). Extracting it to a context-free service
//   helper is a bigger refactor than Group 5 scope; the landing
//   screen handles `.fit` by surfacing a SnackBar that points the
//   user at the recipe form. Phase Two completes the route.
// - **Clipboard route materialises text to a temp `.csv`** before
//   pushing `SpreadsheetImportScreen(initialFile:)`. The wizard
//   already handles fuzzy header detection — no special clipboard-
//   shaped parser needed.
// - **Soft failure throughout.** Every async path is wrapped with
//   try/catch + a SnackBar; a thrown exception never reaches the
//   user as a red screen. The patterns mirror the
//   `safeAsync`-wrapped paths inside `ImportOptionsSection` for
//   the per-source flows that already shipped.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `lib/widgets/import_options_section.dart` — the shim that
//   pushes this screen from Quick Add and the recipe form.
// - Future direct call sites: the Recipes list FAB sheet,
//   onboarding deep links, "Bring Your Existing Data" cards.
//   Add them by calling `RecipeImportLandingScreen.push(context,
//   onImported: ...)`.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Pushes per-source routes via `Navigator.of(context).push`.
// - Reads the OS clipboard via `Clipboard.getData` on the paste
//   tile.
// - Writes a temp `.csv` to the app's temporary directory on the
//   clipboard path (via `path_provider.getTemporaryDirectory`).
// - Picks files via `FilePicker.platform.pickFiles`.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../repositories/recipe_repository.dart';
import '../../services/loadout_file_import_service.dart';
import 'photo_import_screen.dart';
import 'recipe_import_source.dart';
import 'recipe_qr_scan_screen.dart';
import 'spreadsheet_import_screen.dart';

/// Canonical "Import a Recipe" entry point. Push from anywhere the
/// app surfaces a "bring a recipe in" affordance.
///
/// The screen routes the user to the appropriate per-source flow.
/// On a successful recipe insert (currently only QR + JSON re-
/// import populate this), [onImported] fires with the number of
/// recipes inserted so the host can refresh its list.
class RecipeImportLandingScreen extends StatelessWidget {
  const RecipeImportLandingScreen({super.key, this.onImported});

  /// Optional callback fired after a successful import that
  /// inserts at least one recipe directly from the landing
  /// screen's flow. The QR path forwards count == 1; the LoadOut
  /// JSON re-import forwards the row count. Spreadsheet / photo
  /// flows manage their own list refresh via their per-source
  /// screens and do NOT fire this callback.
  final ValueChanged<int>? onImported;

  /// Convenience for callers. Avoids ad-hoc
  /// `MaterialPageRoute(builder: ...)` boilerplate at every
  /// callsite.
  static Future<void> push(
    BuildContext context, {
    ValueChanged<int>? onImported,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RecipeImportLandingScreen(onImported: onImported),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPhoto = PhotoImportScreen.isSupportedPlatform;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import a Recipe'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Bring a recipe in from anywhere',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'LoadOut never sends your reloading data anywhere. '
              'Imports stay on this device.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (isPhoto) ...[
              _LandingTile(
                icon: Icons.photo_camera_outlined,
                title: 'Take a Photo',
                subtitle:
                    'Capture a notebook page; on-device OCR fills the form.',
                onTap: () => _routeFor(
                  context,
                  RecipeImportSourceKind.photoSingle,
                ),
              ),
              _LandingTile(
                icon: Icons.photo_library_outlined,
                title: 'Pick From Gallery',
                subtitle:
                    'One or more photos already in your camera roll.',
                onTap: () => _routeFor(
                  context,
                  RecipeImportSourceKind.photoSingle,
                ),
              ),
            ],
            _LandingTile(
              icon: Icons.folder_open_outlined,
              title: 'Choose a File',
              subtitle:
                  'CSV · Excel (.xlsx / .xls) · LoadOut export (.json)',
              onTap: () => _openFilePicker(context),
            ),
            _LandingTile(
              icon: Icons.content_paste_outlined,
              title: 'Paste From Clipboard',
              subtitle:
                  'CSV-shaped text. We stage it as a temp file and route '
                  'through the spreadsheet wizard.',
              onTap: () => _routeFor(
                context,
                RecipeImportSourceKind.clipboard,
              ),
            ),
            _LandingTile(
              icon: Icons.qr_code_scanner_outlined,
              title: 'Scan a Recipe QR',
              subtitle:
                  'Recipes shared from another LoadOut user as a QR code.',
              onTap: () => _routeFor(
                context,
                RecipeImportSourceKind.qrCode,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Coming Soon',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            const _LandingTile(
              icon: Icons.description_outlined,
              title: 'Microsoft Word Document',
              subtitle: '`.docx` / `.doc` — Phase Two.',
              onTap: null,
            ),
            const _LandingTile(
              icon: Icons.book_outlined,
              title: 'Microsoft OneNote',
              subtitle:
                  '`.one` — realistic path is export to `.docx` first.',
              onTap: null,
            ),
            const _LandingTile(
              icon: Icons.timer_outlined,
              title: 'Garmin Xero Chronograph Photo',
              subtitle:
                  'OCR a photo of the Xero display. Complement to `.fit` import.',
              onTap: null,
            ),
            const SizedBox(height: 16),
            Text(
              'Already have a recipe open?',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Garmin Xero `.fit` chronograph data is imported from the '
              'recipe form (Pro Tools section) so it attaches directly to '
              "the load you're editing.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Routing
  // ──────────────────────────────────────────────────────────────

  Future<void> _openFilePicker(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx', 'xls', 'json', 'fit'],
        withData: false,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't open the file picker: $e")),
      );
      return;
    }
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final path = file.path;
    if (path == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't read the selected file.")),
      );
      return;
    }
    final kind = detectKindFromFileExtension(file.name);
    if (kind == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Unsupported file type: "${file.name}". Try CSV, Excel, '
            'LoadOut JSON export, or Garmin .fit.',
          ),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    await _routeFor(context, kind, file: File(path));
  }

  Future<void> _routeFor(
    BuildContext context,
    RecipeImportSourceKind kind, {
    File? file,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    switch (kind) {
      case RecipeImportSourceKind.spreadsheet:
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => SpreadsheetImportScreen(initialFile: file),
          ),
        );
        return;

      case RecipeImportSourceKind.photoSingle:
      case RecipeImportSourceKind.photoMultiPage:
        // Both photo kinds funnel through PhotoImportScreen — the
        // capture screen's source picker (camera vs gallery) is
        // the right place to disambiguate single vs multi-page.
        await Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const PhotoImportScreen()),
        );
        return;

      case RecipeImportSourceKind.loadoutJson:
        if (file == null) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Re-open the file picker to choose a .json.'),
            ),
          );
          return;
        }
        if (!context.mounted) return;
        await _runLoadoutJsonReimport(context, file);
        return;

      case RecipeImportSourceKind.qrCode:
        final result = await Navigator.of(context).push<RecipeQrScanResult?>(
          RecipeQrScanScreen.route(),
        );
        if (result != null) {
          onImported?.call(1);
        }
        return;

      case RecipeImportSourceKind.clipboard:
        await _runClipboardImport(context);
        return;

      case RecipeImportSourceKind.garminFit:
        // Live route deferred — see file header. Point the user
        // at the recipe form's Pro Tools section where the
        // existing inline handler lives.
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              "Garmin .fit imports attach to a specific recipe — open "
              "the recipe form's Pro Tools section to import.",
            ),
          ),
        );
        return;

      case RecipeImportSourceKind.msWordDoc:
      case RecipeImportSourceKind.msOneNote:
      case RecipeImportSourceKind.garminXeroPhoto:
        // Reached when the file picker matched a Coming Soon
        // extension. Surface a friendly snackbar; the tile itself
        // is disabled in the UI so direct taps don't land here.
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              "We're working on this. Try exporting to CSV or Excel "
              "in the meantime.",
            ),
          ),
        );
        return;
    }
  }

  Future<void> _runLoadoutJsonReimport(
      BuildContext context, File file) async {
    final repo = context.read<RecipeRepository>();
    final messenger = ScaffoldMessenger.of(context);
    LoadoutFileImportResult? outcome;
    try {
      // `LoadoutFileImportService.importFromJson` takes a JSON
      // string; read the file the user already picked rather than
      // bouncing them through the service's own
      // `pickAndImportRecipes()` (which would re-open the system
      // file picker — bad UX since we already have the file).
      final json = await file.readAsString();
      outcome = await LoadoutFileImportService(repo).importFromJson(json);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't import that file: $e")),
      );
      return;
    }
    if (outcome.cancelled) return;
    final summary = outcome.snackbarSummary();
    if (summary.isNotEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(summary)));
    }
    if (outcome.imported > 0) {
      onImported?.call(outcome.imported);
    }
  }

  Future<void> _runClipboardImport(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    ClipboardData? clipboard;
    try {
      clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't read the clipboard: $e")),
      );
      return;
    }
    final text = clipboard?.text?.trim();
    if (text == null || text.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Clipboard is empty. Copy CSV-shaped text first, then try '
            'again.',
          ),
        ),
      );
      return;
    }
    File tempFile;
    try {
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      tempFile = File('${dir.path}/loadout-clipboard-$stamp.csv');
      await tempFile.writeAsString(text, flush: true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't stage the pasted text: $e")),
      );
      return;
    }
    if (!context.mounted) return;
    await navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => SpreadsheetImportScreen(
          initialFile: tempFile,
          titleOverride: 'Import from clipboard',
        ),
      ),
    );
  }
}

/// Visual building block for the landing screen. Static rows
/// (always render) and Coming Soon rows (visible-but-disabled,
/// `onTap: null`).
class _LandingTile extends StatelessWidget {
  const _LandingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = onTap == null;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      elevation: disabled ? 0 : 1,
      child: ListTile(
        leading: Icon(
          icon,
          color: disabled ? muted : theme.colorScheme.primary,
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: disabled ? muted : null,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: disabled
            ? Chip(
                label: const Text('Coming Soon'),
                visualDensity: VisualDensity.compact,
                labelStyle: theme.textTheme.labelSmall,
              )
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
