// FILE: test/spreadsheet_import_service_test.dart
//
// Round-trip test for the Smart Import service. Builds a CSV string in
// memory, writes it to a temp file, parses + ingests through the
// service into an in-memory drift database, and asserts the resulting
// rows match.
//
// Excel (.xlsx) round-trip is skipped — see TODO at end of file.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/database/database.dart';
import 'package:loadout/repositories/recipe_repository.dart';
import 'package:loadout/services/spreadsheet_import_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late RecipeRepository repo;
  late SpreadsheetImportService service;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('loadout_smart_import_');
    // Mock SharedPreferences so the saved-mapping calls inside the
    // service don't try to hit the real platform channel.
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = RecipeRepository(db);
    service = SpreadsheetImportService(repo);
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('CSV round-trip: parse → preview → import → verify rows', () async {
    // Custom column names that the legacy strict importer wouldn't have
    // recognised — exercise the auto-suggester.
    const csv =
        'Loadname,Cartridge,Crg gr,Bullet Brand,Bullet Wt,COAL,Memo\n'
        'Match A,6.5 Creedmoor,41.5gr,Hornady ELD-M,140,2.825,test load\n'
        'Match B,6.5 Creedmoor,42.0,Berger Hybrid,140,2.83,\n'
        'Plinker,9mm Luger,5.2 grains,Berry 124gr,124,1.135,plinking\n';

    final file = File(p.join(tempDir.path, 'sample.csv'));
    await file.writeAsString(csv);

    final preview = await service.parsePreview(file);
    expect(preview.hasFatalError, isFalse);
    expect(preview.headers, [
      'Loadname',
      'Cartridge',
      'Crg gr',
      'Bullet Brand',
      'Bullet Wt',
      'COAL',
      'Memo',
    ]);
    expect(preview.totalDataRows, 3);
    expect(preview.sampleRows.length, 3);

    // Auto-suggester should hit the obvious ones.
    final suggestionByHeader = {
      for (final s in preview.suggestions) s.header: s.suggestedField,
    };
    expect(suggestionByHeader['Loadname'], FieldId.name);
    expect(suggestionByHeader['Cartridge'], FieldId.caliber);
    expect(suggestionByHeader['Bullet Brand'], FieldId.bullet);
    expect(suggestionByHeader['COAL'], FieldId.coalIn);
    expect(suggestionByHeader['Memo'], FieldId.notes);

    // The auto-suggester resolves the rest deterministically; for the
    // import we explicitly pass the mapping so the test isn't sensitive
    // to threshold tuning.
    final mapping = <String, FieldId>{
      'Loadname': FieldId.name,
      'Cartridge': FieldId.caliber,
      'Crg gr': FieldId.powderChargeGr,
      'Bullet Brand': FieldId.bullet,
      'Bullet Wt': FieldId.bulletWeightGr,
      'COAL': FieldId.coalIn,
      'Memo': FieldId.notes,
    };

    final result = await service.importRows(
      file: file,
      mapping: mapping,
    );
    expect(result.imported, 3);
    expect(result.skipped, 0);
    expect(result.errors, isEmpty);

    final rows = await repo.watchAll().first;
    expect(rows.length, 3);

    final byName = {for (final r in rows) r.name: r};
    final matchA = byName['Match A']!;
    expect(matchA.caliber, '6.5 Creedmoor');
    expect(matchA.powderChargeGr, 41.5);
    expect(matchA.bullet, 'Hornady ELD-M');
    expect(matchA.bulletWeightGr, 140);
    expect(matchA.coalIn, 2.825);
    expect(matchA.notes, 'test load');

    final matchB = byName['Match B']!;
    expect(matchB.powderChargeGr, 42.0);
    expect(matchB.coalIn, 2.83);
    expect(matchB.notes, isNull);

    final plinker = byName['Plinker']!;
    expect(plinker.caliber, '9mm Luger');
    expect(plinker.powderChargeGr, 5.2); // strips " grains"
    expect(plinker.bulletWeightGr, 124);
    expect(plinker.coalIn, 1.135);
  });

  test('rows missing the recipe-name column are skipped', () async {
    const csv =
        'Loadname,Cartridge,Crg gr\n'
        'Match A,6.5 Creedmoor,41.5\n'
        ',6.5 Creedmoor,42.0\n'
        'Plinker,9mm Luger,5.2\n';
    final file = File(p.join(tempDir.path, 'skip.csv'));
    await file.writeAsString(csv);
    final result = await service.importRows(
      file: file,
      mapping: const {
        'Loadname': FieldId.name,
        'Cartridge': FieldId.caliber,
        'Crg gr': FieldId.powderChargeGr,
      },
    );
    expect(result.imported, 2);
    expect(result.skipped, 1);
  });

  test('non-numeric values in numeric columns log warnings, not aborts',
      () async {
    const csv =
        'Loadname,Crg gr\n'
        'Good,41.5\n'
        'Bad,varies\n';
    final file = File(p.join(tempDir.path, 'tolerance.csv'));
    await file.writeAsString(csv);
    final result = await service.importRows(
      file: file,
      mapping: const {
        'Loadname': FieldId.name,
        'Crg gr': FieldId.powderChargeGr,
      },
    );
    // Both rows still imported — but "Bad" has a null charge plus a
    // warning in errors.
    expect(result.imported, 2);
    expect(result.skipped, 0);
    expect(result.errors, isNotEmpty);
    final rows = await repo.watchAll().first;
    final bad = rows.firstWhere((r) => r.name == 'Bad');
    expect(bad.powderChargeGr, isNull);
  });

  test('parseTolerantNumeric handles units and thousands separators', () {
    expect(SpreadsheetImportService.parseTolerantNumeric('41.5'), 41.5);
    expect(SpreadsheetImportService.parseTolerantNumeric('41.5gr'), 41.5);
    expect(SpreadsheetImportService.parseTolerantNumeric('41.5 grains'), 41.5);
    expect(SpreadsheetImportService.parseTolerantNumeric('  41.5 '), 41.5);
    expect(SpreadsheetImportService.parseTolerantNumeric('2.825 in'), 2.825);
    expect(SpreadsheetImportService.parseTolerantNumeric('1,234.5'), 1234.5);
    expect(SpreadsheetImportService.parseTolerantNumeric('41,5'), 41.5);
    expect(SpreadsheetImportService.parseTolerantNumeric('varies'), isNull);
    expect(SpreadsheetImportService.parseTolerantNumeric(''), isNull);
  });

  // TODO: end-to-end XLSX round-trip — the `excel` package's
  // `Excel.decodeBytes` reads a real workbook from a byte buffer.
  // Building a minimal valid `.xlsx` in-memory means producing the
  // OOXML zip structure, which is awkward to mock. Cover that with an
  // integration-test fixture rather than a unit test once we have a
  // sample workbook checked in to `test/fixtures/`.
}
