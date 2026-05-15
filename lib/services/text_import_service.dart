// FILE: lib/services/text_import_service.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Shared helper for the non-photo import paths (plain text, PDF, shared
// text intent, Word/OneNote-after-export). Three responsibilities:
//
//   1. Build a [RecipeParser] from the on-device reference catalog.
//      Mirrors the catalog-load pass at the top of `PhotoImportScreen`
//      so every import surface produces drafts of the same quality.
//
//   2. Read a `.txt` (or any plain-text) file as a UTF-8 string. Falls
//      back to Latin-1 on decode error so a user pulling text out of
//      Word / OneNote with a stray smart quote doesn't see an error.
//
//   3. Rasterise a PDF page-by-page via the existing `printing` package
//      (already in pubspec for recipe-export PDFs) and OCR each page
//      with ML Kit. The OCR output is concatenated newline-separated
//      so the parser sees the document as one block of text. Works
//      for both digital PDFs (rasterized text round-trips cleanly
//      through OCR) and scanned PDFs (the only path that reads them
//      at all). Returns the joined text.
//
// The orchestration screen (`ImportSourcesScreen`) is responsible for:
//   - Opening the file picker.
//   - Calling these helpers.
//   - Pushing `PhotoImportReviewScreen` with the resulting draft.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The photo-import flow already has the OCR + parse + review chain.
// Without this helper, every new import surface (text, PDF, share
// intent, future Word/OneNote direct support) would re-implement the
// "load catalog → build parser → read text → parse → push review"
// dance and drift apart. Centralising the text-input plumbing here
// keeps every surface producing identical `RecipeDraft` shape and
// hitting the same review screen.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * `printing` returns one `PdfRaster` per page — we have to manage
//     the iteration ourselves, write each page out as a temp PNG so
//     `InputImage.fromFile()` can find it, and remember to delete the
//     temps on success / failure. Skipping the cleanup leaks ~1MB per
//     page in the OS temp directory across many imports.
//   * `TextRecognizer` holds a native ML Kit handle — we instantiate
//     ONE recogniser per call and `close()` it in a `finally` so the
//     native side doesn't leak across long PDFs.
//   * `printing.Printing.raster()` ships full implementations on iOS,
//     Android, macOS, Linux, Windows and web. ML Kit, however, is
//     iOS+Android only. So PDF import gates on the same platform
//     check the photo-import screen uses (`PhotoImportScreen
//     .isSupportedPlatform`). The text-file helper has no such
//     restriction — it's pure Dart `File.readAsString`.
//   * UTF-8 decode failures are not rare. Word / OneNote / Notes
//     exports can carry non-UTF-8 bytes (smart quotes from old
//     Mac-Roman files, BOM-prefixed UTF-16 from Windows). We fall
//     back to Latin-1 (lossy but never throws) so the user never
//     sees a "not a text file" error on what is, by their lights,
//     a perfectly normal note.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/onboarding/import_sources_screen.dart — the new picker
//   that surfaces every supported import path on the welcome page.
// - lib/services/share_handler_service.dart (forthcoming) — the
//   inbound-share-intent listener that routes pasted / shared text
//   through `RecipeParser` without touching the file system.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Reads from SQLite via the `ComponentRepository` to build the
//   parser's catalog hints. No writes.
// - When OCR-ing a PDF, writes one temp PNG per page to the system
//   temp directory and deletes them before returning.
// - Holds a native ML Kit `TextRecognizer` for the duration of a PDF
//   OCR call; `close()`d in a `finally` block.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../repositories/component_repository.dart';
import 'recipe_parser.dart';

class TextImportService {
  TextImportService();

  /// Build a [RecipeParser] from the live on-device reference catalog.
  /// The pass mirrors `PhotoImportScreen._loadCatalog` so every
  /// non-photo import surface yields drafts of the same quality as
  /// photo OCR. Pulled into a service so the new ImportSources flow
  /// doesn't have to re-implement the same wiring.
  static Future<RecipeParser> buildParser(BuildContext context) async {
    final components = context.read<ComponentRepository>();
    final cartridges = await components.allCartridges();
    final powderLabels = await components.componentLabels('powder');
    final bullets = await components.allBulletsWithManufacturer();
    final primers = await components.componentLabels('primer');
    final brassMfgs = await components.manufacturersForKind('brass');

    // Decode the JSON-encoded `aliasesJson` text column. Defensive
    // try/catch — bad seed data shouldn't crash the import.
    final cartridgeAliases = <String, List<String>>{};
    for (final c in cartridges) {
      try {
        final raw = c.aliasesJson;
        if (raw.isEmpty) {
          cartridgeAliases[c.name] = const <String>[];
          continue;
        }
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          cartridgeAliases[c.name] = [
            for (final v in decoded) v.toString(),
          ];
        } else {
          cartridgeAliases[c.name] = const <String>[];
        }
      } catch (_) {
        cartridgeAliases[c.name] = const <String>[];
      }
    }

    // Same powder-name canonicalisation as the photo screen:
    // include both "Hodgdon H4350" and "H4350" so a recipe that
    // names only the powder still matches. Phase Two Group 3
    // (2026-05-15) replaced the previous `label.split(' ')...`
    // prefix-strip with a direct read from `Powders.name` via
    // `componentNames('powder')` — the strip path broke for
    // two-word manufacturer names (`"Western Powders Ramshot
    // Hunter"` → `"Powders Ramshot Hunter"`) and produced empty
    // strings for bare-manufacturer labels (`"Lapua"` → `""`).
    final powderNames = <String>{
      ...powderLabels,
      ...await components.componentNames('powder'),
    };

    final bulletEntries = <BulletCatalogEntry>[
      for (final b in bullets)
        BulletCatalogEntry(
          manufacturer: b.mfg.name,
          line: b.bullet.line,
          weightGr: b.bullet.weightGr,
        ),
    ];

    return RecipeParser(
      cartridgeAliases: cartridgeAliases,
      powderNames: powderNames.toList(growable: false),
      bulletLines: bulletEntries,
      primerNames: primers,
      brassNames: brassMfgs,
    );
  }

  /// Read a plain-text file. Tries UTF-8 first; falls back to
  /// Latin-1 on decode failure (Word / OneNote / older Mac exports
  /// often carry non-UTF-8 bytes). Returns null if the file can't
  /// be read at all.
  static Future<String?> readTextFile(File file) async {
    try {
      // Read raw bytes once — UTF-8 / Latin-1 attempts are cheap
      // string-decode passes after that, no second disk hit.
      final bytes = await file.readAsBytes();
      try {
        return utf8.decode(bytes);
      } on FormatException {
        // Lossy but never throws. The OCR'd text is going through a
        // tolerant heuristic parser anyway, so a few mis-mapped
        // smart quotes don't change the outcome.
        return latin1.decode(bytes, allowInvalid: true);
      }
    } catch (_) {
      return null;
    }
  }

  /// Rasterise a PDF page-by-page (via `printing.Printing.raster`)
  /// and OCR each page with ML Kit. Returns the concatenated text,
  /// newline-separated between pages so the parser's line-based
  /// heuristics still trigger on per-page totals / labels.
  ///
  /// Returns null when the PDF reads back zero text — caller surfaces
  /// "no text found, try the photo-import flow" rather than passing
  /// an empty string into the parser. Throws on truly broken input
  /// (corrupt PDF, OCR engine failure) so the caller can show an
  /// error state.
  ///
  /// Platform support: iOS + Android only (matches `PhotoImportScreen
  /// .isSupportedPlatform` since ML Kit doesn't ship for desktop /
  /// web). Caller is responsible for the platform check.
  ///
  /// `dpi` defaults to 200 — high enough for ML Kit to read printed
  /// text reliably without ballooning per-page memory above ~5 MB
  /// for a typical letter-size page.
  static Future<String?> rasterizeAndOcrPdf(
    File pdfFile, {
    double dpi = 200,
  }) async {
    final bytes = await pdfFile.readAsBytes();
    final tempDir = await getTemporaryDirectory();
    final tempFiles = <File>[];
    final recogniser = TextRecognizer(
      script: TextRecognitionScript.latin,
    );
    try {
      final pages = <String>[];
      var pageIndex = 0;
      await for (final raster in Printing.raster(bytes, dpi: dpi)) {
        // `raster.toPng()` returns the page as a PNG-encoded
        // `Uint8List`. Write it to a temp file so `InputImage.fromFile`
        // can hand a path to the native ML Kit side.
        final pngBytes = await raster.toPng();
        final tmp = File(
          '${tempDir.path}/loadout_pdf_ocr_${DateTime.now().millisecondsSinceEpoch}_$pageIndex.png',
        );
        await tmp.writeAsBytes(pngBytes);
        tempFiles.add(tmp);
        pageIndex += 1;

        final input = InputImage.fromFile(tmp);
        final result = await recogniser.processImage(input);
        if (result.text.trim().isNotEmpty) {
          pages.add(result.text);
        }
      }
      if (pages.isEmpty) return null;
      // Join with double-newline so a downstream line-based parser
      // sees clean per-page boundaries.
      return pages.join('\n\n');
    } finally {
      await recogniser.close();
      for (final f in tempFiles) {
        try {
          if (await f.exists()) await f.delete();
        } catch (_) {
          // Temp-dir cleanup is best-effort; the OS will eventually
          // reclaim these on its own.
        }
      }
    }
  }

  /// True when the PDF rasterise+OCR path is available (iOS + Android).
  /// Other platforms can still import plain text and shared-intent
  /// content; PDF specifically requires ML Kit which only ships for
  /// the two mobile OSes.
  static bool get pdfImportSupported {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid;
  }
}
