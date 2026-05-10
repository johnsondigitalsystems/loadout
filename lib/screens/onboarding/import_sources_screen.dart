// FILE: lib/screens/onboarding/import_sources_screen.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Dedicated picker screen showing every supported import source for an
// existing reloader bringing data into LoadOut. Reachable from the
// onboarding deck's "Bring Your Existing Data" slide and from the
// drawer / Backup screen as a permanent home.
//
// Each row is a tappable card with an icon, a Title-Case label, a
// short description, and a routing handler. Sources:
//
//   * Photo                — opens [PhotoImportScreen] (existing OCR flow).
//   * CSV / Excel          — opens [SmartImportScreen] (.csv + .xlsx).
//   * Notes / Text File    — file picker for `.txt`, plain UTF-8 read,
//                            parsed via [RecipeParser], pushed to the
//                            existing review screen.
//   * PDF Document         — file picker for `.pdf`, rasterise + OCR
//                            via [TextImportService], parser, review.
//                            iOS / Android only.
//   * Word Document        — guide dialog ("export to .pdf or .txt
//                            from Word, then pick that file") followed
//                            by the same file picker.
//   * Microsoft OneNote    — guide dialog ("OneNote → Share → Export
//                            Page → choose .pdf / .txt / .docx, then
//                            pick that file") followed by the same
//                            file picker.
//   * Apple Notes          — instructions-only card; the inbound
//                            share-intent listener (registered in
//                            [AppEntry]) takes over once the user
//                            shares text from the Notes share sheet.
//                            See `lib/services/share_handler_service.dart`.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The previous onboarding "Bring your data" slide carried only two
// buttons (spreadsheet + photo) hard-coded into the page widget,
// which left no room to surface the four new formats the user
// asked for (plus Apple Notes, plus PDF). Lifting the picker out
// of the slide into its own screen keeps the onboarding deck
// scannable AND makes the picker re-usable from the drawer / Backup
// screen ("Import Existing Data" entry) without duplicating the UI.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * Two of the rows (Word, OneNote) don't import directly — they
//     show a guide-then-pick flow because the source apps' file
//     formats are either inaccessible (OneNote's `.one` is
//     proprietary + cloud-stored) or strategically not worth
//     parsing in-app (`.docx` is a zip of XML; the export is
//     trivially user-driven and yields a file we already handle).
//     The guide dialogs are first-class — they're the actual UX,
//     not an error fallback.
//   * Apple Notes intentionally has no in-screen file picker. Apple
//     Notes is a closed sandbox app — the only public way to
//     extract its text is the iOS Share Sheet. The card's job is
//     to TEACH the user how to invoke it, not to launch it. The
//     actual handoff lives in [ShareHandlerService] which fires
//     a navigator push the moment shared text arrives.
//   * Platform gating: PDF requires ML Kit (iOS / Android only).
//     Apple Notes Share Sheet is iOS-only by name (Android users
//     would use the equivalent Android share menu from any notes
//     app — same `share_handler` plugin). Word / OneNote guides
//     are platform-agnostic. CSV / photo gate via their own
//     existing isSupportedPlatform checks.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/onboarding/onboarding_screen.dart — "Bring Your
//   Existing Data" slide's primary button.
// - Future: drawer / backup screen entry "Import Existing Data".
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Pushes [SmartImportScreen], [PhotoImportScreen], or
//   [PhotoImportReviewScreen] (with a draft) onto the navigator
//   depending on the user's pick.
// - For text / PDF / guide-then-pick paths, opens the OS file picker
//   via `file_picker`.
// - Reads from SQLite (component catalog) when building a parser via
//   [TextImportService.buildParser].

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/text_import_service.dart';
import '../recipes/photo_import_review_screen.dart';
import '../recipes/photo_import_screen.dart';
import '../recipes/smart_import_screen.dart';

class ImportSourcesScreen extends StatefulWidget {
  const ImportSourcesScreen({super.key});

  @override
  State<ImportSourcesScreen> createState() => _ImportSourcesScreenState();
}

class _ImportSourcesScreenState extends State<ImportSourcesScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pdfAvailable = TextImportService.pdfImportSupported;
    final photoAvailable = PhotoImportScreen.isSupportedPlatform;
    return Scaffold(
      appBar: AppBar(title: const Text('Import Existing Data')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Pick the format you have. We support recipes from '
                    "spreadsheets, photos, documents, notes — pick "
                    "whichever matches what you've already got.",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _ImportSourceCard(
                  icon: Icons.camera_alt_outlined,
                  title: 'Photo',
                  description: photoAvailable
                      ? "Snap a photo of a notebook page, recipe card, "
                          "or printed load-data sheet."
                      : "Photo import isn't available on this platform — "
                          "use a phone or tablet.",
                  enabled: photoAvailable,
                  onTap: _openPhoto,
                ),
                _ImportSourceCard(
                  icon: Icons.table_chart_outlined,
                  title: 'CSV or Excel',
                  description: 'Map columns from any spreadsheet '
                      'to LoadOut fields.',
                  onTap: _openSpreadsheet,
                ),
                _ImportSourceCard(
                  icon: Icons.description_outlined,
                  title: 'Notes or Text File',
                  description: 'Plain-text export from any notes app — '
                      'iOS Notes, Bear, Obsidian, OneNote, anything.',
                  onTap: _pickAndImportTextFile,
                ),
                _ImportSourceCard(
                  icon: Icons.picture_as_pdf_outlined,
                  title: 'PDF Document',
                  description: pdfAvailable
                      ? 'Any PDF — manufacturer load tables, scanned '
                          "notebook pages, exported documents."
                      : "PDF import isn't available on this platform — "
                          "use a phone or tablet.",
                  enabled: pdfAvailable,
                  onTap: _pickAndImportPdfFile,
                ),
                _ImportSourceCard(
                  icon: Icons.article_outlined,
                  title: 'Word Document',
                  description: "We don't read .docx directly — export "
                      'to PDF or text first, then pick the file.',
                  onTap: _showWordExportGuide,
                ),
                _ImportSourceCard(
                  icon: Icons.menu_book_outlined,
                  title: 'OneNote',
                  description: 'Export the page from OneNote first — '
                      "we'll walk you through it.",
                  onTap: _showOneNoteExportGuide,
                ),
                _ImportSourceCard(
                  icon: Icons.share_outlined,
                  title: 'Apple Notes (Share to LoadOut)',
                  description: 'Open a note in Apple Notes, tap Share, '
                      'pick LoadOut. Works for any app that shares text.',
                  onTap: _showAppleNotesGuide,
                ),
              ],
            ),
            if (_busy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x66000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Routing handlers
  // ───────────────────────────────────────────────────────────────────

  void _openPhoto() {
    if (!PhotoImportScreen.isSupportedPlatform) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PhotoImportScreen()),
    );
  }

  void _openSpreadsheet() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SmartImportScreen()),
    );
  }

  Future<void> _pickAndImportTextFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'text', 'md', 'markdown', 'rtf'],
      withData: false,
    );
    if (picked == null || picked.files.isEmpty || !mounted) return;
    final path = picked.files.single.path;
    if (path == null) {
      _showErrorSnack("Couldn't read the selected file.");
      return;
    }
    await _runWithBusy(() async {
      final text = await TextImportService.readTextFile(File(path));
      if (text == null || text.trim().isEmpty) {
        _showErrorSnack(
          "We couldn't find any text in that file. "
          'Make sure it\'s a plain-text or markdown export.',
        );
        return;
      }
      await _parseAndPushReview(text);
    });
  }

  Future<void> _pickAndImportPdfFile() async {
    if (!TextImportService.pdfImportSupported) {
      _showErrorSnack(
        "PDF import requires iOS or Android — try Photo import instead.",
      );
      return;
    }
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: false,
    );
    if (picked == null || picked.files.isEmpty || !mounted) return;
    final path = picked.files.single.path;
    if (path == null) {
      _showErrorSnack("Couldn't read the selected file.");
      return;
    }
    await _runWithBusy(() async {
      try {
        final text = await TextImportService.rasterizeAndOcrPdf(File(path));
        if (text == null || text.trim().isEmpty) {
          _showErrorSnack(
            "We couldn't find any readable text in that PDF. "
            'If it\'s a scan, try cropping individual pages and using '
            'the Photo import instead.',
          );
          return;
        }
        await _parseAndPushReview(text);
      } catch (e) {
        _showErrorSnack("Couldn't read that PDF: $e");
      }
    });
  }

  // ───────────────────────────────────────────────────────────────────
  // Guide dialogs (Word / OneNote / Apple Notes)
  // ───────────────────────────────────────────────────────────────────

  Future<void> _showWordExportGuide() async {
    final picked = await _showExportGuide(
      title: 'Import From Microsoft Word',
      icon: Icons.article_outlined,
      intro: "We don't read Word's .docx format directly. The cleanest "
          'path is to export your document to PDF or plain text first, '
          'then pick the file here.',
      steps: const [
        'Open the document in Microsoft Word.',
        'File → Save As (or Export).',
        'Choose PDF (.pdf) or Plain Text (.txt) as the format.',
        'Save the file somewhere you can find it (Desktop, Files app).',
        'Come back here and tap Pick File.',
      ],
      pickButtonLabel: 'Pick File',
    );
    if (!picked || !mounted) return;
    await _pickFromAnyExportedFormat();
  }

  Future<void> _showOneNoteExportGuide() async {
    final picked = await _showExportGuide(
      title: 'Import From OneNote',
      icon: Icons.menu_book_outlined,
      intro: "OneNote pages live in Microsoft's cloud — we can't read "
          'them directly. Export the page first, then pick the file.',
      steps: const [
        'Open the page in OneNote.',
        'Tap the Share button (or File → Export on desktop).',
        'Choose Export Page → PDF or Word.',
        'Save the file somewhere you can find it (Files app, Desktop).',
        'Come back here and tap Pick File.',
      ],
      pickButtonLabel: 'Pick File',
    );
    if (!picked || !mounted) return;
    await _pickFromAnyExportedFormat();
  }

  Future<void> _showAppleNotesGuide() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.share_outlined, size: 28),
        title: const Text('Share From Apple Notes'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Apple Notes doesn't expose your notes to other apps "
                "directly — but the iOS Share Sheet does. Once shared, "
                "LoadOut opens straight into the recipe review screen "
                "with your note pre-parsed.",
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              const _NumberedSteps(steps: [
                'Open the note in Apple Notes.',
                'Tap the Share button (top right).',
                'Pick LoadOut from the share sheet.',
                "We'll open the recipe review screen with your "
                    'text already parsed.',
              ]),
              const SizedBox(height: 12),
              Text(
                "If LoadOut doesn't appear in the share sheet, scroll "
                "the row of apps and tap More — toggle LoadOut on.",
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color:
                          Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  /// Generic guide-and-then-pick dialog used by both the Word and
  /// OneNote flows. Returns true when the user tapped "Pick File"
  /// (caller then opens the file picker), false on dismiss.
  Future<bool> _showExportGuide({
    required String title,
    required IconData icon,
    required String intro,
    required List<String> steps,
    required String pickButtonLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(icon, size: 28),
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(intro,
                  style: Theme.of(ctx).textTheme.bodyMedium),
              const SizedBox(height: 12),
              _NumberedSteps(steps: steps),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(pickButtonLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// File picker used after the Word / OneNote guide. Accepts the
  /// formats that both export flows commonly produce: PDF (any),
  /// plain text, and (on Android) `.docx` — Word's own zip format
  /// occasionally lands here when the user "saves as" without
  /// converting. We attempt a UTF-8 read on `.docx` as a courtesy
  /// — it will read the raw zipped XML which is mostly junk, but
  /// the parser is tolerant and may still find a recipe if the
  /// document is small.
  Future<void> _pickFromAnyExportedFormat() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'txt', 'text', 'md', 'rtf', 'docx'],
      withData: false,
    );
    if (picked == null || picked.files.isEmpty || !mounted) return;
    final path = picked.files.single.path;
    if (path == null) {
      _showErrorSnack("Couldn't read the selected file.");
      return;
    }
    final lower = path.toLowerCase();
    await _runWithBusy(() async {
      String? text;
      if (lower.endsWith('.pdf')) {
        if (!TextImportService.pdfImportSupported) {
          _showErrorSnack(
            "PDF import requires iOS or Android — export to text "
            "instead, or open this file on a phone.",
          );
          return;
        }
        try {
          text = await TextImportService.rasterizeAndOcrPdf(File(path));
        } catch (e) {
          _showErrorSnack("Couldn't read that PDF: $e");
          return;
        }
      } else {
        text = await TextImportService.readTextFile(File(path));
      }
      if (text == null || text.trim().isEmpty) {
        _showErrorSnack(
          "We couldn't find any readable text in that file.",
        );
        return;
      }
      await _parseAndPushReview(text);
    });
  }

  // ───────────────────────────────────────────────────────────────────
  // Common parse + push helper
  // ───────────────────────────────────────────────────────────────────

  Future<void> _parseAndPushReview(String text) async {
    final parser = await TextImportService.buildParser(context);
    if (!mounted) return;
    final draft = parser.parse(text);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoImportReviewScreen(
          draft: draft,
          imagePath: null,
          ocrText: text,
        ),
      ),
    );
  }

  Future<void> _runWithBusy(Future<void> Function() body) async {
    setState(() => _busy = true);
    try {
      await body();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _ImportSourceCard extends StatelessWidget {
  const _ImportSourceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 28,
                color: enabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.5),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: enabled
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled)
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Numbered step list rendered inside guide dialogs. Inline rather
/// than a generic widget because the styling is dialog-specific
/// (compact spacing, no leading icon since the dialog already has
/// one in the title row).
class _NumberedSteps extends StatelessWidget {
  const _NumberedSteps({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    '${i + 1}.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    steps[i],
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
