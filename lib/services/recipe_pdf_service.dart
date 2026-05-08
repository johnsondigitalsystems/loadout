// FILE: lib/services/recipe_pdf_service.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Generates a polished, single-page-per-recipe PDF for one or many recipes
// and hands it to the OS share sheet via `share_plus`. Used by the Recipes
// list screen (multi-select → "Share as PDF") and the recipe form screen
// (toolbar "Share as PDF" action). The PDF is a portable, printable record
// reloaders forward to friends / forums / Discord, so visual quality is
// part of the marketing — every shared PDF is a pitch for the app.
//
// Public surface:
//
//   * `RecipePdfService()` — no-arg constructor.
//   * `buildSingleRecipePdfBytes(recipe)` — single-page PDF for one recipe.
//   * `buildMultiRecipePdfBytes(recipes)` — N-page PDF, one recipe per
//     page, with "Page i of N" footers. Pure functions; useful for tests.
//   * `share(context, recipe)` / `shareMultiple(context, recipes)` —
//     build, write to a temp file, surface the OS share sheet. Returns
//     when the share sheet was presented (the destination is the user's
//     choice and not visible to us).
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The original `RecipePrintService` formats recipes as plain text and
// pipes them through the share sheet — fast, dependency-light, but
// unmistakeably a programmer's text dump. Reloaders share these in
// forums and on Discord; the visual quality of the artifact has
// marketing value beyond the data it carries. A clean PDF with a brass
// brand block, sectioned data fields, and a QR code linking back to
// the app is a fundamentally better artifact for that purpose.
//
// The plain-text path stays alive as a secondary "Share as text" option
// for users who genuinely want a copy-pastable representation.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **Fonts.** The `pdf` package ships with the base PDF Type 1 fonts
//    (Helvetica, Times, Courier, Symbol, ZapfDingbats). Embedding a
//    Google Font would push the PDF size past 100 KB per page just for
//    the font data and add latency to the build call. We deliberately
//    use the built-ins: `Font.times()` for body / data fields (gives
//    the printed-record feel) and `Font.helvetica()` for the brand
//    wordmark, section headers, and small caps. No asset embedding,
//    no `flutter pub get` change, < 50 KB per page in practice.
//
// 2. **Empty fields must drop silently.** A reloader who fills in only
//    the basics shouldn't get a PDF dotted with "Powder Lot: ". The
//    `_kv` helper short-circuits on null / empty / zero-equivalent
//    values; the body only contributes a section if it has at least
//    one rendered row.
//
// 3. **Two-column body layout.** Reloading data is dense. A single
//    column wastes paper; three columns crams. Two columns of
//    `Field: value` pairs balance density with readability. We pack
//    each section into a left column then a right column when its
//    field count exceeds a threshold; small sections (Notes, Pressure
//    when only Notes is set) span the full width.
//
// 4. **QR code.** The `pdf` package has a built-in `BarcodeWidget` +
//    `Barcode.qrCode()`, so we don't need `qr_flutter` (which is a
//    Flutter widget, not a PDF widget). The QR encodes the marketing
//    URL for the app; the dot color is a subdued brass to match the
//    brand without dominating the page.
//
// 5. **`Theme.withFont` is not enough.** The `pdf` package's text
//    widgets default to a sans-serif font. The brand wants serif body.
//    We construct a `pw.ThemeData.withFont(base, bold, italic, ...)`
//    using `Font.times()` for the body theme, then override sectional
//    headers with `pw.TextStyle(font: Font.helvetica())` per-widget.
//
// 6. **Multi-recipe flow uses `MultiPage`** in disguise. We render each
//    recipe with the same layout function; the shared `pw.Document`
//    accumulates pages with their `currentPage / pagesCount` slot
//    populated by the `pw.Page`'s built-in footer support. We don't
//    use `MultiPage` because each recipe's content is fully self-
//    contained on its own page and we want the footer to read
//    "Page i of N" deterministically.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/recipes/recipe_form_screen.dart — the AppBar exposes a
//   "Share as PDF" action that calls `share()`.
// - lib/screens/recipes/recipes_list_screen.dart — long-press enters
//   multi-select mode; the AppBar action calls `shareMultiple()`.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Writes a temp file under `getTemporaryDirectory()`.
// - Opens the OS share sheet via `share_plus`.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../database/database.dart';

/// Generates and shares polished PDF copies of one or many recipes.
class RecipePdfService {
  RecipePdfService();

  // ─────────────────────────── Brand palette ───────────────────────────
  // Mirrors `lib/theme/app_theme.dart`. Defined as `PdfColor` here so we
  // don't need to convert at every call site. The PDF lives outside the
  // Material theme entirely — the brand has to be re-stated in the
  // PDF's own coordinate system.

  /// Primary accent (brass).
  static const PdfColor _brass = PdfColor.fromInt(0xFFC5A572);

  /// Deeper brass — used for section headers in light-on-paper renders
  /// where the lighter shade would be too pale.
  static const PdfColor _brassDeep = PdfColor.fromInt(0xFF8A6F3F);

  /// Body text — a cool charcoal pulled from the theme's `gunmetal`.
  static const PdfColor _ink = PdfColor.fromInt(0xFF1F2937);

  /// Secondary line — used for the gray subtitle line + footer.
  static const PdfColor _slate = PdfColor.fromInt(0xFF4A5566);

  // ─────────────────────────── Constants ───────────────────────────

  /// Marketing URL embedded in the QR code. Public landing page.
  static const String _kMarketingUrl =
      'https://loadout-precision-reloading.web.app';

  /// Brand display name shown in the footer.
  static const String _kAppName = 'LoadOut';

  /// Recipe printed disclaimer — kept short, italic, gray. Mirrors the
  /// in-app safety copy.
  static const String _kDisclaimer =
      'Verify all values against your reloading manual before use. '
      '$_kAppName and its developers assume no liability for unsafe loads.';

  /// Page margin (PDF points; 72 pt = 1 in).
  static const double _kMargin = 36;

  // ─────────────────────────── Public API ───────────────────────────

  /// Build a single-page PDF for [recipe]. Pure function — returns
  /// bytes, no I/O. Multi-recipe export builds many of these and
  /// concatenates the pages.
  Future<Uint8List> buildSingleRecipePdfBytes(UserLoadRow recipe) {
    return _build([recipe]);
  }

  /// Build a multi-page PDF, one [recipe] per page, in the order given.
  /// Each page footer reads "Page i of N". Returns an empty PDF (no
  /// pages) when [recipes] is empty.
  Future<Uint8List> buildMultiRecipePdfBytes(List<UserLoadRow> recipes) {
    return _build(recipes);
  }

  /// Build a single-recipe PDF, write it to a temp file, and surface
  /// the OS share sheet. The user picks Print / Save / AirDrop / etc.
  Future<void> share(BuildContext context, UserLoadRow recipe) async {
    // Capture the share-sheet origin synchronously before any await
    // (iPad popovers need it).
    final origin = _captureOrigin(context);
    final bytes = await buildSingleRecipePdfBytes(recipe);
    await _writeAndShare(
      bytes: bytes,
      filename: _filenameFor(recipe),
      subject: '$_kAppName recipe: ${recipe.name}',
      text: 'Reloading recipe shared from $_kAppName.',
      origin: origin,
    );
  }

  /// Build a multi-recipe PDF, write it to a temp file, and surface the
  /// OS share sheet. No-op when [recipes] is empty.
  Future<void> shareMultiple(
    BuildContext context,
    List<UserLoadRow> recipes,
  ) async {
    if (recipes.isEmpty) return;
    final origin = _captureOrigin(context);
    final bytes = await buildMultiRecipePdfBytes(recipes);
    final subject = recipes.length == 1
        ? '$_kAppName recipe: ${recipes.single.name}'
        : '$_kAppName recipes (${recipes.length})';
    await _writeAndShare(
      bytes: bytes,
      filename: recipes.length == 1
          ? _filenameFor(recipes.single)
          : 'loadout-recipes-${recipes.length}.pdf',
      subject: subject,
      text: 'Reloading recipes shared from $_kAppName.',
      origin: origin,
    );
  }

  // ─────────────────────────── Build pipeline ───────────────────────────

  /// Core rendering loop. One [pw.Page] per recipe; each page knows its
  /// own page index via the `Context` argument.
  Future<Uint8List> _build(List<UserLoadRow> recipes) async {
    final theme = pw.ThemeData.withFont(
      base: pw.Font.times(),
      bold: pw.Font.timesBold(),
      italic: pw.Font.timesItalic(),
      boldItalic: pw.Font.timesBoldItalic(),
    );

    final doc = pw.Document(
      title: recipes.length == 1
          ? '$_kAppName — ${recipes.single.name}'
          : '$_kAppName — ${recipes.length} recipes',
      author: _kAppName,
      subject: 'Reloading recipe',
      keywords: 'reloading, recipe, ammo, handload',
      theme: theme,
    );

    final total = recipes.length;
    final timestamp = _formatTimestamp(DateTime.now());

    for (var i = 0; i < total; i++) {
      final recipe = recipes[i];
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter.copyWith(
            marginLeft: _kMargin,
            marginRight: _kMargin,
            marginTop: _kMargin,
            marginBottom: _kMargin,
          ),
          build: (ctx) => _buildPage(
            recipe: recipe,
            pageIndex: i + 1,
            pageCount: total,
            timestamp: timestamp,
          ),
        ),
      );
    }

    return doc.save();
  }

  /// Build the layout for one recipe's page. The page is a `Column`
  /// with two children:
  ///   * an `Expanded` body block (header + section grid + notes)
  ///     that takes whatever vertical space is left after the
  ///     footer.
  ///   * a fixed-height footer at the bottom.
  /// Wrapping the body in `Expanded` is the reliable way to get
  /// "fill the rest of the page" inside a `pw.Page.build` — `Spacer`
  /// only works when the parent passes bounded main-axis constraints
  /// AND the column's `mainAxisSize` is `max`, and the pdf package
  /// occasionally hands the page builder unbounded constraints,
  /// making `Spacer` collapse. `Expanded` is unambiguous.
  pw.Widget _buildPage({
    required UserLoadRow recipe,
    required int pageIndex,
    required int pageCount,
    required String timestamp,
  }) {
    final sections = _collectSections(recipe);
    final notes = (recipe.notes ?? '').trim();

    // Build the page as a Stack:
    //   * the body (header + section grid + notes) renders top-down
    //     at its intrinsic height. We DO NOT wrap in
    //     `Positioned.fill` because that imposes a tight height that
    //     the body's `Row` of two columns then resists, dropping
    //     content. A bare `pw.Container(width: double.infinity, ...)`
    //     gives the inner column the full page width but leaves the
    //     vertical axis loose.
    //   * the footer is pinned to the bottom via `Positioned`.
    //
    // The body's bottom padding equals the footer's reserved height,
    // so a recipe so dense the body would otherwise overlap the
    // footer instead clips above it.
    //
    // Why not `Column + Spacer`? The pdf package's flex layout breaks
    // out of its child loop the moment the running allocated size
    // exceeds `constraints.maxHeight` — and since our body section
    // grid is nearly page-tall on a fully-populated recipe, the
    // Spacer + footer never get laid out at all.
    // Layout: one Column, top-down — header, body sections, optional
    // notes, Spacer, footer. The Spacer needs the parent Column to
    // claim the full page height (`mainAxisSize: MainAxisSize.max`),
    // and the parent Column needs the bounded `maxHeight` constraint
    // that `pw.Page.build` already provides. Order:
    //   1. Header band + headline + subtitle.
    //   2. The two-column section grid.
    //   3. Optional Notes block (full width, padded box).
    //   4. `pw.Spacer()` — zero or more pt of empty space.
    //   5. Footer (disclaimer + URL + QR code, plus pagination).
    //
    // For very dense recipes (50+ populated fields), the body
    // section grid alone may exceed the page's printable height. In
    // that case the pdf package's flex layout silently clips the
    // overflow at the bottom of the body, the Spacer collapses to
    // zero, and the footer ends up immediately below the body
    // (truncating into / past the bottom margin). That degradation
    // is acceptable — the alternative is `MultiPage`, which would
    // span the recipe across two pages and break the
    // "single-page-per-recipe" design promise.
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.max,
      children: [
        _buildHeader(recipe: recipe, timestamp: timestamp),
        pw.SizedBox(height: 14),
        if (sections.isNotEmpty)
          _buildSectionGrid(sections)
        else
          _buildEmptyBodyPlaceholder(),
        if (notes.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          _buildNotesBlock(notes),
        ],
        pw.Spacer(),
        _buildFooter(
          pageIndex: pageIndex,
          pageCount: pageCount,
        ),
      ],
    );
  }

  // ─────────────────────────── Header ───────────────────────────

  pw.Widget _buildHeader({
    required UserLoadRow recipe,
    required String timestamp,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Brand block — wordmark + subtitle.
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _kAppName,
                  style: pw.TextStyle(
                    font: pw.Font.helveticaBold(),
                    fontSize: 22,
                    color: _brass,
                    letterSpacing: 0.4,
                  ),
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  'Reloading Recipe',
                  style: pw.TextStyle(
                    font: pw.Font.helvetica(),
                    fontSize: 9,
                    color: _slate,
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
            // Timestamp block — small, right-aligned, gray.
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Generated $timestamp',
                  style: pw.TextStyle(
                    font: pw.Font.helvetica(),
                    fontSize: 8,
                    color: _slate,
                  ),
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  '$_kAppName v1.0',
                  style: pw.TextStyle(
                    font: pw.Font.helvetica(),
                    fontSize: 8,
                    color: _slate,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        // Recipe headline.
        pw.Text(
          _headline(recipe),
          style: pw.TextStyle(
            font: pw.Font.timesBold(),
            fontSize: 22,
            color: _brassDeep,
            letterSpacing: 0.1,
          ),
          maxLines: 2,
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          _subhead(recipe),
          style: pw.TextStyle(
            font: pw.Font.helvetica(),
            fontSize: 11,
            color: _slate,
          ),
        ),
        pw.SizedBox(height: 10),
        // Brass divider line.
        pw.Container(
          height: 1,
          color: _brass,
        ),
      ],
    );
  }

  /// Compose a marketing-quality recipe headline:
  /// "[name] - [caliber] - [powder] [charge] gr". Falls back to the
  /// recipe name alone if no supporting fields are populated.
  String _headline(UserLoadRow r) {
    final parts = <String>[r.name];
    final hint = <String>[];
    if (r.powder != null && r.powder!.trim().isNotEmpty) hint.add(r.powder!);
    if (r.powderChargeGr != null) {
      hint.add('${_formatNum(r.powderChargeGr)} gr');
    }
    if (hint.isNotEmpty) parts.add(hint.join(' '));
    return _asciiSafe(parts.join('  -  '));
  }

  /// Secondary line — "[caliber] - [use case] - [status]".
  String _subhead(UserLoadRow r) {
    final parts = <String>[];
    if (r.caliber != null && r.caliber!.trim().isNotEmpty) {
      parts.add(r.caliber!.trim());
    }
    if (r.useCase != null && r.useCase!.trim().isNotEmpty) {
      parts.add(_titleCase(r.useCase!.trim()));
    }
    if (r.status != null && r.status!.trim().isNotEmpty) {
      parts.add(_titleCase(r.status!.trim()));
    }
    if (parts.isEmpty) return 'Reloading recipe';
    // Plain ASCII middle-dot replacement (the bundled fonts can render
    // basic Latin-1 only). [_asciiSafe] strips anything that slips
    // past — em-dashes inside a caliber name, smart quotes from a
    // pasted use-case label, etc.
    return _asciiSafe(parts.join('  -  '));
  }

  // ─────────────────────────── Body sections ───────────────────────────

  /// Build the list of populated sections in a recipe-form-mirroring
  /// order. Each section returns a list of `(label, value)` pairs;
  /// empty sections are filtered.
  List<_PdfSection> _collectSections(UserLoadRow r) {
    final sections = <_PdfSection>[];

    // `powderReferenceTempCelsius` has a non-null default (15.6). Only
    // surface it when the user has actually engaged with powder
    // sensitivity (set the sensitivity value, or named a powder) —
    // otherwise it pollutes minimal recipes with an unset-looking
    // value.
    final hasPowderContext = (r.powder != null && r.powder!.trim().isNotEmpty)
        || r.powderTempSensitivityFpsPerCelsius != null;
    final powder = <_PdfRow?>[
      _kv('Powder', r.powder),
      _kv('Charge', _formatNum(r.powderChargeGr), suffix: ' gr'),
      _kv(
        'Charge Tolerance',
        _formatNum(r.chargeToleranceGr),
        suffix: ' gr',
      ),
      _kv(
        'Temp Sensitivity',
        _formatNum(r.powderTempSensitivityFpsPerCelsius),
        suffix: ' fps/C',
      ),
      if (hasPowderContext)
        _kv(
          'Reference Temp',
          _formatNum(r.powderReferenceTempCelsius),
          suffix: ' C',
        ),
    ].whereType<_PdfRow>().toList();
    if (powder.isNotEmpty) {
      sections.add(_PdfSection('Powder', powder));
    }

    final primer = <_PdfRow?>[
      _kv('Primer', r.primer),
      _kv('Primer Depth', _formatNum(r.primerDepthCps), suffix: ' cps'),
      _kv(
        'Seating Force',
        _formatNum(r.primerSeatingForceLbs),
        suffix: ' lbs',
      ),
    ].whereType<_PdfRow>().toList();
    if (primer.isNotEmpty) {
      sections.add(_PdfSection('Primer', primer));
    }

    final bullet = <_PdfRow?>[
      _kv('Bullet', r.bullet),
      _kv('Weight', _formatNum(r.bulletWeightGr), suffix: ' gr'),
      _kv('Length', _formatNum(r.bulletLengthIn), suffix: ' in'),
      _kv('Base-to-Ogive', _formatNum(r.bulletBaseToOgiveIn), suffix: ' in'),
      _kv(
        'Bearing Surface',
        _formatNum(r.bulletBearingSurfaceIn),
        suffix: ' in',
      ),
      if (r.bulletMeplatTrimmed) const _PdfRow('Meplat Trimmed', 'Yes'),
      if (r.bulletPointed) const _PdfRow('Pointed', 'Yes'),
      if (r.bulletWeightSorted) const _PdfRow('Weight Sorted', 'Yes'),
      _kv(
        'Weight Tol.',
        _formatNum(r.bulletWeightToleranceGr),
        suffix: ' gr',
      ),
      if (r.bulletBtoSorted) const _PdfRow('BTO Sorted', 'Yes'),
      _kv('BTO Tol.', _formatNum(r.bulletBtoToleranceIn), suffix: ' in'),
      if (r.bulletDiameterSorted) const _PdfRow('Diameter Sorted', 'Yes'),
    ].whereType<_PdfRow>().toList();
    if (bullet.isNotEmpty) {
      sections.add(_PdfSection('Bullet', bullet));
    }

    final brass = <_PdfRow?>[
      _kv('Brass', r.brass),
    ].whereType<_PdfRow>().toList();
    if (brass.isNotEmpty) {
      sections.add(_PdfSection('Brass', brass));
    }

    final loaded = <_PdfRow?>[
      _kv('COAL', _formatNum(r.coalIn), suffix: ' in'),
      _kv('CBTO', _formatNum(r.cbtoIn), suffix: ' in'),
      _kv('Seating Depth', _formatNum(r.seatingDepthIn), suffix: ' in'),
      _kv('Shoulder Bump', _formatNum(r.shoulderBumpIn), suffix: ' in'),
      _kv('Mandrel Size', _formatNum(r.mandrelSizeIn), suffix: ' in'),
      _kv(
        'Distance to Lands',
        _formatNum(r.distanceToLandsIn),
        suffix: ' in',
      ),
      _kv('Jump to Lands', _formatNum(r.jumpToLandsIn), suffix: ' in'),
      _kv(
        'Loaded Neck Diam.',
        _formatNum(r.loadedNeckDiameterIn),
        suffix: ' in',
      ),
      _kv('Bullet Runout (TIR)', _formatNum(r.bulletRunoutTirIn), suffix: ' in'),
      _kv('Bushing Size', _formatNum(r.bushingSizeIn), suffix: ' in'),
    ].whereType<_PdfRow>().toList();
    if (loaded.isNotEmpty) {
      sections.add(_PdfSection('Loaded Round', loaded));
    }

    final pressure = <_PdfRow?>[
      _kv('Pressure Notes', r.pressureNotes),
      _kv('Bolt Lift', _titleCaseOrNull(r.boltLift)),
      if (r.ejectorMarks) const _PdfRow('Ejector Marks', 'Yes'),
      if (r.crateredPrimers) const _PdfRow('Cratered Primers', 'Yes'),
      _kv(
        'Web Expansion @.200',
        _formatNum(r.webExpansion200In),
        suffix: ' in',
      ),
      _kv('Primer Flatness', r.primerFlatness?.toString(), suffix: ' / 5'),
    ].whereType<_PdfRow>().toList();
    if (pressure.isNotEmpty) {
      sections.add(_PdfSection('Pressure Indicators', pressure));
    }

    final process = <_PdfRow?>[
      _kv('Loaded By', r.loadedBy),
      _kv('Loading Date', _formatDate(r.loadingDate)),
      _kv('Date Established', _formatDate(r.dateEstablished)),
      _kv('Rounds in Batch', r.roundsLoadedInBatch?.toString()),
      _kv('Press', r.pressUsed),
      _kv('Sizing Die', r.sizingDieUsed),
      _kv('Seating Die', r.seatingDieUsed),
      _kv('Scale', r.scaleUsed),
      _kv('Scale Calibration', _formatDate(r.scaleCalibrationDate)),
      _kv('Comparator', r.comparatorInsertUsed),
      _kv('Chronograph', r.chronographUsed),
      _kv('Bore State', _titleCaseOrNull(r.boreState)),
    ].whereType<_PdfRow>().toList();
    if (process.isNotEmpty) {
      sections.add(_PdfSection('Process / Equipment', process));
    }

    return sections;
  }

  /// Render the populated sections in a packed two-column grid. Each
  /// section is one block; blocks fill column A first, then wrap into
  /// column B. We measure by row count rather than rendered height —
  /// at body-density a full-page section never overflows.
  pw.Widget _buildSectionGrid(List<_PdfSection> sections) {
    // Estimate per-section row weight to balance the two columns.
    // Header counts as a row, plus one row per data row.
    int weight(_PdfSection s) => s.rows.length + 1;
    final totalWeight = sections.fold<int>(0, (a, b) => a + weight(b));
    final target = totalWeight / 2;

    final left = <_PdfSection>[];
    final right = <_PdfSection>[];
    var accumulated = 0;
    for (final s in sections) {
      if (accumulated < target || (right.isEmpty && left.isEmpty)) {
        left.add(s);
      } else {
        right.add(s);
      }
      accumulated += weight(s);
    }
    // Edge case — single-section recipes go entirely on the left
    // (avoids rendering an empty right column with stray padding).
    if (right.isEmpty && left.length > 1) {
      // try to peel off the bottom-half-ish entries to balance.
      var pulled = 0;
      while (left.length > 1 && pulled < target) {
        final last = left.removeLast();
        right.insert(0, last);
        pulled += weight(last);
      }
    }

    pw.Widget column(List<_PdfSection> items) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) pw.SizedBox(height: 12),
            _buildSection(items[i]),
          ],
        ],
      );
    }

    // Two flex columns of section blocks, sharing the page width
    // 50/50 with a 24pt gutter.
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: column(left)),
        pw.SizedBox(width: 24),
        pw.Expanded(child: column(right)),
      ],
    );
  }

  pw.Widget _buildSection(_PdfSection section) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          _asciiSafe(section.title).toUpperCase(),
          style: pw.TextStyle(
            font: pw.Font.helveticaBold(),
            fontSize: 9,
            color: _brassDeep,
            letterSpacing: 1.4,
          ),
        ),
        pw.SizedBox(height: 4),
        // Brass underline under the section header.
        pw.Container(
          height: 0.6,
          color: _brass,
        ),
        pw.SizedBox(height: 6),
        for (final row in section.rows) _buildRow(row),
      ],
    );
  }

  pw.Widget _buildRow(_PdfRow row) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '${row.label}: ',
              style: pw.TextStyle(
                font: pw.Font.times(),
                fontSize: 11,
                color: _slate,
              ),
            ),
            pw.TextSpan(
              text: row.value,
              style: pw.TextStyle(
                font: pw.Font.timesBold(),
                fontSize: 11,
                color: _ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Empty placeholder when no sections are populated. Reduces the
  /// "user added a recipe with only a name" footprint.
  pw.Widget _buildEmptyBodyPlaceholder() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 24),
      child: pw.Center(
        child: pw.Text(
          'This recipe has no component or dimension fields populated yet.',
          style: pw.TextStyle(
            font: pw.Font.timesItalic(),
            fontSize: 11,
            color: _slate,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── Notes block ───────────────────────────

  pw.Widget _buildNotesBlock(String notes) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: _brass,
          width: 0.6,
        ),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'NOTES',
            style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 9,
              color: _brassDeep,
              letterSpacing: 1.4,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _asciiSafe(notes),
            style: pw.TextStyle(
              font: pw.Font.times(),
              fontSize: 11,
              color: _ink,
              lineSpacing: 2.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── Footer ───────────────────────────

  pw.Widget _buildFooter({
    required int pageIndex,
    required int pageCount,
  }) {
    final showPageNumber = pageCount > 1;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          height: 0.4,
          color: _slate,
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left: disclaimer + signature line.
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    _kDisclaimer,
                    style: pw.TextStyle(
                      font: pw.Font.timesItalic(),
                      fontSize: 8,
                      color: _slate,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Created with $_kAppName  -  loadout-precision-reloading.web.app',
                    style: pw.TextStyle(
                      font: pw.Font.helvetica(),
                      fontSize: 8,
                      color: _slate,
                    ),
                  ),
                  if (showPageNumber) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Page $pageIndex of $pageCount',
                      style: pw.TextStyle(
                        font: pw.Font.helvetica(),
                        fontSize: 8,
                        color: _slate,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            // Right: QR code → marketing URL.
            pw.SizedBox(
              width: 56,
              height: 56,
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: _kMarketingUrl,
                color: _brassDeep,
                drawText: false,
                padding: pw.EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────── Helpers ───────────────────────────

  /// Build a `_PdfRow` from a label + value, returning null if the
  /// value is null / blank / "0" so empty fields don't render. Both
  /// label and value are sanitised through [_asciiSafe] so any em-dash
  /// or smart-quote a user typed renders as an ASCII equivalent that
  /// the bundled PDF Type 1 fonts can actually draw.
  _PdfRow? _kv(String label, Object? value, {String? suffix}) {
    if (value == null) return null;
    final str = value.toString().trim();
    if (str.isEmpty) return null;
    return _PdfRow(_asciiSafe(label), _asciiSafe('$str${suffix ?? ''}'));
  }

  /// Format a numeric value compactly. `null` returns null. Integer
  /// values render without the trailing ".0".
  String? _formatNum(num? v) {
    if (v == null) return null;
    final d = v.toDouble();
    if (d == d.truncateToDouble()) {
      return d.toInt().toString();
    }
    // Trim trailing zeros after the decimal point, max 4 significant
    // decimals (handles e.g. 0.0035 → "0.0035" but 41.50 → "41.5").
    var str = d.toStringAsFixed(4);
    str = str.replaceAll(RegExp(r'0+$'), '');
    str = str.replaceAll(RegExp(r'\.$'), '');
    return str;
  }

  String? _formatDate(DateTime? dt) {
    if (dt == null) return null;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }

  String _formatTimestamp(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }

  String? _titleCaseOrNull(String? s) {
    if (s == null) return null;
    final t = s.trim();
    if (t.isEmpty) return null;
    return _titleCase(t);
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    // Just capitalise the first character — the source values are
    // single tokens like "match" / "active" / "normal" already.
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Replace common Unicode punctuation with ASCII equivalents so the
  /// bundled Type 1 fonts (Helvetica / Times / Courier — Latin-1 only)
  /// can render the string. Reloaders frequently paste em-dashes or
  /// smart quotes from notebooks / web pages; rendering them as a
  /// missing-glyph box looks worse than swapping them for ASCII.
  /// Anything outside the basic Latin-1 range that we can't map gets
  /// dropped silently — this is a printout, not a database round-trip.
  static String _asciiSafe(String s) {
    if (s.isEmpty) return s;
    final buf = StringBuffer();
    for (final rune in s.runes) {
      if (rune < 0x80) {
        // Plain ASCII — passes through unchanged.
        buf.writeCharCode(rune);
        continue;
      }
      // Common typographic substitutes.
      switch (rune) {
        case 0x2010: // hyphen
        case 0x2011: // non-breaking hyphen
        case 0x2012: // figure dash
        case 0x2013: // en dash
        case 0x2014: // em dash
        case 0x2015: // horizontal bar
          buf.write('-');
          break;
        case 0x2018: // left single quote
        case 0x2019: // right single quote
          buf.write("'");
          break;
        case 0x201C: // left double quote
        case 0x201D: // right double quote
          buf.write('"');
          break;
        case 0x2022: // bullet
        case 0x00B7: // middle dot
        case 0x2027: // hyphenation point
          buf.write('-');
          break;
        case 0x2026: // ellipsis
          buf.write('...');
          break;
        case 0x00B0: // degree
          buf.write(' deg');
          break;
        case 0x00BC: // 1/4
          buf.write('1/4');
          break;
        case 0x00BD: // 1/2
          buf.write('1/2');
          break;
        case 0x00BE: // 3/4
          buf.write('3/4');
          break;
        case 0x2070: // superscript zero
          buf.write('0');
          break;
        case 0x00D7: // multiplication sign
          buf.write('x');
          break;
        case 0x2032: // prime
          buf.write("'");
          break;
        case 0x2033: // double prime
          buf.write('"');
          break;
        default:
          if (rune <= 0xFF) {
            // Latin-1 range — the PDF Type 1 fonts handle these.
            buf.writeCharCode(rune);
          } else {
            // Drop anything else (CJK, emoji, etc.). Replacing with
            // '?' would draw a tofu box; an empty drop is cleaner.
          }
          break;
      }
    }
    return buf.toString();
  }

  /// Sanitised filename for one recipe. Lowercase, kebab-case, no
  /// shell metacharacters.
  String _filenameFor(UserLoadRow r) {
    final safe = r.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return 'loadout-recipe-${safe.isEmpty ? 'recipe' : safe}.pdf';
  }

  /// Capture the iPad share-sheet origin rect synchronously from a
  /// `BuildContext`. Required before any await — `findRenderObject` on
  /// a deactivated context returns garbage.
  Rect? _captureOrigin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Common write-temp + share path. Skipped on web (file system is
  /// not available); web users get a no-op until we wire up
  /// `printing` or browser download.
  Future<void> _writeAndShare({
    required Uint8List bytes,
    required String filename,
    required String subject,
    required String text,
    required Rect? origin,
  }) async {
    if (kIsWeb) {
      // Web has no temp directory; share_plus on web only supports
      // `Share.share` (text). Future hook: blob URL + anchor download.
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: subject,
      text: text,
      sharePositionOrigin: origin,
    );
  }
}

/// One labelled row inside a section block (label + already-formatted
/// value with units appended).
class _PdfRow {
  const _PdfRow(this.label, this.value);
  final String label;
  final String value;
}

/// One titled group of `_PdfRow`s. Sections with no rows are filtered
/// out by `_collectSections` so they never reach the grid layout.
class _PdfSection {
  const _PdfSection(this.title, this.rows);
  final String title;
  final List<_PdfRow> rows;
}
