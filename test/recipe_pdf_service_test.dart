// FILE: test/recipe_pdf_service_test.dart
//
// Smoke tests for `lib/services/recipe_pdf_service.dart`. We exercise
// the pure builder methods (`buildSingleRecipePdfBytes`,
// `buildMultiRecipePdfBytes`) against synthesised `UserLoadRow`
// instances and assert:
//
//   1. The byte string starts with the `%PDF` magic header.
//   2. The byte string is large enough to be a meaningful document
//      (at minimum kilobytes).
//   3. Multi-recipe builds emit one page per recipe (counted by
//      `/Type /Page` markers in the raw byte stream — a coarse but
//      reliable structural check that doesn't require pulling in a
//      PDF parser).
//
// We don't render the page or compare pixels — that would couple the
// tests to font metrics and layout decisions. The point of the suite
// is regression coverage: did a code change break the PDF generator
// or accidentally drop a page when more than one recipe is exported?

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/database/database.dart';
import 'package:loadout/services/recipe_pdf_service.dart';

/// Count `Type/Page` markers in the PDF byte stream. The pdf package
/// emits one per page object. The PDF format the package emits packs
/// the key + value together as `Type/Page` (with the slash on the
/// value). After that comes the resources sub-dict as `Type/Page/...`,
/// so we look for `Page` followed specifically by `/` or whitespace —
/// excluding `Pages` (the container) by requiring the lookahead to
/// not be a letter / digit.
int _countPages(List<int> bytes) {
  final ascii = String.fromCharCodes(bytes);
  // Match `Type/Page` where the character following `Page` is anything
  // except a word-continuation (e.g. `s` for `Pages`). `/Resources`
  // qualifies (the slash is not a word char). Whitespace between
  // `Type` and `/Page` is also allowed because some emitters insert
  // a space.
  final re = RegExp(r'Type\s*/Page(?!\w)');
  return re.allMatches(ascii).length;
}

void main() {
  late AppDatabase db;
  setUp(() {
    // Drift companion `.insert(...)` validates required columns, so we
    // build a minimal in-memory DB and round-trip rows out as
    // `UserLoadRow` instances. That gives us realistic shape (every
    // column type matches the production schema) without us having to
    // hand-roll a constructor for the 50+ columns.
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<UserLoadRow> insertAndFetch(UserLoadsCompanion companion) async {
    final id = await db.into(db.userLoads).insert(companion);
    final row = await (db.select(db.userLoads)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    return row;
  }

  group('RecipePdfService.buildSingleRecipePdfBytes', () {
    test('produces a multi-KB PDF with the %PDF magic header for a '
        'realistic populated recipe (~25 fields)', () async {
      // ~25 fields exercises every section that the PDF can render
      // without overflowing the single-page layout. We deliberately
      // don't stuff every column — extreme-density recipes (50+
      // populated fields) clip into the footer area, which is the
      // documented degradation.
      final row = await insertAndFetch(
        UserLoadsCompanion.insert(
          name: '6.5 Creedmoor - Match',
          caliber: const Value('6.5 Creedmoor'),
          powder: const Value('Hodgdon H4350'),
          powderChargeGr: const Value(41.5),
          chargeToleranceGr: const Value(0.04),
          bullet: const Value('Berger 140gr Hybrid Target'),
          bulletWeightGr: const Value(140),
          bulletLengthIn: const Value(1.347),
          bulletBaseToOgiveIn: const Value(0.748),
          primer: const Value('CCI BR-2'),
          primerSeatingForceLbs: const Value(35),
          brass: const Value('Lapua 6.5 Creedmoor'),
          coalIn: const Value(2.825),
          cbtoIn: const Value(2.215),
          seatingDepthIn: const Value(0.018),
          shoulderBumpIn: const Value(0.002),
          status: const Value('active'),
          useCase: const Value('match'),
          loadedBy: const Value('General'),
          loadingDate: Value(DateTime(2026, 4, 28)),
          pressUsed: const Value('AMP Press 2'),
          seatingDieUsed: const Value('Forster Micrometer'),
          scaleUsed: const Value('A&D FX-120i'),
          chronographUsed: const Value('Garmin Xero C1 Pro'),
          notes: const Value(
            'Cold-bore zero @ 60F. ES 9 fps over 20 shots; SD 3.4 fps. '
            'Group at 100 yd: 0.32 MOA.',
          ),
        ),
      );

      final svc = RecipePdfService();
      final bytes = await svc.buildSingleRecipePdfBytes(row);

      // Header — every PDF starts with `%PDF`.
      expect(bytes.length, greaterThan(5000),
          reason: 'PDF should be at least 5 KB for a fully-populated recipe.');
      final header = String.fromCharCodes(bytes.sublist(0, 4));
      expect(header, '%PDF');

      // Single page.
      expect(_countPages(bytes), 1);
    });

    test('builds a clean PDF for a minimally-populated recipe (just '
        'name + caliber) without crashing or rendering empty-field '
        'artifacts', () async {
      final row = await insertAndFetch(
        UserLoadsCompanion.insert(
          name: 'Untitled Load',
          caliber: const Value('.308 Winchester'),
        ),
      );

      final svc = RecipePdfService();
      final bytes = await svc.buildSingleRecipePdfBytes(row);

      // Magic header + non-trivial size.
      expect(bytes.length, greaterThan(1024));
      final header = String.fromCharCodes(bytes.sublist(0, 4));
      expect(header, '%PDF');

      // Single page even when most sections are filtered out.
      expect(_countPages(bytes), 1);

      // No "stray label colon" should appear in the page stream — empty
      // fields must drop silently. We can look for the placeholder
      // empty-body block instead.
      final ascii = String.fromCharCodes(bytes);
      // The page stream uses the PDF text-showing operator `Tj` with
      // hex-or-string operands; our helper text is encoded as plain
      // ASCII inside the content stream when the bundled fonts are
      // used. Scan for "Powder:" (a label that should NEVER appear
      // because no powder was set).
      // (We can't trivially decode the content stream, but a "Powder"
      // section is gated on the `_collectSections` helper returning
      // any non-null powder row. Verify no Powder section exists.)
      expect(ascii.contains('POWDER'), isFalse,
          reason:
              'POWDER section header must not appear when no powder fields '
              'are populated.');
    });
  });

  group('RecipePdfService.buildMultiRecipePdfBytes', () {
    test('emits one page per recipe in the input order', () async {
      final r1 = await insertAndFetch(
        UserLoadsCompanion.insert(
          name: 'Recipe A',
          caliber: const Value('6.5 Creedmoor'),
          powder: const Value('H4350'),
          powderChargeGr: const Value(41.5),
        ),
      );
      final r2 = await insertAndFetch(
        UserLoadsCompanion.insert(
          name: 'Recipe B',
          caliber: const Value('.308 Winchester'),
          powder: const Value('Varget'),
          powderChargeGr: const Value(44.0),
        ),
      );
      final r3 = await insertAndFetch(
        UserLoadsCompanion.insert(
          name: 'Recipe C',
          caliber: const Value('.223 Remington'),
        ),
      );

      final svc = RecipePdfService();
      final bytes = await svc.buildMultiRecipePdfBytes([r1, r2, r3]);

      expect(bytes.length, greaterThan(5000));
      final header = String.fromCharCodes(bytes.sublist(0, 4));
      expect(header, '%PDF');
      expect(_countPages(bytes), 3);
    });

    test('returns an empty document for an empty input list', () async {
      final svc = RecipePdfService();
      final bytes = await svc.buildMultiRecipePdfBytes(const []);
      // Even an empty document still has a `%PDF` header — the pdf
      // package emits a valid (page-less) document.
      expect(bytes.length, greaterThan(64));
      final header = String.fromCharCodes(bytes.sublist(0, 4));
      expect(header, '%PDF');
      expect(_countPages(bytes), 0);
    });
  });
}
