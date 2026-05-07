import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/database.dart';

/// Reads reference + custom components and exposes them as flat option lists
/// for dropdowns. Also writes user-added custom components.
class ComponentRepository {
  ComponentRepository(this.db);
  final AppDatabase db;

  // ───── Cartridges ─────

  Future<List<CartridgeRow>> allCartridges() => db.select(db.cartridges).get();

  Stream<List<CartridgeRow>> watchCartridges() =>
      (db.select(db.cartridges)..orderBy([(c) => OrderingTerm.asc(c.name)]))
          .watch();

  Future<CartridgeRow?> cartridgeByName(String name) =>
      (db.select(db.cartridges)..where((c) => c.name.equals(name)))
          .getSingleOrNull();

  // ───── Powders / bullets / primers / brass — unified label helpers ─────

  /// Returns label strings for the given component kind, combining reference
  /// data with user-added custom components.
  Future<List<String>> componentLabels(String kind) async {
    final results = <String>[];
    switch (kind) {
      case 'powder':
        final rows = await (db.select(db.powders).join([
          innerJoin(db.manufacturers,
              db.manufacturers.id.equalsExp(db.powders.manufacturerId)),
        ])
              ..orderBy([
                OrderingTerm.asc(db.manufacturers.name),
                OrderingTerm.asc(db.powders.name),
              ]))
            .get();
        for (final row in rows) {
          final mfg = row.readTable(db.manufacturers);
          final p = row.readTable(db.powders);
          results.add('${mfg.name} ${p.name}');
        }
        break;
      case 'bullet':
        final rows = await (db.select(db.bullets).join([
          innerJoin(db.manufacturers,
              db.manufacturers.id.equalsExp(db.bullets.manufacturerId)),
        ])
              ..orderBy([
                OrderingTerm.asc(db.manufacturers.name),
                OrderingTerm.asc(db.bullets.line),
                OrderingTerm.asc(db.bullets.weightGr),
              ]))
            .get();
        for (final row in rows) {
          final mfg = row.readTable(db.manufacturers);
          final b = row.readTable(db.bullets);
          final wt = b.weightGr.toStringAsFixed(b.weightGr.truncateToDouble() == b.weightGr ? 0 : 1);
          results.add('${mfg.name} ${b.line} ${wt}gr');
        }
        break;
      case 'primer':
        final rows = await (db.select(db.primers).join([
          innerJoin(db.manufacturers,
              db.manufacturers.id.equalsExp(db.primers.manufacturerId)),
        ])
              ..orderBy([
                OrderingTerm.asc(db.manufacturers.name),
                OrderingTerm.asc(db.primers.name),
              ]))
            .get();
        for (final row in rows) {
          final mfg = row.readTable(db.manufacturers);
          final p = row.readTable(db.primers);
          // Prepend a `#` to the primer ID so labels read like
          // "Federal #210M" or "Winchester #WLR".
          results.add('${mfg.name} #${p.name}');
        }
        break;
      case 'brass':
        final rows = await (db.select(db.brassProducts).join([
          innerJoin(db.manufacturers,
              db.manufacturers.id.equalsExp(db.brassProducts.manufacturerId)),
        ])
              ..orderBy([OrderingTerm.asc(db.manufacturers.name)]))
            .get();
        for (final row in rows) {
          final mfg = row.readTable(db.manufacturers);
          results.add(mfg.name);
        }
        break;
      case 'cartridge':
        final rows = await (db.select(db.cartridges)
              ..orderBy([(c) => OrderingTerm.asc(c.name)]))
            .get();
        results.addAll(rows.map((r) => r.name));
        break;
    }
    final customs = await (db.select(db.customComponents)
          ..where((c) => c.kind.equals(kind))
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();
    results.addAll(customs.map((c) => c.name));
    return results;
  }

  Future<int> addCustomComponent(String kind, String name, {String? notes}) =>
      db.into(db.customComponents).insertOnConflictUpdate(
            CustomComponentsCompanion.insert(
              kind: kind,
              name: name,
              notes: Value(notes),
            ),
          );

  /// Look up a primer reference row by a fully-formatted label of the form
  /// `"<Manufacturer> #<PrimerId>"` (e.g. `"Federal #210M"`). Returns
  /// `null` if the label doesn't match the format or no row is found.
  ///
  /// Used by the recipe form to auto-fill primer size when a user picks
  /// a known primer from the dropdown.
  Future<PrimerRow?> primerByLabel(String label) async {
    final hashIdx = label.indexOf('#');
    if (hashIdx <= 0 || hashIdx == label.length - 1) return null;
    final mfgName = label.substring(0, hashIdx).trim();
    final primerName = label.substring(hashIdx + 1).trim();
    if (mfgName.isEmpty || primerName.isEmpty) return null;

    final rows = await (db.select(db.primers).join([
      innerJoin(db.manufacturers,
          db.manufacturers.id.equalsExp(db.primers.manufacturerId)),
    ])
          ..where(db.manufacturers.name.equals(mfgName) &
              db.primers.name.equals(primerName)))
        .get();
    if (rows.isEmpty) return null;
    return rows.first.readTable(db.primers);
  }

  // ───── Primer cascading dropdown helpers ─────

  /// All primer manufacturer names, alphabetical. Used to populate the
  /// brand dropdown of the cascading primer field.
  Future<List<String>> primerManufacturers() async {
    final rows = await (db.select(db.manufacturers)
          ..where((m) => m.kind.equals('primer'))
          ..orderBy([(m) => OrderingTerm.asc(m.name)]))
        .get();
    return rows.map((m) => m.name).toList();
  }

  /// All primer products from a given manufacturer, sorted by product line
  /// then model number. Used to populate the product dropdown of the
  /// cascading primer field once a brand is chosen.
  Future<List<PrimerRow>> primersByManufacturer(String manufacturerName) async {
    final rows = await (db.select(db.primers).join([
      innerJoin(db.manufacturers,
          db.manufacturers.id.equalsExp(db.primers.manufacturerId)),
    ])
          ..where(db.manufacturers.name.equals(manufacturerName))
          ..orderBy([
            OrderingTerm.asc(db.primers.size),
            OrderingTerm.asc(db.primers.name),
          ]))
        .get();
    return rows.map((r) => r.readTable(db.primers)).toList();
  }

  /// Build the canonical user-facing label for a primer product.
  ///
  /// Format: `"<ProductLine> #<Name>"` if a product line exists, otherwise
  /// just `"#<Name>"`. The brand name is intentionally excluded since the
  /// cascading dropdown shows brand and product separately. For storage in
  /// the recipe (where only one string is persisted), use
  /// [primerStorageLabel] instead.
  static String primerProductLabel(PrimerRow p) {
    final pl = p.productLine;
    return pl == null || pl.isEmpty ? '#${p.name}' : '$pl #${p.name}';
  }

  /// The string we persist in `UserLoads.primer` when a user picks a primer
  /// from the dropdown. Keeps the existing `"<Brand> #<Name>"` shape so
  /// older recipes remain compatible and [primerByLabel] keeps working.
  static String primerStorageLabel(String manufacturer, PrimerRow p) {
    return '$manufacturer #${p.name}';
  }

  /// Parse a stored primer label like `"Federal #210M"` into its components.
  /// Returns `(manufacturer, primerName)` or `null` if the label isn't in
  /// the canonical format. Used by the cascading field to pre-select the
  /// dropdowns when editing an existing recipe.
  static ({String manufacturer, String primerName})? splitPrimerStorageLabel(
      String label) {
    final hashIdx = label.indexOf('#');
    if (hashIdx <= 0 || hashIdx == label.length - 1) return null;
    final mfg = label.substring(0, hashIdx).trim();
    final name = label.substring(hashIdx + 1).trim();
    if (mfg.isEmpty || name.isEmpty) return null;
    return (manufacturer: mfg, primerName: name);
  }

  // ───── Reference firearms ─────

  Future<List<({FirearmRefRow firearm, ManufacturerRow manufacturer, List<String> calibers})>>
      allReferenceFirearms() async {
    final rows = await (db.select(db.firearmsRef).join([
      innerJoin(db.manufacturers,
          db.manufacturers.id.equalsExp(db.firearmsRef.manufacturerId)),
    ])
          ..orderBy([
            OrderingTerm.asc(db.manufacturers.name),
            OrderingTerm.asc(db.firearmsRef.model),
          ]))
        .get();
    return rows.map((row) {
      final firearm = row.readTable(db.firearmsRef);
      final mfg = row.readTable(db.manufacturers);
      final calibers = (json.decode(firearm.calibersJson) as List<dynamic>)
          .cast<String>();
      return (firearm: firearm, manufacturer: mfg, calibers: calibers);
    }).toList();
  }
}
