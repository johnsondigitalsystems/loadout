// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ManufacturersTable extends Manufacturers
    with TableInfo<$ManufacturersTable, ManufacturerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ManufacturersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countryMeta = const VerificationMeta(
    'country',
  );
  @override
  late final GeneratedColumn<String> country = GeneratedColumn<String>(
    'country',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, country, kind];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'manufacturers';
  @override
  VerificationContext validateIntegrity(
    Insertable<ManufacturerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('country')) {
      context.handle(
        _countryMeta,
        country.isAcceptableOrUnknown(data['country']!, _countryMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {name, kind},
  ];
  @override
  ManufacturerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ManufacturerRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      country: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}country'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
    );
  }

  @override
  $ManufacturersTable createAlias(String alias) {
    return $ManufacturersTable(attachedDatabase, alias);
  }
}

class ManufacturerRow extends DataClass implements Insertable<ManufacturerRow> {
  final int id;
  final String name;
  final String? country;

  /// 'powder' | 'bullet' | 'primer' | 'brass' | 'firearm' | 'parts'
  final String kind;
  const ManufacturerRow({
    required this.id,
    required this.name,
    this.country,
    required this.kind,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || country != null) {
      map['country'] = Variable<String>(country);
    }
    map['kind'] = Variable<String>(kind);
    return map;
  }

  ManufacturersCompanion toCompanion(bool nullToAbsent) {
    return ManufacturersCompanion(
      id: Value(id),
      name: Value(name),
      country: country == null && nullToAbsent
          ? const Value.absent()
          : Value(country),
      kind: Value(kind),
    );
  }

  factory ManufacturerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ManufacturerRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      country: serializer.fromJson<String?>(json['country']),
      kind: serializer.fromJson<String>(json['kind']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'country': serializer.toJson<String?>(country),
      'kind': serializer.toJson<String>(kind),
    };
  }

  ManufacturerRow copyWith({
    int? id,
    String? name,
    Value<String?> country = const Value.absent(),
    String? kind,
  }) => ManufacturerRow(
    id: id ?? this.id,
    name: name ?? this.name,
    country: country.present ? country.value : this.country,
    kind: kind ?? this.kind,
  );
  ManufacturerRow copyWithCompanion(ManufacturersCompanion data) {
    return ManufacturerRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      country: data.country.present ? data.country.value : this.country,
      kind: data.kind.present ? data.kind.value : this.kind,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ManufacturerRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('country: $country, ')
          ..write('kind: $kind')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, country, kind);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ManufacturerRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.country == this.country &&
          other.kind == this.kind);
}

class ManufacturersCompanion extends UpdateCompanion<ManufacturerRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> country;
  final Value<String> kind;
  const ManufacturersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.country = const Value.absent(),
    this.kind = const Value.absent(),
  });
  ManufacturersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.country = const Value.absent(),
    required String kind,
  }) : name = Value(name),
       kind = Value(kind);
  static Insertable<ManufacturerRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? country,
    Expression<String>? kind,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (country != null) 'country': country,
      if (kind != null) 'kind': kind,
    });
  }

  ManufacturersCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? country,
    Value<String>? kind,
  }) {
    return ManufacturersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      country: country ?? this.country,
      kind: kind ?? this.kind,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (country.present) {
      map['country'] = Variable<String>(country.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ManufacturersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('country: $country, ')
          ..write('kind: $kind')
          ..write(')'))
        .toString();
  }
}

class $CartridgesTable extends Cartridges
    with TableInfo<$CartridgesTable, CartridgeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CartridgesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bulletDiameterInMeta = const VerificationMeta(
    'bulletDiameterIn',
  );
  @override
  late final GeneratedColumn<double> bulletDiameterIn = GeneratedColumn<double>(
    'bullet_diameter_in',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _caseLengthInMeta = const VerificationMeta(
    'caseLengthIn',
  );
  @override
  late final GeneratedColumn<double> caseLengthIn = GeneratedColumn<double>(
    'case_length_in',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxCoalInMeta = const VerificationMeta(
    'maxCoalIn',
  );
  @override
  late final GeneratedColumn<double> maxCoalIn = GeneratedColumn<double>(
    'max_coal_in',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gaugeMeta = const VerificationMeta('gauge');
  @override
  late final GeneratedColumn<double> gauge = GeneratedColumn<double>(
    'gauge',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shellLengthInMeta = const VerificationMeta(
    'shellLengthIn',
  );
  @override
  late final GeneratedColumn<double> shellLengthIn = GeneratedColumn<double>(
    'shell_length_in',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentCaseMeta = const VerificationMeta(
    'parentCase',
  );
  @override
  late final GeneratedColumn<String> parentCase = GeneratedColumn<String>(
    'parent_case',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearIntroducedMeta = const VerificationMeta(
    'yearIntroduced',
  );
  @override
  late final GeneratedColumn<int> yearIntroduced = GeneratedColumn<int>(
    'year_introduced',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aliasesJsonMeta = const VerificationMeta(
    'aliasesJson',
  );
  @override
  late final GeneratedColumn<String> aliasesJson = GeneratedColumn<String>(
    'aliases_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _bodyDiameterInMeta = const VerificationMeta(
    'bodyDiameterIn',
  );
  @override
  late final GeneratedColumn<double> bodyDiameterIn = GeneratedColumn<double>(
    'body_diameter_in',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shoulderDiameterInMeta =
      const VerificationMeta('shoulderDiameterIn');
  @override
  late final GeneratedColumn<double> shoulderDiameterIn =
      GeneratedColumn<double>(
        'shoulder_diameter_in',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _shoulderAngleDegMeta = const VerificationMeta(
    'shoulderAngleDeg',
  );
  @override
  late final GeneratedColumn<double> shoulderAngleDeg = GeneratedColumn<double>(
    'shoulder_angle_deg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _neckDiameterInMeta = const VerificationMeta(
    'neckDiameterIn',
  );
  @override
  late final GeneratedColumn<double> neckDiameterIn = GeneratedColumn<double>(
    'neck_diameter_in',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _neckLengthInMeta = const VerificationMeta(
    'neckLengthIn',
  );
  @override
  late final GeneratedColumn<double> neckLengthIn = GeneratedColumn<double>(
    'neck_length_in',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseToShoulderInMeta = const VerificationMeta(
    'baseToShoulderIn',
  );
  @override
  late final GeneratedColumn<double> baseToShoulderIn = GeneratedColumn<double>(
    'base_to_shoulder_in',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseToNeckInMeta = const VerificationMeta(
    'baseToNeckIn',
  );
  @override
  late final GeneratedColumn<double> baseToNeckIn = GeneratedColumn<double>(
    'base_to_neck_in',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rimDiameterInMeta = const VerificationMeta(
    'rimDiameterIn',
  );
  @override
  late final GeneratedColumn<double> rimDiameterIn = GeneratedColumn<double>(
    'rim_diameter_in',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rimThicknessInMeta = const VerificationMeta(
    'rimThicknessIn',
  );
  @override
  late final GeneratedColumn<double> rimThicknessIn = GeneratedColumn<double>(
    'rim_thickness_in',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _primerTypeMeta = const VerificationMeta(
    'primerType',
  );
  @override
  late final GeneratedColumn<String> primerType = GeneratedColumn<String>(
    'primer_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _twistRateMeta = const VerificationMeta(
    'twistRate',
  );
  @override
  late final GeneratedColumn<String> twistRate = GeneratedColumn<String>(
    'twist_rate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxAvgPressurePsiMeta = const VerificationMeta(
    'maxAvgPressurePsi',
  );
  @override
  late final GeneratedColumn<int> maxAvgPressurePsi = GeneratedColumn<int>(
    'max_avg_pressure_psi',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _boreDiameterInMeta = const VerificationMeta(
    'boreDiameterIn',
  );
  @override
  late final GeneratedColumn<double> boreDiameterIn = GeneratedColumn<double>(
    'bore_diameter_in',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _grooveDiameterInMeta = const VerificationMeta(
    'grooveDiameterIn',
  );
  @override
  late final GeneratedColumn<double> grooveDiameterIn = GeneratedColumn<double>(
    'groove_diameter_in',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _caseSubtypeMeta = const VerificationMeta(
    'caseSubtype',
  );
  @override
  late final GeneratedColumn<String> caseSubtype = GeneratedColumn<String>(
    'case_subtype',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _saamiDocMeta = const VerificationMeta(
    'saamiDoc',
  );
  @override
  late final GeneratedColumn<String> saamiDoc = GeneratedColumn<String>(
    'saami_doc',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    bulletDiameterIn,
    caseLengthIn,
    maxCoalIn,
    gauge,
    shellLengthIn,
    parentCase,
    yearIntroduced,
    aliasesJson,
    bodyDiameterIn,
    shoulderDiameterIn,
    shoulderAngleDeg,
    neckDiameterIn,
    neckLengthIn,
    baseToShoulderIn,
    baseToNeckIn,
    rimDiameterIn,
    rimThicknessIn,
    primerType,
    twistRate,
    maxAvgPressurePsi,
    boreDiameterIn,
    grooveDiameterIn,
    caseSubtype,
    saamiDoc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cartridges';
  @override
  VerificationContext validateIntegrity(
    Insertable<CartridgeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('bullet_diameter_in')) {
      context.handle(
        _bulletDiameterInMeta,
        bulletDiameterIn.isAcceptableOrUnknown(
          data['bullet_diameter_in']!,
          _bulletDiameterInMeta,
        ),
      );
    }
    if (data.containsKey('case_length_in')) {
      context.handle(
        _caseLengthInMeta,
        caseLengthIn.isAcceptableOrUnknown(
          data['case_length_in']!,
          _caseLengthInMeta,
        ),
      );
    }
    if (data.containsKey('max_coal_in')) {
      context.handle(
        _maxCoalInMeta,
        maxCoalIn.isAcceptableOrUnknown(data['max_coal_in']!, _maxCoalInMeta),
      );
    }
    if (data.containsKey('gauge')) {
      context.handle(
        _gaugeMeta,
        gauge.isAcceptableOrUnknown(data['gauge']!, _gaugeMeta),
      );
    }
    if (data.containsKey('shell_length_in')) {
      context.handle(
        _shellLengthInMeta,
        shellLengthIn.isAcceptableOrUnknown(
          data['shell_length_in']!,
          _shellLengthInMeta,
        ),
      );
    }
    if (data.containsKey('parent_case')) {
      context.handle(
        _parentCaseMeta,
        parentCase.isAcceptableOrUnknown(data['parent_case']!, _parentCaseMeta),
      );
    }
    if (data.containsKey('year_introduced')) {
      context.handle(
        _yearIntroducedMeta,
        yearIntroduced.isAcceptableOrUnknown(
          data['year_introduced']!,
          _yearIntroducedMeta,
        ),
      );
    }
    if (data.containsKey('aliases_json')) {
      context.handle(
        _aliasesJsonMeta,
        aliasesJson.isAcceptableOrUnknown(
          data['aliases_json']!,
          _aliasesJsonMeta,
        ),
      );
    }
    if (data.containsKey('body_diameter_in')) {
      context.handle(
        _bodyDiameterInMeta,
        bodyDiameterIn.isAcceptableOrUnknown(
          data['body_diameter_in']!,
          _bodyDiameterInMeta,
        ),
      );
    }
    if (data.containsKey('shoulder_diameter_in')) {
      context.handle(
        _shoulderDiameterInMeta,
        shoulderDiameterIn.isAcceptableOrUnknown(
          data['shoulder_diameter_in']!,
          _shoulderDiameterInMeta,
        ),
      );
    }
    if (data.containsKey('shoulder_angle_deg')) {
      context.handle(
        _shoulderAngleDegMeta,
        shoulderAngleDeg.isAcceptableOrUnknown(
          data['shoulder_angle_deg']!,
          _shoulderAngleDegMeta,
        ),
      );
    }
    if (data.containsKey('neck_diameter_in')) {
      context.handle(
        _neckDiameterInMeta,
        neckDiameterIn.isAcceptableOrUnknown(
          data['neck_diameter_in']!,
          _neckDiameterInMeta,
        ),
      );
    }
    if (data.containsKey('neck_length_in')) {
      context.handle(
        _neckLengthInMeta,
        neckLengthIn.isAcceptableOrUnknown(
          data['neck_length_in']!,
          _neckLengthInMeta,
        ),
      );
    }
    if (data.containsKey('base_to_shoulder_in')) {
      context.handle(
        _baseToShoulderInMeta,
        baseToShoulderIn.isAcceptableOrUnknown(
          data['base_to_shoulder_in']!,
          _baseToShoulderInMeta,
        ),
      );
    }
    if (data.containsKey('base_to_neck_in')) {
      context.handle(
        _baseToNeckInMeta,
        baseToNeckIn.isAcceptableOrUnknown(
          data['base_to_neck_in']!,
          _baseToNeckInMeta,
        ),
      );
    }
    if (data.containsKey('rim_diameter_in')) {
      context.handle(
        _rimDiameterInMeta,
        rimDiameterIn.isAcceptableOrUnknown(
          data['rim_diameter_in']!,
          _rimDiameterInMeta,
        ),
      );
    }
    if (data.containsKey('rim_thickness_in')) {
      context.handle(
        _rimThicknessInMeta,
        rimThicknessIn.isAcceptableOrUnknown(
          data['rim_thickness_in']!,
          _rimThicknessInMeta,
        ),
      );
    }
    if (data.containsKey('primer_type')) {
      context.handle(
        _primerTypeMeta,
        primerType.isAcceptableOrUnknown(data['primer_type']!, _primerTypeMeta),
      );
    }
    if (data.containsKey('twist_rate')) {
      context.handle(
        _twistRateMeta,
        twistRate.isAcceptableOrUnknown(data['twist_rate']!, _twistRateMeta),
      );
    }
    if (data.containsKey('max_avg_pressure_psi')) {
      context.handle(
        _maxAvgPressurePsiMeta,
        maxAvgPressurePsi.isAcceptableOrUnknown(
          data['max_avg_pressure_psi']!,
          _maxAvgPressurePsiMeta,
        ),
      );
    }
    if (data.containsKey('bore_diameter_in')) {
      context.handle(
        _boreDiameterInMeta,
        boreDiameterIn.isAcceptableOrUnknown(
          data['bore_diameter_in']!,
          _boreDiameterInMeta,
        ),
      );
    }
    if (data.containsKey('groove_diameter_in')) {
      context.handle(
        _grooveDiameterInMeta,
        grooveDiameterIn.isAcceptableOrUnknown(
          data['groove_diameter_in']!,
          _grooveDiameterInMeta,
        ),
      );
    }
    if (data.containsKey('case_subtype')) {
      context.handle(
        _caseSubtypeMeta,
        caseSubtype.isAcceptableOrUnknown(
          data['case_subtype']!,
          _caseSubtypeMeta,
        ),
      );
    }
    if (data.containsKey('saami_doc')) {
      context.handle(
        _saamiDocMeta,
        saamiDoc.isAcceptableOrUnknown(data['saami_doc']!, _saamiDocMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CartridgeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CartridgeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      bulletDiameterIn: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bullet_diameter_in'],
      ),
      caseLengthIn: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}case_length_in'],
      ),
      maxCoalIn: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_coal_in'],
      ),
      gauge: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}gauge'],
      ),
      shellLengthIn: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}shell_length_in'],
      ),
      parentCase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_case'],
      ),
      yearIntroduced: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year_introduced'],
      ),
      aliasesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aliases_json'],
      )!,
      bodyDiameterIn: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}body_diameter_in'],
      ),
      shoulderDiameterIn: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}shoulder_diameter_in'],
      ),
      shoulderAngleDeg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}shoulder_angle_deg'],
      ),
      neckDiameterIn: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}neck_diameter_in'],
      ),
      neckLengthIn: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}neck_length_in'],
      ),
      baseToShoulderIn: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}base_to_shoulder_in'],
      ),
      baseToNeckIn: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}base_to_neck_in'],
      ),
      rimDiameterIn: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rim_diameter_in'],
      ),
      rimThicknessIn: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rim_thickness_in'],
      ),
      primerType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primer_type'],
      ),
      twistRate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}twist_rate'],
      ),
      maxAvgPressurePsi: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_avg_pressure_psi'],
      ),
      boreDiameterIn: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bore_diameter_in'],
      ),
      grooveDiameterIn: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}groove_diameter_in'],
      ),
      caseSubtype: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}case_subtype'],
      ),
      saamiDoc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}saami_doc'],
      ),
    );
  }

  @override
  $CartridgesTable createAlias(String alias) {
    return $CartridgesTable(attachedDatabase, alias);
  }
}

class CartridgeRow extends DataClass implements Insertable<CartridgeRow> {
  final int id;
  final String name;

  /// 'pistol' | 'rifle' | 'shotgun'
  final String type;
  final double? bulletDiameterIn;
  final double? caseLengthIn;
  final double? maxCoalIn;
  final double? gauge;
  final double? shellLengthIn;
  final String? parentCase;
  final int? yearIntroduced;

  /// JSON array of alias strings
  final String aliasesJson;
  final double? bodyDiameterIn;
  final double? shoulderDiameterIn;
  final double? shoulderAngleDeg;
  final double? neckDiameterIn;
  final double? neckLengthIn;
  final double? baseToShoulderIn;
  final double? baseToNeckIn;
  final double? rimDiameterIn;
  final double? rimThicknessIn;

  /// 'small-pistol' | 'large-pistol' | 'small-rifle' | 'large-rifle' | 'berdan'
  final String? primerType;

  /// e.g. '1:8'
  final String? twistRate;
  final int? maxAvgPressurePsi;
  final double? boreDiameterIn;
  final double? grooveDiameterIn;

  /// 'bottleneck' | 'straight' | 'belted-bottleneck' | etc.
  final String? caseSubtype;

  /// 'Z299.1' | 'Z299.3' | 'Z299.4'
  final String? saamiDoc;
  const CartridgeRow({
    required this.id,
    required this.name,
    required this.type,
    this.bulletDiameterIn,
    this.caseLengthIn,
    this.maxCoalIn,
    this.gauge,
    this.shellLengthIn,
    this.parentCase,
    this.yearIntroduced,
    required this.aliasesJson,
    this.bodyDiameterIn,
    this.shoulderDiameterIn,
    this.shoulderAngleDeg,
    this.neckDiameterIn,
    this.neckLengthIn,
    this.baseToShoulderIn,
    this.baseToNeckIn,
    this.rimDiameterIn,
    this.rimThicknessIn,
    this.primerType,
    this.twistRate,
    this.maxAvgPressurePsi,
    this.boreDiameterIn,
    this.grooveDiameterIn,
    this.caseSubtype,
    this.saamiDoc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || bulletDiameterIn != null) {
      map['bullet_diameter_in'] = Variable<double>(bulletDiameterIn);
    }
    if (!nullToAbsent || caseLengthIn != null) {
      map['case_length_in'] = Variable<double>(caseLengthIn);
    }
    if (!nullToAbsent || maxCoalIn != null) {
      map['max_coal_in'] = Variable<double>(maxCoalIn);
    }
    if (!nullToAbsent || gauge != null) {
      map['gauge'] = Variable<double>(gauge);
    }
    if (!nullToAbsent || shellLengthIn != null) {
      map['shell_length_in'] = Variable<double>(shellLengthIn);
    }
    if (!nullToAbsent || parentCase != null) {
      map['parent_case'] = Variable<String>(parentCase);
    }
    if (!nullToAbsent || yearIntroduced != null) {
      map['year_introduced'] = Variable<int>(yearIntroduced);
    }
    map['aliases_json'] = Variable<String>(aliasesJson);
    if (!nullToAbsent || bodyDiameterIn != null) {
      map['body_diameter_in'] = Variable<double>(bodyDiameterIn);
    }
    if (!nullToAbsent || shoulderDiameterIn != null) {
      map['shoulder_diameter_in'] = Variable<double>(shoulderDiameterIn);
    }
    if (!nullToAbsent || shoulderAngleDeg != null) {
      map['shoulder_angle_deg'] = Variable<double>(shoulderAngleDeg);
    }
    if (!nullToAbsent || neckDiameterIn != null) {
      map['neck_diameter_in'] = Variable<double>(neckDiameterIn);
    }
    if (!nullToAbsent || neckLengthIn != null) {
      map['neck_length_in'] = Variable<double>(neckLengthIn);
    }
    if (!nullToAbsent || baseToShoulderIn != null) {
      map['base_to_shoulder_in'] = Variable<double>(baseToShoulderIn);
    }
    if (!nullToAbsent || baseToNeckIn != null) {
      map['base_to_neck_in'] = Variable<double>(baseToNeckIn);
    }
    if (!nullToAbsent || rimDiameterIn != null) {
      map['rim_diameter_in'] = Variable<double>(rimDiameterIn);
    }
    if (!nullToAbsent || rimThicknessIn != null) {
      map['rim_thickness_in'] = Variable<double>(rimThicknessIn);
    }
    if (!nullToAbsent || primerType != null) {
      map['primer_type'] = Variable<String>(primerType);
    }
    if (!nullToAbsent || twistRate != null) {
      map['twist_rate'] = Variable<String>(twistRate);
    }
    if (!nullToAbsent || maxAvgPressurePsi != null) {
      map['max_avg_pressure_psi'] = Variable<int>(maxAvgPressurePsi);
    }
    if (!nullToAbsent || boreDiameterIn != null) {
      map['bore_diameter_in'] = Variable<double>(boreDiameterIn);
    }
    if (!nullToAbsent || grooveDiameterIn != null) {
      map['groove_diameter_in'] = Variable<double>(grooveDiameterIn);
    }
    if (!nullToAbsent || caseSubtype != null) {
      map['case_subtype'] = Variable<String>(caseSubtype);
    }
    if (!nullToAbsent || saamiDoc != null) {
      map['saami_doc'] = Variable<String>(saamiDoc);
    }
    return map;
  }

  CartridgesCompanion toCompanion(bool nullToAbsent) {
    return CartridgesCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      bulletDiameterIn: bulletDiameterIn == null && nullToAbsent
          ? const Value.absent()
          : Value(bulletDiameterIn),
      caseLengthIn: caseLengthIn == null && nullToAbsent
          ? const Value.absent()
          : Value(caseLengthIn),
      maxCoalIn: maxCoalIn == null && nullToAbsent
          ? const Value.absent()
          : Value(maxCoalIn),
      gauge: gauge == null && nullToAbsent
          ? const Value.absent()
          : Value(gauge),
      shellLengthIn: shellLengthIn == null && nullToAbsent
          ? const Value.absent()
          : Value(shellLengthIn),
      parentCase: parentCase == null && nullToAbsent
          ? const Value.absent()
          : Value(parentCase),
      yearIntroduced: yearIntroduced == null && nullToAbsent
          ? const Value.absent()
          : Value(yearIntroduced),
      aliasesJson: Value(aliasesJson),
      bodyDiameterIn: bodyDiameterIn == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyDiameterIn),
      shoulderDiameterIn: shoulderDiameterIn == null && nullToAbsent
          ? const Value.absent()
          : Value(shoulderDiameterIn),
      shoulderAngleDeg: shoulderAngleDeg == null && nullToAbsent
          ? const Value.absent()
          : Value(shoulderAngleDeg),
      neckDiameterIn: neckDiameterIn == null && nullToAbsent
          ? const Value.absent()
          : Value(neckDiameterIn),
      neckLengthIn: neckLengthIn == null && nullToAbsent
          ? const Value.absent()
          : Value(neckLengthIn),
      baseToShoulderIn: baseToShoulderIn == null && nullToAbsent
          ? const Value.absent()
          : Value(baseToShoulderIn),
      baseToNeckIn: baseToNeckIn == null && nullToAbsent
          ? const Value.absent()
          : Value(baseToNeckIn),
      rimDiameterIn: rimDiameterIn == null && nullToAbsent
          ? const Value.absent()
          : Value(rimDiameterIn),
      rimThicknessIn: rimThicknessIn == null && nullToAbsent
          ? const Value.absent()
          : Value(rimThicknessIn),
      primerType: primerType == null && nullToAbsent
          ? const Value.absent()
          : Value(primerType),
      twistRate: twistRate == null && nullToAbsent
          ? const Value.absent()
          : Value(twistRate),
      maxAvgPressurePsi: maxAvgPressurePsi == null && nullToAbsent
          ? const Value.absent()
          : Value(maxAvgPressurePsi),
      boreDiameterIn: boreDiameterIn == null && nullToAbsent
          ? const Value.absent()
          : Value(boreDiameterIn),
      grooveDiameterIn: grooveDiameterIn == null && nullToAbsent
          ? const Value.absent()
          : Value(grooveDiameterIn),
      caseSubtype: caseSubtype == null && nullToAbsent
          ? const Value.absent()
          : Value(caseSubtype),
      saamiDoc: saamiDoc == null && nullToAbsent
          ? const Value.absent()
          : Value(saamiDoc),
    );
  }

  factory CartridgeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CartridgeRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      bulletDiameterIn: serializer.fromJson<double?>(json['bulletDiameterIn']),
      caseLengthIn: serializer.fromJson<double?>(json['caseLengthIn']),
      maxCoalIn: serializer.fromJson<double?>(json['maxCoalIn']),
      gauge: serializer.fromJson<double?>(json['gauge']),
      shellLengthIn: serializer.fromJson<double?>(json['shellLengthIn']),
      parentCase: serializer.fromJson<String?>(json['parentCase']),
      yearIntroduced: serializer.fromJson<int?>(json['yearIntroduced']),
      aliasesJson: serializer.fromJson<String>(json['aliasesJson']),
      bodyDiameterIn: serializer.fromJson<double?>(json['bodyDiameterIn']),
      shoulderDiameterIn: serializer.fromJson<double?>(
        json['shoulderDiameterIn'],
      ),
      shoulderAngleDeg: serializer.fromJson<double?>(json['shoulderAngleDeg']),
      neckDiameterIn: serializer.fromJson<double?>(json['neckDiameterIn']),
      neckLengthIn: serializer.fromJson<double?>(json['neckLengthIn']),
      baseToShoulderIn: serializer.fromJson<double?>(json['baseToShoulderIn']),
      baseToNeckIn: serializer.fromJson<double?>(json['baseToNeckIn']),
      rimDiameterIn: serializer.fromJson<double?>(json['rimDiameterIn']),
      rimThicknessIn: serializer.fromJson<double?>(json['rimThicknessIn']),
      primerType: serializer.fromJson<String?>(json['primerType']),
      twistRate: serializer.fromJson<String?>(json['twistRate']),
      maxAvgPressurePsi: serializer.fromJson<int?>(json['maxAvgPressurePsi']),
      boreDiameterIn: serializer.fromJson<double?>(json['boreDiameterIn']),
      grooveDiameterIn: serializer.fromJson<double?>(json['grooveDiameterIn']),
      caseSubtype: serializer.fromJson<String?>(json['caseSubtype']),
      saamiDoc: serializer.fromJson<String?>(json['saamiDoc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'bulletDiameterIn': serializer.toJson<double?>(bulletDiameterIn),
      'caseLengthIn': serializer.toJson<double?>(caseLengthIn),
      'maxCoalIn': serializer.toJson<double?>(maxCoalIn),
      'gauge': serializer.toJson<double?>(gauge),
      'shellLengthIn': serializer.toJson<double?>(shellLengthIn),
      'parentCase': serializer.toJson<String?>(parentCase),
      'yearIntroduced': serializer.toJson<int?>(yearIntroduced),
      'aliasesJson': serializer.toJson<String>(aliasesJson),
      'bodyDiameterIn': serializer.toJson<double?>(bodyDiameterIn),
      'shoulderDiameterIn': serializer.toJson<double?>(shoulderDiameterIn),
      'shoulderAngleDeg': serializer.toJson<double?>(shoulderAngleDeg),
      'neckDiameterIn': serializer.toJson<double?>(neckDiameterIn),
      'neckLengthIn': serializer.toJson<double?>(neckLengthIn),
      'baseToShoulderIn': serializer.toJson<double?>(baseToShoulderIn),
      'baseToNeckIn': serializer.toJson<double?>(baseToNeckIn),
      'rimDiameterIn': serializer.toJson<double?>(rimDiameterIn),
      'rimThicknessIn': serializer.toJson<double?>(rimThicknessIn),
      'primerType': serializer.toJson<String?>(primerType),
      'twistRate': serializer.toJson<String?>(twistRate),
      'maxAvgPressurePsi': serializer.toJson<int?>(maxAvgPressurePsi),
      'boreDiameterIn': serializer.toJson<double?>(boreDiameterIn),
      'grooveDiameterIn': serializer.toJson<double?>(grooveDiameterIn),
      'caseSubtype': serializer.toJson<String?>(caseSubtype),
      'saamiDoc': serializer.toJson<String?>(saamiDoc),
    };
  }

  CartridgeRow copyWith({
    int? id,
    String? name,
    String? type,
    Value<double?> bulletDiameterIn = const Value.absent(),
    Value<double?> caseLengthIn = const Value.absent(),
    Value<double?> maxCoalIn = const Value.absent(),
    Value<double?> gauge = const Value.absent(),
    Value<double?> shellLengthIn = const Value.absent(),
    Value<String?> parentCase = const Value.absent(),
    Value<int?> yearIntroduced = const Value.absent(),
    String? aliasesJson,
    Value<double?> bodyDiameterIn = const Value.absent(),
    Value<double?> shoulderDiameterIn = const Value.absent(),
    Value<double?> shoulderAngleDeg = const Value.absent(),
    Value<double?> neckDiameterIn = const Value.absent(),
    Value<double?> neckLengthIn = const Value.absent(),
    Value<double?> baseToShoulderIn = const Value.absent(),
    Value<double?> baseToNeckIn = const Value.absent(),
    Value<double?> rimDiameterIn = const Value.absent(),
    Value<double?> rimThicknessIn = const Value.absent(),
    Value<String?> primerType = const Value.absent(),
    Value<String?> twistRate = const Value.absent(),
    Value<int?> maxAvgPressurePsi = const Value.absent(),
    Value<double?> boreDiameterIn = const Value.absent(),
    Value<double?> grooveDiameterIn = const Value.absent(),
    Value<String?> caseSubtype = const Value.absent(),
    Value<String?> saamiDoc = const Value.absent(),
  }) => CartridgeRow(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    bulletDiameterIn: bulletDiameterIn.present
        ? bulletDiameterIn.value
        : this.bulletDiameterIn,
    caseLengthIn: caseLengthIn.present ? caseLengthIn.value : this.caseLengthIn,
    maxCoalIn: maxCoalIn.present ? maxCoalIn.value : this.maxCoalIn,
    gauge: gauge.present ? gauge.value : this.gauge,
    shellLengthIn: shellLengthIn.present
        ? shellLengthIn.value
        : this.shellLengthIn,
    parentCase: parentCase.present ? parentCase.value : this.parentCase,
    yearIntroduced: yearIntroduced.present
        ? yearIntroduced.value
        : this.yearIntroduced,
    aliasesJson: aliasesJson ?? this.aliasesJson,
    bodyDiameterIn: bodyDiameterIn.present
        ? bodyDiameterIn.value
        : this.bodyDiameterIn,
    shoulderDiameterIn: shoulderDiameterIn.present
        ? shoulderDiameterIn.value
        : this.shoulderDiameterIn,
    shoulderAngleDeg: shoulderAngleDeg.present
        ? shoulderAngleDeg.value
        : this.shoulderAngleDeg,
    neckDiameterIn: neckDiameterIn.present
        ? neckDiameterIn.value
        : this.neckDiameterIn,
    neckLengthIn: neckLengthIn.present ? neckLengthIn.value : this.neckLengthIn,
    baseToShoulderIn: baseToShoulderIn.present
        ? baseToShoulderIn.value
        : this.baseToShoulderIn,
    baseToNeckIn: baseToNeckIn.present ? baseToNeckIn.value : this.baseToNeckIn,
    rimDiameterIn: rimDiameterIn.present
        ? rimDiameterIn.value
        : this.rimDiameterIn,
    rimThicknessIn: rimThicknessIn.present
        ? rimThicknessIn.value
        : this.rimThicknessIn,
    primerType: primerType.present ? primerType.value : this.primerType,
    twistRate: twistRate.present ? twistRate.value : this.twistRate,
    maxAvgPressurePsi: maxAvgPressurePsi.present
        ? maxAvgPressurePsi.value
        : this.maxAvgPressurePsi,
    boreDiameterIn: boreDiameterIn.present
        ? boreDiameterIn.value
        : this.boreDiameterIn,
    grooveDiameterIn: grooveDiameterIn.present
        ? grooveDiameterIn.value
        : this.grooveDiameterIn,
    caseSubtype: caseSubtype.present ? caseSubtype.value : this.caseSubtype,
    saamiDoc: saamiDoc.present ? saamiDoc.value : this.saamiDoc,
  );
  CartridgeRow copyWithCompanion(CartridgesCompanion data) {
    return CartridgeRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      bulletDiameterIn: data.bulletDiameterIn.present
          ? data.bulletDiameterIn.value
          : this.bulletDiameterIn,
      caseLengthIn: data.caseLengthIn.present
          ? data.caseLengthIn.value
          : this.caseLengthIn,
      maxCoalIn: data.maxCoalIn.present ? data.maxCoalIn.value : this.maxCoalIn,
      gauge: data.gauge.present ? data.gauge.value : this.gauge,
      shellLengthIn: data.shellLengthIn.present
          ? data.shellLengthIn.value
          : this.shellLengthIn,
      parentCase: data.parentCase.present
          ? data.parentCase.value
          : this.parentCase,
      yearIntroduced: data.yearIntroduced.present
          ? data.yearIntroduced.value
          : this.yearIntroduced,
      aliasesJson: data.aliasesJson.present
          ? data.aliasesJson.value
          : this.aliasesJson,
      bodyDiameterIn: data.bodyDiameterIn.present
          ? data.bodyDiameterIn.value
          : this.bodyDiameterIn,
      shoulderDiameterIn: data.shoulderDiameterIn.present
          ? data.shoulderDiameterIn.value
          : this.shoulderDiameterIn,
      shoulderAngleDeg: data.shoulderAngleDeg.present
          ? data.shoulderAngleDeg.value
          : this.shoulderAngleDeg,
      neckDiameterIn: data.neckDiameterIn.present
          ? data.neckDiameterIn.value
          : this.neckDiameterIn,
      neckLengthIn: data.neckLengthIn.present
          ? data.neckLengthIn.value
          : this.neckLengthIn,
      baseToShoulderIn: data.baseToShoulderIn.present
          ? data.baseToShoulderIn.value
          : this.baseToShoulderIn,
      baseToNeckIn: data.baseToNeckIn.present
          ? data.baseToNeckIn.value
          : this.baseToNeckIn,
      rimDiameterIn: data.rimDiameterIn.present
          ? data.rimDiameterIn.value
          : this.rimDiameterIn,
      rimThicknessIn: data.rimThicknessIn.present
          ? data.rimThicknessIn.value
          : this.rimThicknessIn,
      primerType: data.primerType.present
          ? data.primerType.value
          : this.primerType,
      twistRate: data.twistRate.present ? data.twistRate.value : this.twistRate,
      maxAvgPressurePsi: data.maxAvgPressurePsi.present
          ? data.maxAvgPressurePsi.value
          : this.maxAvgPressurePsi,
      boreDiameterIn: data.boreDiameterIn.present
          ? data.boreDiameterIn.value
          : this.boreDiameterIn,
      grooveDiameterIn: data.grooveDiameterIn.present
          ? data.grooveDiameterIn.value
          : this.grooveDiameterIn,
      caseSubtype: data.caseSubtype.present
          ? data.caseSubtype.value
          : this.caseSubtype,
      saamiDoc: data.saamiDoc.present ? data.saamiDoc.value : this.saamiDoc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CartridgeRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('bulletDiameterIn: $bulletDiameterIn, ')
          ..write('caseLengthIn: $caseLengthIn, ')
          ..write('maxCoalIn: $maxCoalIn, ')
          ..write('gauge: $gauge, ')
          ..write('shellLengthIn: $shellLengthIn, ')
          ..write('parentCase: $parentCase, ')
          ..write('yearIntroduced: $yearIntroduced, ')
          ..write('aliasesJson: $aliasesJson, ')
          ..write('bodyDiameterIn: $bodyDiameterIn, ')
          ..write('shoulderDiameterIn: $shoulderDiameterIn, ')
          ..write('shoulderAngleDeg: $shoulderAngleDeg, ')
          ..write('neckDiameterIn: $neckDiameterIn, ')
          ..write('neckLengthIn: $neckLengthIn, ')
          ..write('baseToShoulderIn: $baseToShoulderIn, ')
          ..write('baseToNeckIn: $baseToNeckIn, ')
          ..write('rimDiameterIn: $rimDiameterIn, ')
          ..write('rimThicknessIn: $rimThicknessIn, ')
          ..write('primerType: $primerType, ')
          ..write('twistRate: $twistRate, ')
          ..write('maxAvgPressurePsi: $maxAvgPressurePsi, ')
          ..write('boreDiameterIn: $boreDiameterIn, ')
          ..write('grooveDiameterIn: $grooveDiameterIn, ')
          ..write('caseSubtype: $caseSubtype, ')
          ..write('saamiDoc: $saamiDoc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    type,
    bulletDiameterIn,
    caseLengthIn,
    maxCoalIn,
    gauge,
    shellLengthIn,
    parentCase,
    yearIntroduced,
    aliasesJson,
    bodyDiameterIn,
    shoulderDiameterIn,
    shoulderAngleDeg,
    neckDiameterIn,
    neckLengthIn,
    baseToShoulderIn,
    baseToNeckIn,
    rimDiameterIn,
    rimThicknessIn,
    primerType,
    twistRate,
    maxAvgPressurePsi,
    boreDiameterIn,
    grooveDiameterIn,
    caseSubtype,
    saamiDoc,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CartridgeRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.bulletDiameterIn == this.bulletDiameterIn &&
          other.caseLengthIn == this.caseLengthIn &&
          other.maxCoalIn == this.maxCoalIn &&
          other.gauge == this.gauge &&
          other.shellLengthIn == this.shellLengthIn &&
          other.parentCase == this.parentCase &&
          other.yearIntroduced == this.yearIntroduced &&
          other.aliasesJson == this.aliasesJson &&
          other.bodyDiameterIn == this.bodyDiameterIn &&
          other.shoulderDiameterIn == this.shoulderDiameterIn &&
          other.shoulderAngleDeg == this.shoulderAngleDeg &&
          other.neckDiameterIn == this.neckDiameterIn &&
          other.neckLengthIn == this.neckLengthIn &&
          other.baseToShoulderIn == this.baseToShoulderIn &&
          other.baseToNeckIn == this.baseToNeckIn &&
          other.rimDiameterIn == this.rimDiameterIn &&
          other.rimThicknessIn == this.rimThicknessIn &&
          other.primerType == this.primerType &&
          other.twistRate == this.twistRate &&
          other.maxAvgPressurePsi == this.maxAvgPressurePsi &&
          other.boreDiameterIn == this.boreDiameterIn &&
          other.grooveDiameterIn == this.grooveDiameterIn &&
          other.caseSubtype == this.caseSubtype &&
          other.saamiDoc == this.saamiDoc);
}

class CartridgesCompanion extends UpdateCompanion<CartridgeRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> type;
  final Value<double?> bulletDiameterIn;
  final Value<double?> caseLengthIn;
  final Value<double?> maxCoalIn;
  final Value<double?> gauge;
  final Value<double?> shellLengthIn;
  final Value<String?> parentCase;
  final Value<int?> yearIntroduced;
  final Value<String> aliasesJson;
  final Value<double?> bodyDiameterIn;
  final Value<double?> shoulderDiameterIn;
  final Value<double?> shoulderAngleDeg;
  final Value<double?> neckDiameterIn;
  final Value<double?> neckLengthIn;
  final Value<double?> baseToShoulderIn;
  final Value<double?> baseToNeckIn;
  final Value<double?> rimDiameterIn;
  final Value<double?> rimThicknessIn;
  final Value<String?> primerType;
  final Value<String?> twistRate;
  final Value<int?> maxAvgPressurePsi;
  final Value<double?> boreDiameterIn;
  final Value<double?> grooveDiameterIn;
  final Value<String?> caseSubtype;
  final Value<String?> saamiDoc;
  const CartridgesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.bulletDiameterIn = const Value.absent(),
    this.caseLengthIn = const Value.absent(),
    this.maxCoalIn = const Value.absent(),
    this.gauge = const Value.absent(),
    this.shellLengthIn = const Value.absent(),
    this.parentCase = const Value.absent(),
    this.yearIntroduced = const Value.absent(),
    this.aliasesJson = const Value.absent(),
    this.bodyDiameterIn = const Value.absent(),
    this.shoulderDiameterIn = const Value.absent(),
    this.shoulderAngleDeg = const Value.absent(),
    this.neckDiameterIn = const Value.absent(),
    this.neckLengthIn = const Value.absent(),
    this.baseToShoulderIn = const Value.absent(),
    this.baseToNeckIn = const Value.absent(),
    this.rimDiameterIn = const Value.absent(),
    this.rimThicknessIn = const Value.absent(),
    this.primerType = const Value.absent(),
    this.twistRate = const Value.absent(),
    this.maxAvgPressurePsi = const Value.absent(),
    this.boreDiameterIn = const Value.absent(),
    this.grooveDiameterIn = const Value.absent(),
    this.caseSubtype = const Value.absent(),
    this.saamiDoc = const Value.absent(),
  });
  CartridgesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String type,
    this.bulletDiameterIn = const Value.absent(),
    this.caseLengthIn = const Value.absent(),
    this.maxCoalIn = const Value.absent(),
    this.gauge = const Value.absent(),
    this.shellLengthIn = const Value.absent(),
    this.parentCase = const Value.absent(),
    this.yearIntroduced = const Value.absent(),
    this.aliasesJson = const Value.absent(),
    this.bodyDiameterIn = const Value.absent(),
    this.shoulderDiameterIn = const Value.absent(),
    this.shoulderAngleDeg = const Value.absent(),
    this.neckDiameterIn = const Value.absent(),
    this.neckLengthIn = const Value.absent(),
    this.baseToShoulderIn = const Value.absent(),
    this.baseToNeckIn = const Value.absent(),
    this.rimDiameterIn = const Value.absent(),
    this.rimThicknessIn = const Value.absent(),
    this.primerType = const Value.absent(),
    this.twistRate = const Value.absent(),
    this.maxAvgPressurePsi = const Value.absent(),
    this.boreDiameterIn = const Value.absent(),
    this.grooveDiameterIn = const Value.absent(),
    this.caseSubtype = const Value.absent(),
    this.saamiDoc = const Value.absent(),
  }) : name = Value(name),
       type = Value(type);
  static Insertable<CartridgeRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<double>? bulletDiameterIn,
    Expression<double>? caseLengthIn,
    Expression<double>? maxCoalIn,
    Expression<double>? gauge,
    Expression<double>? shellLengthIn,
    Expression<String>? parentCase,
    Expression<int>? yearIntroduced,
    Expression<String>? aliasesJson,
    Expression<double>? bodyDiameterIn,
    Expression<double>? shoulderDiameterIn,
    Expression<double>? shoulderAngleDeg,
    Expression<double>? neckDiameterIn,
    Expression<double>? neckLengthIn,
    Expression<double>? baseToShoulderIn,
    Expression<double>? baseToNeckIn,
    Expression<double>? rimDiameterIn,
    Expression<double>? rimThicknessIn,
    Expression<String>? primerType,
    Expression<String>? twistRate,
    Expression<int>? maxAvgPressurePsi,
    Expression<double>? boreDiameterIn,
    Expression<double>? grooveDiameterIn,
    Expression<String>? caseSubtype,
    Expression<String>? saamiDoc,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (bulletDiameterIn != null) 'bullet_diameter_in': bulletDiameterIn,
      if (caseLengthIn != null) 'case_length_in': caseLengthIn,
      if (maxCoalIn != null) 'max_coal_in': maxCoalIn,
      if (gauge != null) 'gauge': gauge,
      if (shellLengthIn != null) 'shell_length_in': shellLengthIn,
      if (parentCase != null) 'parent_case': parentCase,
      if (yearIntroduced != null) 'year_introduced': yearIntroduced,
      if (aliasesJson != null) 'aliases_json': aliasesJson,
      if (bodyDiameterIn != null) 'body_diameter_in': bodyDiameterIn,
      if (shoulderDiameterIn != null)
        'shoulder_diameter_in': shoulderDiameterIn,
      if (shoulderAngleDeg != null) 'shoulder_angle_deg': shoulderAngleDeg,
      if (neckDiameterIn != null) 'neck_diameter_in': neckDiameterIn,
      if (neckLengthIn != null) 'neck_length_in': neckLengthIn,
      if (baseToShoulderIn != null) 'base_to_shoulder_in': baseToShoulderIn,
      if (baseToNeckIn != null) 'base_to_neck_in': baseToNeckIn,
      if (rimDiameterIn != null) 'rim_diameter_in': rimDiameterIn,
      if (rimThicknessIn != null) 'rim_thickness_in': rimThicknessIn,
      if (primerType != null) 'primer_type': primerType,
      if (twistRate != null) 'twist_rate': twistRate,
      if (maxAvgPressurePsi != null) 'max_avg_pressure_psi': maxAvgPressurePsi,
      if (boreDiameterIn != null) 'bore_diameter_in': boreDiameterIn,
      if (grooveDiameterIn != null) 'groove_diameter_in': grooveDiameterIn,
      if (caseSubtype != null) 'case_subtype': caseSubtype,
      if (saamiDoc != null) 'saami_doc': saamiDoc,
    });
  }

  CartridgesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? type,
    Value<double?>? bulletDiameterIn,
    Value<double?>? caseLengthIn,
    Value<double?>? maxCoalIn,
    Value<double?>? gauge,
    Value<double?>? shellLengthIn,
    Value<String?>? parentCase,
    Value<int?>? yearIntroduced,
    Value<String>? aliasesJson,
    Value<double?>? bodyDiameterIn,
    Value<double?>? shoulderDiameterIn,
    Value<double?>? shoulderAngleDeg,
    Value<double?>? neckDiameterIn,
    Value<double?>? neckLengthIn,
    Value<double?>? baseToShoulderIn,
    Value<double?>? baseToNeckIn,
    Value<double?>? rimDiameterIn,
    Value<double?>? rimThicknessIn,
    Value<String?>? primerType,
    Value<String?>? twistRate,
    Value<int?>? maxAvgPressurePsi,
    Value<double?>? boreDiameterIn,
    Value<double?>? grooveDiameterIn,
    Value<String?>? caseSubtype,
    Value<String?>? saamiDoc,
  }) {
    return CartridgesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      bulletDiameterIn: bulletDiameterIn ?? this.bulletDiameterIn,
      caseLengthIn: caseLengthIn ?? this.caseLengthIn,
      maxCoalIn: maxCoalIn ?? this.maxCoalIn,
      gauge: gauge ?? this.gauge,
      shellLengthIn: shellLengthIn ?? this.shellLengthIn,
      parentCase: parentCase ?? this.parentCase,
      yearIntroduced: yearIntroduced ?? this.yearIntroduced,
      aliasesJson: aliasesJson ?? this.aliasesJson,
      bodyDiameterIn: bodyDiameterIn ?? this.bodyDiameterIn,
      shoulderDiameterIn: shoulderDiameterIn ?? this.shoulderDiameterIn,
      shoulderAngleDeg: shoulderAngleDeg ?? this.shoulderAngleDeg,
      neckDiameterIn: neckDiameterIn ?? this.neckDiameterIn,
      neckLengthIn: neckLengthIn ?? this.neckLengthIn,
      baseToShoulderIn: baseToShoulderIn ?? this.baseToShoulderIn,
      baseToNeckIn: baseToNeckIn ?? this.baseToNeckIn,
      rimDiameterIn: rimDiameterIn ?? this.rimDiameterIn,
      rimThicknessIn: rimThicknessIn ?? this.rimThicknessIn,
      primerType: primerType ?? this.primerType,
      twistRate: twistRate ?? this.twistRate,
      maxAvgPressurePsi: maxAvgPressurePsi ?? this.maxAvgPressurePsi,
      boreDiameterIn: boreDiameterIn ?? this.boreDiameterIn,
      grooveDiameterIn: grooveDiameterIn ?? this.grooveDiameterIn,
      caseSubtype: caseSubtype ?? this.caseSubtype,
      saamiDoc: saamiDoc ?? this.saamiDoc,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (bulletDiameterIn.present) {
      map['bullet_diameter_in'] = Variable<double>(bulletDiameterIn.value);
    }
    if (caseLengthIn.present) {
      map['case_length_in'] = Variable<double>(caseLengthIn.value);
    }
    if (maxCoalIn.present) {
      map['max_coal_in'] = Variable<double>(maxCoalIn.value);
    }
    if (gauge.present) {
      map['gauge'] = Variable<double>(gauge.value);
    }
    if (shellLengthIn.present) {
      map['shell_length_in'] = Variable<double>(shellLengthIn.value);
    }
    if (parentCase.present) {
      map['parent_case'] = Variable<String>(parentCase.value);
    }
    if (yearIntroduced.present) {
      map['year_introduced'] = Variable<int>(yearIntroduced.value);
    }
    if (aliasesJson.present) {
      map['aliases_json'] = Variable<String>(aliasesJson.value);
    }
    if (bodyDiameterIn.present) {
      map['body_diameter_in'] = Variable<double>(bodyDiameterIn.value);
    }
    if (shoulderDiameterIn.present) {
      map['shoulder_diameter_in'] = Variable<double>(shoulderDiameterIn.value);
    }
    if (shoulderAngleDeg.present) {
      map['shoulder_angle_deg'] = Variable<double>(shoulderAngleDeg.value);
    }
    if (neckDiameterIn.present) {
      map['neck_diameter_in'] = Variable<double>(neckDiameterIn.value);
    }
    if (neckLengthIn.present) {
      map['neck_length_in'] = Variable<double>(neckLengthIn.value);
    }
    if (baseToShoulderIn.present) {
      map['base_to_shoulder_in'] = Variable<double>(baseToShoulderIn.value);
    }
    if (baseToNeckIn.present) {
      map['base_to_neck_in'] = Variable<double>(baseToNeckIn.value);
    }
    if (rimDiameterIn.present) {
      map['rim_diameter_in'] = Variable<double>(rimDiameterIn.value);
    }
    if (rimThicknessIn.present) {
      map['rim_thickness_in'] = Variable<double>(rimThicknessIn.value);
    }
    if (primerType.present) {
      map['primer_type'] = Variable<String>(primerType.value);
    }
    if (twistRate.present) {
      map['twist_rate'] = Variable<String>(twistRate.value);
    }
    if (maxAvgPressurePsi.present) {
      map['max_avg_pressure_psi'] = Variable<int>(maxAvgPressurePsi.value);
    }
    if (boreDiameterIn.present) {
      map['bore_diameter_in'] = Variable<double>(boreDiameterIn.value);
    }
    if (grooveDiameterIn.present) {
      map['groove_diameter_in'] = Variable<double>(grooveDiameterIn.value);
    }
    if (caseSubtype.present) {
      map['case_subtype'] = Variable<String>(caseSubtype.value);
    }
    if (saamiDoc.present) {
      map['saami_doc'] = Variable<String>(saamiDoc.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CartridgesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('bulletDiameterIn: $bulletDiameterIn, ')
          ..write('caseLengthIn: $caseLengthIn, ')
          ..write('maxCoalIn: $maxCoalIn, ')
          ..write('gauge: $gauge, ')
          ..write('shellLengthIn: $shellLengthIn, ')
          ..write('parentCase: $parentCase, ')
          ..write('yearIntroduced: $yearIntroduced, ')
          ..write('aliasesJson: $aliasesJson, ')
          ..write('bodyDiameterIn: $bodyDiameterIn, ')
          ..write('shoulderDiameterIn: $shoulderDiameterIn, ')
          ..write('shoulderAngleDeg: $shoulderAngleDeg, ')
          ..write('neckDiameterIn: $neckDiameterIn, ')
          ..write('neckLengthIn: $neckLengthIn, ')
          ..write('baseToShoulderIn: $baseToShoulderIn, ')
          ..write('baseToNeckIn: $baseToNeckIn, ')
          ..write('rimDiameterIn: $rimDiameterIn, ')
          ..write('rimThicknessIn: $rimThicknessIn, ')
          ..write('primerType: $primerType, ')
          ..write('twistRate: $twistRate, ')
          ..write('maxAvgPressurePsi: $maxAvgPressurePsi, ')
          ..write('boreDiameterIn: $boreDiameterIn, ')
          ..write('grooveDiameterIn: $grooveDiameterIn, ')
          ..write('caseSubtype: $caseSubtype, ')
          ..write('saamiDoc: $saamiDoc')
          ..write(')'))
        .toString();
  }
}

class $PowdersTable extends Powders with TableInfo<$PowdersTable, PowderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PowdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _manufacturerIdMeta = const VerificationMeta(
    'manufacturerId',
  );
  @override
  late final GeneratedColumn<int> manufacturerId = GeneratedColumn<int>(
    'manufacturer_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES manufacturers (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formMeta = const VerificationMeta('form');
  @override
  late final GeneratedColumn<String> form = GeneratedColumn<String>(
    'form',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _burnRateMeta = const VerificationMeta(
    'burnRate',
  );
  @override
  late final GeneratedColumn<String> burnRate = GeneratedColumn<String>(
    'burn_rate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    manufacturerId,
    name,
    type,
    form,
    burnRate,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'powders';
  @override
  VerificationContext validateIntegrity(
    Insertable<PowderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('manufacturer_id')) {
      context.handle(
        _manufacturerIdMeta,
        manufacturerId.isAcceptableOrUnknown(
          data['manufacturer_id']!,
          _manufacturerIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_manufacturerIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('form')) {
      context.handle(
        _formMeta,
        form.isAcceptableOrUnknown(data['form']!, _formMeta),
      );
    }
    if (data.containsKey('burn_rate')) {
      context.handle(
        _burnRateMeta,
        burnRate.isAcceptableOrUnknown(data['burn_rate']!, _burnRateMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PowderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PowderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      manufacturerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}manufacturer_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      form: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}form'],
      ),
      burnRate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}burn_rate'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $PowdersTable createAlias(String alias) {
    return $PowdersTable(attachedDatabase, alias);
  }
}

class PowderRow extends DataClass implements Insertable<PowderRow> {
  final int id;
  final int manufacturerId;
  final String name;
  final String type;
  final String? form;
  final String? burnRate;
  final String? notes;
  const PowderRow({
    required this.id,
    required this.manufacturerId,
    required this.name,
    required this.type,
    this.form,
    this.burnRate,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['manufacturer_id'] = Variable<int>(manufacturerId);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || form != null) {
      map['form'] = Variable<String>(form);
    }
    if (!nullToAbsent || burnRate != null) {
      map['burn_rate'] = Variable<String>(burnRate);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  PowdersCompanion toCompanion(bool nullToAbsent) {
    return PowdersCompanion(
      id: Value(id),
      manufacturerId: Value(manufacturerId),
      name: Value(name),
      type: Value(type),
      form: form == null && nullToAbsent ? const Value.absent() : Value(form),
      burnRate: burnRate == null && nullToAbsent
          ? const Value.absent()
          : Value(burnRate),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory PowderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PowderRow(
      id: serializer.fromJson<int>(json['id']),
      manufacturerId: serializer.fromJson<int>(json['manufacturerId']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      form: serializer.fromJson<String?>(json['form']),
      burnRate: serializer.fromJson<String?>(json['burnRate']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'manufacturerId': serializer.toJson<int>(manufacturerId),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'form': serializer.toJson<String?>(form),
      'burnRate': serializer.toJson<String?>(burnRate),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  PowderRow copyWith({
    int? id,
    int? manufacturerId,
    String? name,
    String? type,
    Value<String?> form = const Value.absent(),
    Value<String?> burnRate = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => PowderRow(
    id: id ?? this.id,
    manufacturerId: manufacturerId ?? this.manufacturerId,
    name: name ?? this.name,
    type: type ?? this.type,
    form: form.present ? form.value : this.form,
    burnRate: burnRate.present ? burnRate.value : this.burnRate,
    notes: notes.present ? notes.value : this.notes,
  );
  PowderRow copyWithCompanion(PowdersCompanion data) {
    return PowderRow(
      id: data.id.present ? data.id.value : this.id,
      manufacturerId: data.manufacturerId.present
          ? data.manufacturerId.value
          : this.manufacturerId,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      form: data.form.present ? data.form.value : this.form,
      burnRate: data.burnRate.present ? data.burnRate.value : this.burnRate,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PowderRow(')
          ..write('id: $id, ')
          ..write('manufacturerId: $manufacturerId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('form: $form, ')
          ..write('burnRate: $burnRate, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, manufacturerId, name, type, form, burnRate, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PowderRow &&
          other.id == this.id &&
          other.manufacturerId == this.manufacturerId &&
          other.name == this.name &&
          other.type == this.type &&
          other.form == this.form &&
          other.burnRate == this.burnRate &&
          other.notes == this.notes);
}

class PowdersCompanion extends UpdateCompanion<PowderRow> {
  final Value<int> id;
  final Value<int> manufacturerId;
  final Value<String> name;
  final Value<String> type;
  final Value<String?> form;
  final Value<String?> burnRate;
  final Value<String?> notes;
  const PowdersCompanion({
    this.id = const Value.absent(),
    this.manufacturerId = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.form = const Value.absent(),
    this.burnRate = const Value.absent(),
    this.notes = const Value.absent(),
  });
  PowdersCompanion.insert({
    this.id = const Value.absent(),
    required int manufacturerId,
    required String name,
    required String type,
    this.form = const Value.absent(),
    this.burnRate = const Value.absent(),
    this.notes = const Value.absent(),
  }) : manufacturerId = Value(manufacturerId),
       name = Value(name),
       type = Value(type);
  static Insertable<PowderRow> custom({
    Expression<int>? id,
    Expression<int>? manufacturerId,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? form,
    Expression<String>? burnRate,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (manufacturerId != null) 'manufacturer_id': manufacturerId,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (form != null) 'form': form,
      if (burnRate != null) 'burn_rate': burnRate,
      if (notes != null) 'notes': notes,
    });
  }

  PowdersCompanion copyWith({
    Value<int>? id,
    Value<int>? manufacturerId,
    Value<String>? name,
    Value<String>? type,
    Value<String?>? form,
    Value<String?>? burnRate,
    Value<String?>? notes,
  }) {
    return PowdersCompanion(
      id: id ?? this.id,
      manufacturerId: manufacturerId ?? this.manufacturerId,
      name: name ?? this.name,
      type: type ?? this.type,
      form: form ?? this.form,
      burnRate: burnRate ?? this.burnRate,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (manufacturerId.present) {
      map['manufacturer_id'] = Variable<int>(manufacturerId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (form.present) {
      map['form'] = Variable<String>(form.value);
    }
    if (burnRate.present) {
      map['burn_rate'] = Variable<String>(burnRate.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PowdersCompanion(')
          ..write('id: $id, ')
          ..write('manufacturerId: $manufacturerId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('form: $form, ')
          ..write('burnRate: $burnRate, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $BulletsTable extends Bullets with TableInfo<$BulletsTable, BulletRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BulletsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _manufacturerIdMeta = const VerificationMeta(
    'manufacturerId',
  );
  @override
  late final GeneratedColumn<int> manufacturerId = GeneratedColumn<int>(
    'manufacturer_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES manufacturers (id)',
    ),
  );
  static const VerificationMeta _lineMeta = const VerificationMeta('line');
  @override
  late final GeneratedColumn<String> line = GeneratedColumn<String>(
    'line',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _diameterInMeta = const VerificationMeta(
    'diameterIn',
  );
  @override
  late final GeneratedColumn<double> diameterIn = GeneratedColumn<double>(
    'diameter_in',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightGrMeta = const VerificationMeta(
    'weightGr',
  );
  @override
  late final GeneratedColumn<double> weightGr = GeneratedColumn<double>(
    'weight_gr',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _designMeta = const VerificationMeta('design');
  @override
  late final GeneratedColumn<String> design = GeneratedColumn<String>(
    'design',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _jacketMeta = const VerificationMeta('jacket');
  @override
  late final GeneratedColumn<String> jacket = GeneratedColumn<String>(
    'jacket',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _applicationMeta = const VerificationMeta(
    'application',
  );
  @override
  late final GeneratedColumn<String> application = GeneratedColumn<String>(
    'application',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bcG1Meta = const VerificationMeta('bcG1');
  @override
  late final GeneratedColumn<double> bcG1 = GeneratedColumn<double>(
    'bc_g1',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bcG7Meta = const VerificationMeta('bcG7');
  @override
  late final GeneratedColumn<double> bcG7 = GeneratedColumn<double>(
    'bc_g7',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    manufacturerId,
    line,
    diameterIn,
    weightGr,
    design,
    jacket,
    application,
    bcG1,
    bcG7,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bullets';
  @override
  VerificationContext validateIntegrity(
    Insertable<BulletRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('manufacturer_id')) {
      context.handle(
        _manufacturerIdMeta,
        manufacturerId.isAcceptableOrUnknown(
          data['manufacturer_id']!,
          _manufacturerIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_manufacturerIdMeta);
    }
    if (data.containsKey('line')) {
      context.handle(
        _lineMeta,
        line.isAcceptableOrUnknown(data['line']!, _lineMeta),
      );
    } else if (isInserting) {
      context.missing(_lineMeta);
    }
    if (data.containsKey('diameter_in')) {
      context.handle(
        _diameterInMeta,
        diameterIn.isAcceptableOrUnknown(data['diameter_in']!, _diameterInMeta),
      );
    } else if (isInserting) {
      context.missing(_diameterInMeta);
    }
    if (data.containsKey('weight_gr')) {
      context.handle(
        _weightGrMeta,
        weightGr.isAcceptableOrUnknown(data['weight_gr']!, _weightGrMeta),
      );
    } else if (isInserting) {
      context.missing(_weightGrMeta);
    }
    if (data.containsKey('design')) {
      context.handle(
        _designMeta,
        design.isAcceptableOrUnknown(data['design']!, _designMeta),
      );
    }
    if (data.containsKey('jacket')) {
      context.handle(
        _jacketMeta,
        jacket.isAcceptableOrUnknown(data['jacket']!, _jacketMeta),
      );
    }
    if (data.containsKey('application')) {
      context.handle(
        _applicationMeta,
        application.isAcceptableOrUnknown(
          data['application']!,
          _applicationMeta,
        ),
      );
    }
    if (data.containsKey('bc_g1')) {
      context.handle(
        _bcG1Meta,
        bcG1.isAcceptableOrUnknown(data['bc_g1']!, _bcG1Meta),
      );
    }
    if (data.containsKey('bc_g7')) {
      context.handle(
        _bcG7Meta,
        bcG7.isAcceptableOrUnknown(data['bc_g7']!, _bcG7Meta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BulletRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BulletRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      manufacturerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}manufacturer_id'],
      )!,
      line: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}line'],
      )!,
      diameterIn: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}diameter_in'],
      )!,
      weightGr: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_gr'],
      )!,
      design: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}design'],
      ),
      jacket: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}jacket'],
      ),
      application: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}application'],
      ),
      bcG1: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bc_g1'],
      ),
      bcG7: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bc_g7'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $BulletsTable createAlias(String alias) {
    return $BulletsTable(attachedDatabase, alias);
  }
}

class BulletRow extends DataClass implements Insertable<BulletRow> {
  final int id;
  final int manufacturerId;
  final String line;
  final double diameterIn;
  final double weightGr;
  final String? design;
  final String? jacket;
  final String? application;
  final double? bcG1;
  final double? bcG7;
  final String? notes;
  const BulletRow({
    required this.id,
    required this.manufacturerId,
    required this.line,
    required this.diameterIn,
    required this.weightGr,
    this.design,
    this.jacket,
    this.application,
    this.bcG1,
    this.bcG7,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['manufacturer_id'] = Variable<int>(manufacturerId);
    map['line'] = Variable<String>(line);
    map['diameter_in'] = Variable<double>(diameterIn);
    map['weight_gr'] = Variable<double>(weightGr);
    if (!nullToAbsent || design != null) {
      map['design'] = Variable<String>(design);
    }
    if (!nullToAbsent || jacket != null) {
      map['jacket'] = Variable<String>(jacket);
    }
    if (!nullToAbsent || application != null) {
      map['application'] = Variable<String>(application);
    }
    if (!nullToAbsent || bcG1 != null) {
      map['bc_g1'] = Variable<double>(bcG1);
    }
    if (!nullToAbsent || bcG7 != null) {
      map['bc_g7'] = Variable<double>(bcG7);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  BulletsCompanion toCompanion(bool nullToAbsent) {
    return BulletsCompanion(
      id: Value(id),
      manufacturerId: Value(manufacturerId),
      line: Value(line),
      diameterIn: Value(diameterIn),
      weightGr: Value(weightGr),
      design: design == null && nullToAbsent
          ? const Value.absent()
          : Value(design),
      jacket: jacket == null && nullToAbsent
          ? const Value.absent()
          : Value(jacket),
      application: application == null && nullToAbsent
          ? const Value.absent()
          : Value(application),
      bcG1: bcG1 == null && nullToAbsent ? const Value.absent() : Value(bcG1),
      bcG7: bcG7 == null && nullToAbsent ? const Value.absent() : Value(bcG7),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory BulletRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BulletRow(
      id: serializer.fromJson<int>(json['id']),
      manufacturerId: serializer.fromJson<int>(json['manufacturerId']),
      line: serializer.fromJson<String>(json['line']),
      diameterIn: serializer.fromJson<double>(json['diameterIn']),
      weightGr: serializer.fromJson<double>(json['weightGr']),
      design: serializer.fromJson<String?>(json['design']),
      jacket: serializer.fromJson<String?>(json['jacket']),
      application: serializer.fromJson<String?>(json['application']),
      bcG1: serializer.fromJson<double?>(json['bcG1']),
      bcG7: serializer.fromJson<double?>(json['bcG7']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'manufacturerId': serializer.toJson<int>(manufacturerId),
      'line': serializer.toJson<String>(line),
      'diameterIn': serializer.toJson<double>(diameterIn),
      'weightGr': serializer.toJson<double>(weightGr),
      'design': serializer.toJson<String?>(design),
      'jacket': serializer.toJson<String?>(jacket),
      'application': serializer.toJson<String?>(application),
      'bcG1': serializer.toJson<double?>(bcG1),
      'bcG7': serializer.toJson<double?>(bcG7),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  BulletRow copyWith({
    int? id,
    int? manufacturerId,
    String? line,
    double? diameterIn,
    double? weightGr,
    Value<String?> design = const Value.absent(),
    Value<String?> jacket = const Value.absent(),
    Value<String?> application = const Value.absent(),
    Value<double?> bcG1 = const Value.absent(),
    Value<double?> bcG7 = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => BulletRow(
    id: id ?? this.id,
    manufacturerId: manufacturerId ?? this.manufacturerId,
    line: line ?? this.line,
    diameterIn: diameterIn ?? this.diameterIn,
    weightGr: weightGr ?? this.weightGr,
    design: design.present ? design.value : this.design,
    jacket: jacket.present ? jacket.value : this.jacket,
    application: application.present ? application.value : this.application,
    bcG1: bcG1.present ? bcG1.value : this.bcG1,
    bcG7: bcG7.present ? bcG7.value : this.bcG7,
    notes: notes.present ? notes.value : this.notes,
  );
  BulletRow copyWithCompanion(BulletsCompanion data) {
    return BulletRow(
      id: data.id.present ? data.id.value : this.id,
      manufacturerId: data.manufacturerId.present
          ? data.manufacturerId.value
          : this.manufacturerId,
      line: data.line.present ? data.line.value : this.line,
      diameterIn: data.diameterIn.present
          ? data.diameterIn.value
          : this.diameterIn,
      weightGr: data.weightGr.present ? data.weightGr.value : this.weightGr,
      design: data.design.present ? data.design.value : this.design,
      jacket: data.jacket.present ? data.jacket.value : this.jacket,
      application: data.application.present
          ? data.application.value
          : this.application,
      bcG1: data.bcG1.present ? data.bcG1.value : this.bcG1,
      bcG7: data.bcG7.present ? data.bcG7.value : this.bcG7,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BulletRow(')
          ..write('id: $id, ')
          ..write('manufacturerId: $manufacturerId, ')
          ..write('line: $line, ')
          ..write('diameterIn: $diameterIn, ')
          ..write('weightGr: $weightGr, ')
          ..write('design: $design, ')
          ..write('jacket: $jacket, ')
          ..write('application: $application, ')
          ..write('bcG1: $bcG1, ')
          ..write('bcG7: $bcG7, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    manufacturerId,
    line,
    diameterIn,
    weightGr,
    design,
    jacket,
    application,
    bcG1,
    bcG7,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BulletRow &&
          other.id == this.id &&
          other.manufacturerId == this.manufacturerId &&
          other.line == this.line &&
          other.diameterIn == this.diameterIn &&
          other.weightGr == this.weightGr &&
          other.design == this.design &&
          other.jacket == this.jacket &&
          other.application == this.application &&
          other.bcG1 == this.bcG1 &&
          other.bcG7 == this.bcG7 &&
          other.notes == this.notes);
}

class BulletsCompanion extends UpdateCompanion<BulletRow> {
  final Value<int> id;
  final Value<int> manufacturerId;
  final Value<String> line;
  final Value<double> diameterIn;
  final Value<double> weightGr;
  final Value<String?> design;
  final Value<String?> jacket;
  final Value<String?> application;
  final Value<double?> bcG1;
  final Value<double?> bcG7;
  final Value<String?> notes;
  const BulletsCompanion({
    this.id = const Value.absent(),
    this.manufacturerId = const Value.absent(),
    this.line = const Value.absent(),
    this.diameterIn = const Value.absent(),
    this.weightGr = const Value.absent(),
    this.design = const Value.absent(),
    this.jacket = const Value.absent(),
    this.application = const Value.absent(),
    this.bcG1 = const Value.absent(),
    this.bcG7 = const Value.absent(),
    this.notes = const Value.absent(),
  });
  BulletsCompanion.insert({
    this.id = const Value.absent(),
    required int manufacturerId,
    required String line,
    required double diameterIn,
    required double weightGr,
    this.design = const Value.absent(),
    this.jacket = const Value.absent(),
    this.application = const Value.absent(),
    this.bcG1 = const Value.absent(),
    this.bcG7 = const Value.absent(),
    this.notes = const Value.absent(),
  }) : manufacturerId = Value(manufacturerId),
       line = Value(line),
       diameterIn = Value(diameterIn),
       weightGr = Value(weightGr);
  static Insertable<BulletRow> custom({
    Expression<int>? id,
    Expression<int>? manufacturerId,
    Expression<String>? line,
    Expression<double>? diameterIn,
    Expression<double>? weightGr,
    Expression<String>? design,
    Expression<String>? jacket,
    Expression<String>? application,
    Expression<double>? bcG1,
    Expression<double>? bcG7,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (manufacturerId != null) 'manufacturer_id': manufacturerId,
      if (line != null) 'line': line,
      if (diameterIn != null) 'diameter_in': diameterIn,
      if (weightGr != null) 'weight_gr': weightGr,
      if (design != null) 'design': design,
      if (jacket != null) 'jacket': jacket,
      if (application != null) 'application': application,
      if (bcG1 != null) 'bc_g1': bcG1,
      if (bcG7 != null) 'bc_g7': bcG7,
      if (notes != null) 'notes': notes,
    });
  }

  BulletsCompanion copyWith({
    Value<int>? id,
    Value<int>? manufacturerId,
    Value<String>? line,
    Value<double>? diameterIn,
    Value<double>? weightGr,
    Value<String?>? design,
    Value<String?>? jacket,
    Value<String?>? application,
    Value<double?>? bcG1,
    Value<double?>? bcG7,
    Value<String?>? notes,
  }) {
    return BulletsCompanion(
      id: id ?? this.id,
      manufacturerId: manufacturerId ?? this.manufacturerId,
      line: line ?? this.line,
      diameterIn: diameterIn ?? this.diameterIn,
      weightGr: weightGr ?? this.weightGr,
      design: design ?? this.design,
      jacket: jacket ?? this.jacket,
      application: application ?? this.application,
      bcG1: bcG1 ?? this.bcG1,
      bcG7: bcG7 ?? this.bcG7,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (manufacturerId.present) {
      map['manufacturer_id'] = Variable<int>(manufacturerId.value);
    }
    if (line.present) {
      map['line'] = Variable<String>(line.value);
    }
    if (diameterIn.present) {
      map['diameter_in'] = Variable<double>(diameterIn.value);
    }
    if (weightGr.present) {
      map['weight_gr'] = Variable<double>(weightGr.value);
    }
    if (design.present) {
      map['design'] = Variable<String>(design.value);
    }
    if (jacket.present) {
      map['jacket'] = Variable<String>(jacket.value);
    }
    if (application.present) {
      map['application'] = Variable<String>(application.value);
    }
    if (bcG1.present) {
      map['bc_g1'] = Variable<double>(bcG1.value);
    }
    if (bcG7.present) {
      map['bc_g7'] = Variable<double>(bcG7.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BulletsCompanion(')
          ..write('id: $id, ')
          ..write('manufacturerId: $manufacturerId, ')
          ..write('line: $line, ')
          ..write('diameterIn: $diameterIn, ')
          ..write('weightGr: $weightGr, ')
          ..write('design: $design, ')
          ..write('jacket: $jacket, ')
          ..write('application: $application, ')
          ..write('bcG1: $bcG1, ')
          ..write('bcG7: $bcG7, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $PrimersTable extends Primers with TableInfo<$PrimersTable, PrimerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrimersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _manufacturerIdMeta = const VerificationMeta(
    'manufacturerId',
  );
  @override
  late final GeneratedColumn<int> manufacturerId = GeneratedColumn<int>(
    'manufacturer_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES manufacturers (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<String> size = GeneratedColumn<String>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _magnumMeta = const VerificationMeta('magnum');
  @override
  late final GeneratedColumn<bool> magnum = GeneratedColumn<bool>(
    'magnum',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("magnum" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _gradeMeta = const VerificationMeta('grade');
  @override
  late final GeneratedColumn<String> grade = GeneratedColumn<String>(
    'grade',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _productLineMeta = const VerificationMeta(
    'productLine',
  );
  @override
  late final GeneratedColumn<String> productLine = GeneratedColumn<String>(
    'product_line',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    manufacturerId,
    name,
    size,
    magnum,
    grade,
    productLine,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'primers';
  @override
  VerificationContext validateIntegrity(
    Insertable<PrimerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('manufacturer_id')) {
      context.handle(
        _manufacturerIdMeta,
        manufacturerId.isAcceptableOrUnknown(
          data['manufacturer_id']!,
          _manufacturerIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_manufacturerIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('magnum')) {
      context.handle(
        _magnumMeta,
        magnum.isAcceptableOrUnknown(data['magnum']!, _magnumMeta),
      );
    }
    if (data.containsKey('grade')) {
      context.handle(
        _gradeMeta,
        grade.isAcceptableOrUnknown(data['grade']!, _gradeMeta),
      );
    }
    if (data.containsKey('product_line')) {
      context.handle(
        _productLineMeta,
        productLine.isAcceptableOrUnknown(
          data['product_line']!,
          _productLineMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PrimerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PrimerRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      manufacturerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}manufacturer_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}size'],
      )!,
      magnum: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}magnum'],
      )!,
      grade: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}grade'],
      ),
      productLine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_line'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $PrimersTable createAlias(String alias) {
    return $PrimersTable(attachedDatabase, alias);
  }
}

class PrimerRow extends DataClass implements Insertable<PrimerRow> {
  final int id;
  final int manufacturerId;

  /// Model number / code (e.g. "GM205M", "WLR", "9.5M"). Used in `Federal #205M`
  /// style labels and on box headstamps.
  final String name;
  final String size;
  final bool magnum;
  final String? grade;

  /// Manufacturer's marketing name for the product family
  /// (e.g. "Premium Gold Medal Small Rifle Match"). Shown in the product
  /// dropdown alongside `#name` so non-experts can recognize what they're
  /// picking. Added in schema v3. Nullable to allow custom user-added primers
  /// to omit it.
  final String? productLine;
  final String? notes;
  const PrimerRow({
    required this.id,
    required this.manufacturerId,
    required this.name,
    required this.size,
    required this.magnum,
    this.grade,
    this.productLine,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['manufacturer_id'] = Variable<int>(manufacturerId);
    map['name'] = Variable<String>(name);
    map['size'] = Variable<String>(size);
    map['magnum'] = Variable<bool>(magnum);
    if (!nullToAbsent || grade != null) {
      map['grade'] = Variable<String>(grade);
    }
    if (!nullToAbsent || productLine != null) {
      map['product_line'] = Variable<String>(productLine);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  PrimersCompanion toCompanion(bool nullToAbsent) {
    return PrimersCompanion(
      id: Value(id),
      manufacturerId: Value(manufacturerId),
      name: Value(name),
      size: Value(size),
      magnum: Value(magnum),
      grade: grade == null && nullToAbsent
          ? const Value.absent()
          : Value(grade),
      productLine: productLine == null && nullToAbsent
          ? const Value.absent()
          : Value(productLine),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory PrimerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PrimerRow(
      id: serializer.fromJson<int>(json['id']),
      manufacturerId: serializer.fromJson<int>(json['manufacturerId']),
      name: serializer.fromJson<String>(json['name']),
      size: serializer.fromJson<String>(json['size']),
      magnum: serializer.fromJson<bool>(json['magnum']),
      grade: serializer.fromJson<String?>(json['grade']),
      productLine: serializer.fromJson<String?>(json['productLine']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'manufacturerId': serializer.toJson<int>(manufacturerId),
      'name': serializer.toJson<String>(name),
      'size': serializer.toJson<String>(size),
      'magnum': serializer.toJson<bool>(magnum),
      'grade': serializer.toJson<String?>(grade),
      'productLine': serializer.toJson<String?>(productLine),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  PrimerRow copyWith({
    int? id,
    int? manufacturerId,
    String? name,
    String? size,
    bool? magnum,
    Value<String?> grade = const Value.absent(),
    Value<String?> productLine = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => PrimerRow(
    id: id ?? this.id,
    manufacturerId: manufacturerId ?? this.manufacturerId,
    name: name ?? this.name,
    size: size ?? this.size,
    magnum: magnum ?? this.magnum,
    grade: grade.present ? grade.value : this.grade,
    productLine: productLine.present ? productLine.value : this.productLine,
    notes: notes.present ? notes.value : this.notes,
  );
  PrimerRow copyWithCompanion(PrimersCompanion data) {
    return PrimerRow(
      id: data.id.present ? data.id.value : this.id,
      manufacturerId: data.manufacturerId.present
          ? data.manufacturerId.value
          : this.manufacturerId,
      name: data.name.present ? data.name.value : this.name,
      size: data.size.present ? data.size.value : this.size,
      magnum: data.magnum.present ? data.magnum.value : this.magnum,
      grade: data.grade.present ? data.grade.value : this.grade,
      productLine: data.productLine.present
          ? data.productLine.value
          : this.productLine,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PrimerRow(')
          ..write('id: $id, ')
          ..write('manufacturerId: $manufacturerId, ')
          ..write('name: $name, ')
          ..write('size: $size, ')
          ..write('magnum: $magnum, ')
          ..write('grade: $grade, ')
          ..write('productLine: $productLine, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    manufacturerId,
    name,
    size,
    magnum,
    grade,
    productLine,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrimerRow &&
          other.id == this.id &&
          other.manufacturerId == this.manufacturerId &&
          other.name == this.name &&
          other.size == this.size &&
          other.magnum == this.magnum &&
          other.grade == this.grade &&
          other.productLine == this.productLine &&
          other.notes == this.notes);
}

class PrimersCompanion extends UpdateCompanion<PrimerRow> {
  final Value<int> id;
  final Value<int> manufacturerId;
  final Value<String> name;
  final Value<String> size;
  final Value<bool> magnum;
  final Value<String?> grade;
  final Value<String?> productLine;
  final Value<String?> notes;
  const PrimersCompanion({
    this.id = const Value.absent(),
    this.manufacturerId = const Value.absent(),
    this.name = const Value.absent(),
    this.size = const Value.absent(),
    this.magnum = const Value.absent(),
    this.grade = const Value.absent(),
    this.productLine = const Value.absent(),
    this.notes = const Value.absent(),
  });
  PrimersCompanion.insert({
    this.id = const Value.absent(),
    required int manufacturerId,
    required String name,
    required String size,
    this.magnum = const Value.absent(),
    this.grade = const Value.absent(),
    this.productLine = const Value.absent(),
    this.notes = const Value.absent(),
  }) : manufacturerId = Value(manufacturerId),
       name = Value(name),
       size = Value(size);
  static Insertable<PrimerRow> custom({
    Expression<int>? id,
    Expression<int>? manufacturerId,
    Expression<String>? name,
    Expression<String>? size,
    Expression<bool>? magnum,
    Expression<String>? grade,
    Expression<String>? productLine,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (manufacturerId != null) 'manufacturer_id': manufacturerId,
      if (name != null) 'name': name,
      if (size != null) 'size': size,
      if (magnum != null) 'magnum': magnum,
      if (grade != null) 'grade': grade,
      if (productLine != null) 'product_line': productLine,
      if (notes != null) 'notes': notes,
    });
  }

  PrimersCompanion copyWith({
    Value<int>? id,
    Value<int>? manufacturerId,
    Value<String>? name,
    Value<String>? size,
    Value<bool>? magnum,
    Value<String?>? grade,
    Value<String?>? productLine,
    Value<String?>? notes,
  }) {
    return PrimersCompanion(
      id: id ?? this.id,
      manufacturerId: manufacturerId ?? this.manufacturerId,
      name: name ?? this.name,
      size: size ?? this.size,
      magnum: magnum ?? this.magnum,
      grade: grade ?? this.grade,
      productLine: productLine ?? this.productLine,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (manufacturerId.present) {
      map['manufacturer_id'] = Variable<int>(manufacturerId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (size.present) {
      map['size'] = Variable<String>(size.value);
    }
    if (magnum.present) {
      map['magnum'] = Variable<bool>(magnum.value);
    }
    if (grade.present) {
      map['grade'] = Variable<String>(grade.value);
    }
    if (productLine.present) {
      map['product_line'] = Variable<String>(productLine.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrimersCompanion(')
          ..write('id: $id, ')
          ..write('manufacturerId: $manufacturerId, ')
          ..write('name: $name, ')
          ..write('size: $size, ')
          ..write('magnum: $magnum, ')
          ..write('grade: $grade, ')
          ..write('productLine: $productLine, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $BrassProductsTable extends BrassProducts
    with TableInfo<$BrassProductsTable, BrassProductRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BrassProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _manufacturerIdMeta = const VerificationMeta(
    'manufacturerId',
  );
  @override
  late final GeneratedColumn<int> manufacturerId = GeneratedColumn<int>(
    'manufacturer_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES manufacturers (id)',
    ),
  );
  static const VerificationMeta _tierMeta = const VerificationMeta('tier');
  @override
  late final GeneratedColumn<String> tier = GeneratedColumn<String>(
    'tier',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _calibersJsonMeta = const VerificationMeta(
    'calibersJson',
  );
  @override
  late final GeneratedColumn<String> calibersJson = GeneratedColumn<String>(
    'calibers_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    manufacturerId,
    tier,
    calibersJson,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'brass_products';
  @override
  VerificationContext validateIntegrity(
    Insertable<BrassProductRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('manufacturer_id')) {
      context.handle(
        _manufacturerIdMeta,
        manufacturerId.isAcceptableOrUnknown(
          data['manufacturer_id']!,
          _manufacturerIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_manufacturerIdMeta);
    }
    if (data.containsKey('tier')) {
      context.handle(
        _tierMeta,
        tier.isAcceptableOrUnknown(data['tier']!, _tierMeta),
      );
    }
    if (data.containsKey('calibers_json')) {
      context.handle(
        _calibersJsonMeta,
        calibersJson.isAcceptableOrUnknown(
          data['calibers_json']!,
          _calibersJsonMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BrassProductRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BrassProductRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      manufacturerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}manufacturer_id'],
      )!,
      tier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tier'],
      ),
      calibersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calibers_json'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $BrassProductsTable createAlias(String alias) {
    return $BrassProductsTable(attachedDatabase, alias);
  }
}

class BrassProductRow extends DataClass implements Insertable<BrassProductRow> {
  final int id;
  final int manufacturerId;
  final String? tier;

  /// JSON array of caliber names this brass is offered in
  final String calibersJson;
  final String? notes;
  const BrassProductRow({
    required this.id,
    required this.manufacturerId,
    this.tier,
    required this.calibersJson,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['manufacturer_id'] = Variable<int>(manufacturerId);
    if (!nullToAbsent || tier != null) {
      map['tier'] = Variable<String>(tier);
    }
    map['calibers_json'] = Variable<String>(calibersJson);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  BrassProductsCompanion toCompanion(bool nullToAbsent) {
    return BrassProductsCompanion(
      id: Value(id),
      manufacturerId: Value(manufacturerId),
      tier: tier == null && nullToAbsent ? const Value.absent() : Value(tier),
      calibersJson: Value(calibersJson),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory BrassProductRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BrassProductRow(
      id: serializer.fromJson<int>(json['id']),
      manufacturerId: serializer.fromJson<int>(json['manufacturerId']),
      tier: serializer.fromJson<String?>(json['tier']),
      calibersJson: serializer.fromJson<String>(json['calibersJson']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'manufacturerId': serializer.toJson<int>(manufacturerId),
      'tier': serializer.toJson<String?>(tier),
      'calibersJson': serializer.toJson<String>(calibersJson),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  BrassProductRow copyWith({
    int? id,
    int? manufacturerId,
    Value<String?> tier = const Value.absent(),
    String? calibersJson,
    Value<String?> notes = const Value.absent(),
  }) => BrassProductRow(
    id: id ?? this.id,
    manufacturerId: manufacturerId ?? this.manufacturerId,
    tier: tier.present ? tier.value : this.tier,
    calibersJson: calibersJson ?? this.calibersJson,
    notes: notes.present ? notes.value : this.notes,
  );
  BrassProductRow copyWithCompanion(BrassProductsCompanion data) {
    return BrassProductRow(
      id: data.id.present ? data.id.value : this.id,
      manufacturerId: data.manufacturerId.present
          ? data.manufacturerId.value
          : this.manufacturerId,
      tier: data.tier.present ? data.tier.value : this.tier,
      calibersJson: data.calibersJson.present
          ? data.calibersJson.value
          : this.calibersJson,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BrassProductRow(')
          ..write('id: $id, ')
          ..write('manufacturerId: $manufacturerId, ')
          ..write('tier: $tier, ')
          ..write('calibersJson: $calibersJson, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, manufacturerId, tier, calibersJson, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BrassProductRow &&
          other.id == this.id &&
          other.manufacturerId == this.manufacturerId &&
          other.tier == this.tier &&
          other.calibersJson == this.calibersJson &&
          other.notes == this.notes);
}

class BrassProductsCompanion extends UpdateCompanion<BrassProductRow> {
  final Value<int> id;
  final Value<int> manufacturerId;
  final Value<String?> tier;
  final Value<String> calibersJson;
  final Value<String?> notes;
  const BrassProductsCompanion({
    this.id = const Value.absent(),
    this.manufacturerId = const Value.absent(),
    this.tier = const Value.absent(),
    this.calibersJson = const Value.absent(),
    this.notes = const Value.absent(),
  });
  BrassProductsCompanion.insert({
    this.id = const Value.absent(),
    required int manufacturerId,
    this.tier = const Value.absent(),
    this.calibersJson = const Value.absent(),
    this.notes = const Value.absent(),
  }) : manufacturerId = Value(manufacturerId);
  static Insertable<BrassProductRow> custom({
    Expression<int>? id,
    Expression<int>? manufacturerId,
    Expression<String>? tier,
    Expression<String>? calibersJson,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (manufacturerId != null) 'manufacturer_id': manufacturerId,
      if (tier != null) 'tier': tier,
      if (calibersJson != null) 'calibers_json': calibersJson,
      if (notes != null) 'notes': notes,
    });
  }

  BrassProductsCompanion copyWith({
    Value<int>? id,
    Value<int>? manufacturerId,
    Value<String?>? tier,
    Value<String>? calibersJson,
    Value<String?>? notes,
  }) {
    return BrassProductsCompanion(
      id: id ?? this.id,
      manufacturerId: manufacturerId ?? this.manufacturerId,
      tier: tier ?? this.tier,
      calibersJson: calibersJson ?? this.calibersJson,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (manufacturerId.present) {
      map['manufacturer_id'] = Variable<int>(manufacturerId.value);
    }
    if (tier.present) {
      map['tier'] = Variable<String>(tier.value);
    }
    if (calibersJson.present) {
      map['calibers_json'] = Variable<String>(calibersJson.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BrassProductsCompanion(')
          ..write('id: $id, ')
          ..write('manufacturerId: $manufacturerId, ')
          ..write('tier: $tier, ')
          ..write('calibersJson: $calibersJson, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $FirearmsRefTable extends FirearmsRef
    with TableInfo<$FirearmsRefTable, FirearmRefRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FirearmsRefTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _manufacturerIdMeta = const VerificationMeta(
    'manufacturerId',
  );
  @override
  late final GeneratedColumn<int> manufacturerId = GeneratedColumn<int>(
    'manufacturer_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES manufacturers (id)',
    ),
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _calibersJsonMeta = const VerificationMeta(
    'calibersJson',
  );
  @override
  late final GeneratedColumn<String> calibersJson = GeneratedColumn<String>(
    'calibers_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    manufacturerId,
    model,
    type,
    action,
    calibersJson,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'firearms_ref';
  @override
  VerificationContext validateIntegrity(
    Insertable<FirearmRefRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('manufacturer_id')) {
      context.handle(
        _manufacturerIdMeta,
        manufacturerId.isAcceptableOrUnknown(
          data['manufacturer_id']!,
          _manufacturerIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_manufacturerIdMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    }
    if (data.containsKey('calibers_json')) {
      context.handle(
        _calibersJsonMeta,
        calibersJson.isAcceptableOrUnknown(
          data['calibers_json']!,
          _calibersJsonMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FirearmRefRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FirearmRefRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      manufacturerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}manufacturer_id'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      ),
      calibersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calibers_json'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $FirearmsRefTable createAlias(String alias) {
    return $FirearmsRefTable(attachedDatabase, alias);
  }
}

class FirearmRefRow extends DataClass implements Insertable<FirearmRefRow> {
  final int id;
  final int manufacturerId;
  final String model;

  /// 'pistol' | 'rifle' | 'shotgun'
  final String type;

  /// 'semi-auto' | 'bolt-action' | etc.
  final String? action;
  final String calibersJson;
  final String? notes;
  const FirearmRefRow({
    required this.id,
    required this.manufacturerId,
    required this.model,
    required this.type,
    this.action,
    required this.calibersJson,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['manufacturer_id'] = Variable<int>(manufacturerId);
    map['model'] = Variable<String>(model);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || action != null) {
      map['action'] = Variable<String>(action);
    }
    map['calibers_json'] = Variable<String>(calibersJson);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  FirearmsRefCompanion toCompanion(bool nullToAbsent) {
    return FirearmsRefCompanion(
      id: Value(id),
      manufacturerId: Value(manufacturerId),
      model: Value(model),
      type: Value(type),
      action: action == null && nullToAbsent
          ? const Value.absent()
          : Value(action),
      calibersJson: Value(calibersJson),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory FirearmRefRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FirearmRefRow(
      id: serializer.fromJson<int>(json['id']),
      manufacturerId: serializer.fromJson<int>(json['manufacturerId']),
      model: serializer.fromJson<String>(json['model']),
      type: serializer.fromJson<String>(json['type']),
      action: serializer.fromJson<String?>(json['action']),
      calibersJson: serializer.fromJson<String>(json['calibersJson']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'manufacturerId': serializer.toJson<int>(manufacturerId),
      'model': serializer.toJson<String>(model),
      'type': serializer.toJson<String>(type),
      'action': serializer.toJson<String?>(action),
      'calibersJson': serializer.toJson<String>(calibersJson),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  FirearmRefRow copyWith({
    int? id,
    int? manufacturerId,
    String? model,
    String? type,
    Value<String?> action = const Value.absent(),
    String? calibersJson,
    Value<String?> notes = const Value.absent(),
  }) => FirearmRefRow(
    id: id ?? this.id,
    manufacturerId: manufacturerId ?? this.manufacturerId,
    model: model ?? this.model,
    type: type ?? this.type,
    action: action.present ? action.value : this.action,
    calibersJson: calibersJson ?? this.calibersJson,
    notes: notes.present ? notes.value : this.notes,
  );
  FirearmRefRow copyWithCompanion(FirearmsRefCompanion data) {
    return FirearmRefRow(
      id: data.id.present ? data.id.value : this.id,
      manufacturerId: data.manufacturerId.present
          ? data.manufacturerId.value
          : this.manufacturerId,
      model: data.model.present ? data.model.value : this.model,
      type: data.type.present ? data.type.value : this.type,
      action: data.action.present ? data.action.value : this.action,
      calibersJson: data.calibersJson.present
          ? data.calibersJson.value
          : this.calibersJson,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FirearmRefRow(')
          ..write('id: $id, ')
          ..write('manufacturerId: $manufacturerId, ')
          ..write('model: $model, ')
          ..write('type: $type, ')
          ..write('action: $action, ')
          ..write('calibersJson: $calibersJson, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, manufacturerId, model, type, action, calibersJson, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FirearmRefRow &&
          other.id == this.id &&
          other.manufacturerId == this.manufacturerId &&
          other.model == this.model &&
          other.type == this.type &&
          other.action == this.action &&
          other.calibersJson == this.calibersJson &&
          other.notes == this.notes);
}

class FirearmsRefCompanion extends UpdateCompanion<FirearmRefRow> {
  final Value<int> id;
  final Value<int> manufacturerId;
  final Value<String> model;
  final Value<String> type;
  final Value<String?> action;
  final Value<String> calibersJson;
  final Value<String?> notes;
  const FirearmsRefCompanion({
    this.id = const Value.absent(),
    this.manufacturerId = const Value.absent(),
    this.model = const Value.absent(),
    this.type = const Value.absent(),
    this.action = const Value.absent(),
    this.calibersJson = const Value.absent(),
    this.notes = const Value.absent(),
  });
  FirearmsRefCompanion.insert({
    this.id = const Value.absent(),
    required int manufacturerId,
    required String model,
    required String type,
    this.action = const Value.absent(),
    this.calibersJson = const Value.absent(),
    this.notes = const Value.absent(),
  }) : manufacturerId = Value(manufacturerId),
       model = Value(model),
       type = Value(type);
  static Insertable<FirearmRefRow> custom({
    Expression<int>? id,
    Expression<int>? manufacturerId,
    Expression<String>? model,
    Expression<String>? type,
    Expression<String>? action,
    Expression<String>? calibersJson,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (manufacturerId != null) 'manufacturer_id': manufacturerId,
      if (model != null) 'model': model,
      if (type != null) 'type': type,
      if (action != null) 'action': action,
      if (calibersJson != null) 'calibers_json': calibersJson,
      if (notes != null) 'notes': notes,
    });
  }

  FirearmsRefCompanion copyWith({
    Value<int>? id,
    Value<int>? manufacturerId,
    Value<String>? model,
    Value<String>? type,
    Value<String?>? action,
    Value<String>? calibersJson,
    Value<String?>? notes,
  }) {
    return FirearmsRefCompanion(
      id: id ?? this.id,
      manufacturerId: manufacturerId ?? this.manufacturerId,
      model: model ?? this.model,
      type: type ?? this.type,
      action: action ?? this.action,
      calibersJson: calibersJson ?? this.calibersJson,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (manufacturerId.present) {
      map['manufacturer_id'] = Variable<int>(manufacturerId.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (calibersJson.present) {
      map['calibers_json'] = Variable<String>(calibersJson.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FirearmsRefCompanion(')
          ..write('id: $id, ')
          ..write('manufacturerId: $manufacturerId, ')
          ..write('model: $model, ')
          ..write('type: $type, ')
          ..write('action: $action, ')
          ..write('calibersJson: $calibersJson, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $FirearmPartsTable extends FirearmParts
    with TableInfo<$FirearmPartsTable, FirearmPartRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FirearmPartsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _manufacturerIdMeta = const VerificationMeta(
    'manufacturerId',
  );
  @override
  late final GeneratedColumn<int> manufacturerId = GeneratedColumn<int>(
    'manufacturer_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES manufacturers (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _compatibleWithJsonMeta =
      const VerificationMeta('compatibleWithJson');
  @override
  late final GeneratedColumn<String> compatibleWithJson =
      GeneratedColumn<String>(
        'compatible_with_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    manufacturerId,
    name,
    category,
    compatibleWithJson,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'firearm_parts';
  @override
  VerificationContext validateIntegrity(
    Insertable<FirearmPartRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('manufacturer_id')) {
      context.handle(
        _manufacturerIdMeta,
        manufacturerId.isAcceptableOrUnknown(
          data['manufacturer_id']!,
          _manufacturerIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_manufacturerIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('compatible_with_json')) {
      context.handle(
        _compatibleWithJsonMeta,
        compatibleWithJson.isAcceptableOrUnknown(
          data['compatible_with_json']!,
          _compatibleWithJsonMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FirearmPartRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FirearmPartRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      manufacturerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}manufacturer_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      compatibleWithJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}compatible_with_json'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $FirearmPartsTable createAlias(String alias) {
    return $FirearmPartsTable(attachedDatabase, alias);
  }
}

class FirearmPartRow extends DataClass implements Insertable<FirearmPartRow> {
  final int id;
  final int manufacturerId;
  final String name;
  final String category;
  final String compatibleWithJson;
  final String? notes;
  const FirearmPartRow({
    required this.id,
    required this.manufacturerId,
    required this.name,
    required this.category,
    required this.compatibleWithJson,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['manufacturer_id'] = Variable<int>(manufacturerId);
    map['name'] = Variable<String>(name);
    map['category'] = Variable<String>(category);
    map['compatible_with_json'] = Variable<String>(compatibleWithJson);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  FirearmPartsCompanion toCompanion(bool nullToAbsent) {
    return FirearmPartsCompanion(
      id: Value(id),
      manufacturerId: Value(manufacturerId),
      name: Value(name),
      category: Value(category),
      compatibleWithJson: Value(compatibleWithJson),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory FirearmPartRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FirearmPartRow(
      id: serializer.fromJson<int>(json['id']),
      manufacturerId: serializer.fromJson<int>(json['manufacturerId']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String>(json['category']),
      compatibleWithJson: serializer.fromJson<String>(
        json['compatibleWithJson'],
      ),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'manufacturerId': serializer.toJson<int>(manufacturerId),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String>(category),
      'compatibleWithJson': serializer.toJson<String>(compatibleWithJson),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  FirearmPartRow copyWith({
    int? id,
    int? manufacturerId,
    String? name,
    String? category,
    String? compatibleWithJson,
    Value<String?> notes = const Value.absent(),
  }) => FirearmPartRow(
    id: id ?? this.id,
    manufacturerId: manufacturerId ?? this.manufacturerId,
    name: name ?? this.name,
    category: category ?? this.category,
    compatibleWithJson: compatibleWithJson ?? this.compatibleWithJson,
    notes: notes.present ? notes.value : this.notes,
  );
  FirearmPartRow copyWithCompanion(FirearmPartsCompanion data) {
    return FirearmPartRow(
      id: data.id.present ? data.id.value : this.id,
      manufacturerId: data.manufacturerId.present
          ? data.manufacturerId.value
          : this.manufacturerId,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      compatibleWithJson: data.compatibleWithJson.present
          ? data.compatibleWithJson.value
          : this.compatibleWithJson,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FirearmPartRow(')
          ..write('id: $id, ')
          ..write('manufacturerId: $manufacturerId, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('compatibleWithJson: $compatibleWithJson, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    manufacturerId,
    name,
    category,
    compatibleWithJson,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FirearmPartRow &&
          other.id == this.id &&
          other.manufacturerId == this.manufacturerId &&
          other.name == this.name &&
          other.category == this.category &&
          other.compatibleWithJson == this.compatibleWithJson &&
          other.notes == this.notes);
}

class FirearmPartsCompanion extends UpdateCompanion<FirearmPartRow> {
  final Value<int> id;
  final Value<int> manufacturerId;
  final Value<String> name;
  final Value<String> category;
  final Value<String> compatibleWithJson;
  final Value<String?> notes;
  const FirearmPartsCompanion({
    this.id = const Value.absent(),
    this.manufacturerId = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.compatibleWithJson = const Value.absent(),
    this.notes = const Value.absent(),
  });
  FirearmPartsCompanion.insert({
    this.id = const Value.absent(),
    required int manufacturerId,
    required String name,
    required String category,
    this.compatibleWithJson = const Value.absent(),
    this.notes = const Value.absent(),
  }) : manufacturerId = Value(manufacturerId),
       name = Value(name),
       category = Value(category);
  static Insertable<FirearmPartRow> custom({
    Expression<int>? id,
    Expression<int>? manufacturerId,
    Expression<String>? name,
    Expression<String>? category,
    Expression<String>? compatibleWithJson,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (manufacturerId != null) 'manufacturer_id': manufacturerId,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (compatibleWithJson != null)
        'compatible_with_json': compatibleWithJson,
      if (notes != null) 'notes': notes,
    });
  }

  FirearmPartsCompanion copyWith({
    Value<int>? id,
    Value<int>? manufacturerId,
    Value<String>? name,
    Value<String>? category,
    Value<String>? compatibleWithJson,
    Value<String?>? notes,
  }) {
    return FirearmPartsCompanion(
      id: id ?? this.id,
      manufacturerId: manufacturerId ?? this.manufacturerId,
      name: name ?? this.name,
      category: category ?? this.category,
      compatibleWithJson: compatibleWithJson ?? this.compatibleWithJson,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (manufacturerId.present) {
      map['manufacturer_id'] = Variable<int>(manufacturerId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (compatibleWithJson.present) {
      map['compatible_with_json'] = Variable<String>(compatibleWithJson.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FirearmPartsCompanion(')
          ..write('id: $id, ')
          ..write('manufacturerId: $manufacturerId, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('compatibleWithJson: $compatibleWithJson, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $CustomComponentsTable extends CustomComponents
    with TableInfo<$CustomComponentsTable, CustomComponentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomComponentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, kind, name, notes, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'custom_components';
  @override
  VerificationContext validateIntegrity(
    Insertable<CustomComponentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {kind, name},
  ];
  @override
  CustomComponentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomComponentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CustomComponentsTable createAlias(String alias) {
    return $CustomComponentsTable(attachedDatabase, alias);
  }
}

class CustomComponentRow extends DataClass
    implements Insertable<CustomComponentRow> {
  final int id;

  /// 'powder' | 'bullet' | 'primer' | 'brass' | 'cartridge'
  final String kind;
  final String name;
  final String? notes;
  final DateTime createdAt;
  const CustomComponentRow({
    required this.id,
    required this.kind,
    required this.name,
    this.notes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kind'] = Variable<String>(kind);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CustomComponentsCompanion toCompanion(bool nullToAbsent) {
    return CustomComponentsCompanion(
      id: Value(id),
      kind: Value(kind),
      name: Value(name),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory CustomComponentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomComponentRow(
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String>(json['name']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String>(name),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CustomComponentRow copyWith({
    int? id,
    String? kind,
    String? name,
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
  }) => CustomComponentRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
  );
  CustomComponentRow copyWithCompanion(CustomComponentsCompanion data) {
    return CustomComponentRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomComponentRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, name, notes, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomComponentRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class CustomComponentsCompanion extends UpdateCompanion<CustomComponentRow> {
  final Value<int> id;
  final Value<String> kind;
  final Value<String> name;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  const CustomComponentsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CustomComponentsCompanion.insert({
    this.id = const Value.absent(),
    required String kind,
    required String name,
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : kind = Value(kind),
       name = Value(name);
  static Insertable<CustomComponentRow> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CustomComponentsCompanion copyWith({
    Value<int>? id,
    Value<String>? kind,
    Value<String>? name,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
  }) {
    return CustomComponentsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomComponentsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $UserLoadsTable extends UserLoads
    with TableInfo<$UserLoadsTable, UserLoadRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserLoadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _caliberMeta = const VerificationMeta(
    'caliber',
  );
  @override
  late final GeneratedColumn<String> caliber = GeneratedColumn<String>(
    'caliber',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _powderMeta = const VerificationMeta('powder');
  @override
  late final GeneratedColumn<String> powder = GeneratedColumn<String>(
    'powder',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _powderChargeGrMeta = const VerificationMeta(
    'powderChargeGr',
  );
  @override
  late final GeneratedColumn<double> powderChargeGr = GeneratedColumn<double>(
    'powder_charge_gr',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bulletMeta = const VerificationMeta('bullet');
  @override
  late final GeneratedColumn<String> bullet = GeneratedColumn<String>(
    'bullet',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bulletWeightGrMeta = const VerificationMeta(
    'bulletWeightGr',
  );
  @override
  late final GeneratedColumn<double> bulletWeightGr = GeneratedColumn<double>(
    'bullet_weight_gr',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _primerMeta = const VerificationMeta('primer');
  @override
  late final GeneratedColumn<String> primer = GeneratedColumn<String>(
    'primer',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _brassMeta = const VerificationMeta('brass');
  @override
  late final GeneratedColumn<String> brass = GeneratedColumn<String>(
    'brass',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coalInMeta = const VerificationMeta('coalIn');
  @override
  late final GeneratedColumn<double> coalIn = GeneratedColumn<double>(
    'coal_in',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cbtoInMeta = const VerificationMeta('cbtoIn');
  @override
  late final GeneratedColumn<double> cbtoIn = GeneratedColumn<double>(
    'cbto_in',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seatingDepthInMeta = const VerificationMeta(
    'seatingDepthIn',
  );
  @override
  late final GeneratedColumn<double> seatingDepthIn = GeneratedColumn<double>(
    'seating_depth_in',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _primerDepthCpsMeta = const VerificationMeta(
    'primerDepthCps',
  );
  @override
  late final GeneratedColumn<double> primerDepthCps = GeneratedColumn<double>(
    'primer_depth_cps',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shoulderBumpInMeta = const VerificationMeta(
    'shoulderBumpIn',
  );
  @override
  late final GeneratedColumn<double> shoulderBumpIn = GeneratedColumn<double>(
    'shoulder_bump_in',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mandrelSizeInMeta = const VerificationMeta(
    'mandrelSizeIn',
  );
  @override
  late final GeneratedColumn<double> mandrelSizeIn = GeneratedColumn<double>(
    'mandrel_size_in',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateEstablishedMeta = const VerificationMeta(
    'dateEstablished',
  );
  @override
  late final GeneratedColumn<DateTime> dateEstablished =
      GeneratedColumn<DateTime>(
        'date_established',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    caliber,
    powder,
    powderChargeGr,
    bullet,
    bulletWeightGr,
    primer,
    brass,
    coalIn,
    cbtoIn,
    seatingDepthIn,
    primerDepthCps,
    shoulderBumpIn,
    mandrelSizeIn,
    dateEstablished,
    notes,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_loads';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserLoadRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('caliber')) {
      context.handle(
        _caliberMeta,
        caliber.isAcceptableOrUnknown(data['caliber']!, _caliberMeta),
      );
    }
    if (data.containsKey('powder')) {
      context.handle(
        _powderMeta,
        powder.isAcceptableOrUnknown(data['powder']!, _powderMeta),
      );
    }
    if (data.containsKey('powder_charge_gr')) {
      context.handle(
        _powderChargeGrMeta,
        powderChargeGr.isAcceptableOrUnknown(
          data['powder_charge_gr']!,
          _powderChargeGrMeta,
        ),
      );
    }
    if (data.containsKey('bullet')) {
      context.handle(
        _bulletMeta,
        bullet.isAcceptableOrUnknown(data['bullet']!, _bulletMeta),
      );
    }
    if (data.containsKey('bullet_weight_gr')) {
      context.handle(
        _bulletWeightGrMeta,
        bulletWeightGr.isAcceptableOrUnknown(
          data['bullet_weight_gr']!,
          _bulletWeightGrMeta,
        ),
      );
    }
    if (data.containsKey('primer')) {
      context.handle(
        _primerMeta,
        primer.isAcceptableOrUnknown(data['primer']!, _primerMeta),
      );
    }
    if (data.containsKey('brass')) {
      context.handle(
        _brassMeta,
        brass.isAcceptableOrUnknown(data['brass']!, _brassMeta),
      );
    }
    if (data.containsKey('coal_in')) {
      context.handle(
        _coalInMeta,
        coalIn.isAcceptableOrUnknown(data['coal_in']!, _coalInMeta),
      );
    }
    if (data.containsKey('cbto_in')) {
      context.handle(
        _cbtoInMeta,
        cbtoIn.isAcceptableOrUnknown(data['cbto_in']!, _cbtoInMeta),
      );
    }
    if (data.containsKey('seating_depth_in')) {
      context.handle(
        _seatingDepthInMeta,
        seatingDepthIn.isAcceptableOrUnknown(
          data['seating_depth_in']!,
          _seatingDepthInMeta,
        ),
      );
    }
    if (data.containsKey('primer_depth_cps')) {
      context.handle(
        _primerDepthCpsMeta,
        primerDepthCps.isAcceptableOrUnknown(
          data['primer_depth_cps']!,
          _primerDepthCpsMeta,
        ),
      );
    }
    if (data.containsKey('shoulder_bump_in')) {
      context.handle(
        _shoulderBumpInMeta,
        shoulderBumpIn.isAcceptableOrUnknown(
          data['shoulder_bump_in']!,
          _shoulderBumpInMeta,
        ),
      );
    }
    if (data.containsKey('mandrel_size_in')) {
      context.handle(
        _mandrelSizeInMeta,
        mandrelSizeIn.isAcceptableOrUnknown(
          data['mandrel_size_in']!,
          _mandrelSizeInMeta,
        ),
      );
    }
    if (data.containsKey('date_established')) {
      context.handle(
        _dateEstablishedMeta,
        dateEstablished.isAcceptableOrUnknown(
          data['date_established']!,
          _dateEstablishedMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserLoadRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserLoadRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      caliber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}caliber'],
      ),
      powder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}powder'],
      ),
      powderChargeGr: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}powder_charge_gr'],
      ),
      bullet: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bullet'],
      ),
      bulletWeightGr: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bullet_weight_gr'],
      ),
      primer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primer'],
      ),
      brass: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}brass'],
      ),
      coalIn: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}coal_in'],
      ),
      cbtoIn: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cbto_in'],
      ),
      seatingDepthIn: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}seating_depth_in'],
      ),
      primerDepthCps: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}primer_depth_cps'],
      ),
      shoulderBumpIn: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}shoulder_bump_in'],
      ),
      mandrelSizeIn: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}mandrel_size_in'],
      ),
      dateEstablished: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_established'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UserLoadsTable createAlias(String alias) {
    return $UserLoadsTable(attachedDatabase, alias);
  }
}

class UserLoadRow extends DataClass implements Insertable<UserLoadRow> {
  final int id;
  final String name;
  final String? caliber;
  final String? powder;
  final double? powderChargeGr;
  final String? bullet;
  final double? bulletWeightGr;
  final String? primer;
  final String? brass;
  final double? coalIn;
  final double? cbtoIn;
  final double? seatingDepthIn;
  final double? primerDepthCps;
  final double? shoulderBumpIn;
  final double? mandrelSizeIn;
  final DateTime? dateEstablished;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  const UserLoadRow({
    required this.id,
    required this.name,
    this.caliber,
    this.powder,
    this.powderChargeGr,
    this.bullet,
    this.bulletWeightGr,
    this.primer,
    this.brass,
    this.coalIn,
    this.cbtoIn,
    this.seatingDepthIn,
    this.primerDepthCps,
    this.shoulderBumpIn,
    this.mandrelSizeIn,
    this.dateEstablished,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || caliber != null) {
      map['caliber'] = Variable<String>(caliber);
    }
    if (!nullToAbsent || powder != null) {
      map['powder'] = Variable<String>(powder);
    }
    if (!nullToAbsent || powderChargeGr != null) {
      map['powder_charge_gr'] = Variable<double>(powderChargeGr);
    }
    if (!nullToAbsent || bullet != null) {
      map['bullet'] = Variable<String>(bullet);
    }
    if (!nullToAbsent || bulletWeightGr != null) {
      map['bullet_weight_gr'] = Variable<double>(bulletWeightGr);
    }
    if (!nullToAbsent || primer != null) {
      map['primer'] = Variable<String>(primer);
    }
    if (!nullToAbsent || brass != null) {
      map['brass'] = Variable<String>(brass);
    }
    if (!nullToAbsent || coalIn != null) {
      map['coal_in'] = Variable<double>(coalIn);
    }
    if (!nullToAbsent || cbtoIn != null) {
      map['cbto_in'] = Variable<double>(cbtoIn);
    }
    if (!nullToAbsent || seatingDepthIn != null) {
      map['seating_depth_in'] = Variable<double>(seatingDepthIn);
    }
    if (!nullToAbsent || primerDepthCps != null) {
      map['primer_depth_cps'] = Variable<double>(primerDepthCps);
    }
    if (!nullToAbsent || shoulderBumpIn != null) {
      map['shoulder_bump_in'] = Variable<double>(shoulderBumpIn);
    }
    if (!nullToAbsent || mandrelSizeIn != null) {
      map['mandrel_size_in'] = Variable<double>(mandrelSizeIn);
    }
    if (!nullToAbsent || dateEstablished != null) {
      map['date_established'] = Variable<DateTime>(dateEstablished);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserLoadsCompanion toCompanion(bool nullToAbsent) {
    return UserLoadsCompanion(
      id: Value(id),
      name: Value(name),
      caliber: caliber == null && nullToAbsent
          ? const Value.absent()
          : Value(caliber),
      powder: powder == null && nullToAbsent
          ? const Value.absent()
          : Value(powder),
      powderChargeGr: powderChargeGr == null && nullToAbsent
          ? const Value.absent()
          : Value(powderChargeGr),
      bullet: bullet == null && nullToAbsent
          ? const Value.absent()
          : Value(bullet),
      bulletWeightGr: bulletWeightGr == null && nullToAbsent
          ? const Value.absent()
          : Value(bulletWeightGr),
      primer: primer == null && nullToAbsent
          ? const Value.absent()
          : Value(primer),
      brass: brass == null && nullToAbsent
          ? const Value.absent()
          : Value(brass),
      coalIn: coalIn == null && nullToAbsent
          ? const Value.absent()
          : Value(coalIn),
      cbtoIn: cbtoIn == null && nullToAbsent
          ? const Value.absent()
          : Value(cbtoIn),
      seatingDepthIn: seatingDepthIn == null && nullToAbsent
          ? const Value.absent()
          : Value(seatingDepthIn),
      primerDepthCps: primerDepthCps == null && nullToAbsent
          ? const Value.absent()
          : Value(primerDepthCps),
      shoulderBumpIn: shoulderBumpIn == null && nullToAbsent
          ? const Value.absent()
          : Value(shoulderBumpIn),
      mandrelSizeIn: mandrelSizeIn == null && nullToAbsent
          ? const Value.absent()
          : Value(mandrelSizeIn),
      dateEstablished: dateEstablished == null && nullToAbsent
          ? const Value.absent()
          : Value(dateEstablished),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserLoadRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserLoadRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      caliber: serializer.fromJson<String?>(json['caliber']),
      powder: serializer.fromJson<String?>(json['powder']),
      powderChargeGr: serializer.fromJson<double?>(json['powderChargeGr']),
      bullet: serializer.fromJson<String?>(json['bullet']),
      bulletWeightGr: serializer.fromJson<double?>(json['bulletWeightGr']),
      primer: serializer.fromJson<String?>(json['primer']),
      brass: serializer.fromJson<String?>(json['brass']),
      coalIn: serializer.fromJson<double?>(json['coalIn']),
      cbtoIn: serializer.fromJson<double?>(json['cbtoIn']),
      seatingDepthIn: serializer.fromJson<double?>(json['seatingDepthIn']),
      primerDepthCps: serializer.fromJson<double?>(json['primerDepthCps']),
      shoulderBumpIn: serializer.fromJson<double?>(json['shoulderBumpIn']),
      mandrelSizeIn: serializer.fromJson<double?>(json['mandrelSizeIn']),
      dateEstablished: serializer.fromJson<DateTime?>(json['dateEstablished']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'caliber': serializer.toJson<String?>(caliber),
      'powder': serializer.toJson<String?>(powder),
      'powderChargeGr': serializer.toJson<double?>(powderChargeGr),
      'bullet': serializer.toJson<String?>(bullet),
      'bulletWeightGr': serializer.toJson<double?>(bulletWeightGr),
      'primer': serializer.toJson<String?>(primer),
      'brass': serializer.toJson<String?>(brass),
      'coalIn': serializer.toJson<double?>(coalIn),
      'cbtoIn': serializer.toJson<double?>(cbtoIn),
      'seatingDepthIn': serializer.toJson<double?>(seatingDepthIn),
      'primerDepthCps': serializer.toJson<double?>(primerDepthCps),
      'shoulderBumpIn': serializer.toJson<double?>(shoulderBumpIn),
      'mandrelSizeIn': serializer.toJson<double?>(mandrelSizeIn),
      'dateEstablished': serializer.toJson<DateTime?>(dateEstablished),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserLoadRow copyWith({
    int? id,
    String? name,
    Value<String?> caliber = const Value.absent(),
    Value<String?> powder = const Value.absent(),
    Value<double?> powderChargeGr = const Value.absent(),
    Value<String?> bullet = const Value.absent(),
    Value<double?> bulletWeightGr = const Value.absent(),
    Value<String?> primer = const Value.absent(),
    Value<String?> brass = const Value.absent(),
    Value<double?> coalIn = const Value.absent(),
    Value<double?> cbtoIn = const Value.absent(),
    Value<double?> seatingDepthIn = const Value.absent(),
    Value<double?> primerDepthCps = const Value.absent(),
    Value<double?> shoulderBumpIn = const Value.absent(),
    Value<double?> mandrelSizeIn = const Value.absent(),
    Value<DateTime?> dateEstablished = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => UserLoadRow(
    id: id ?? this.id,
    name: name ?? this.name,
    caliber: caliber.present ? caliber.value : this.caliber,
    powder: powder.present ? powder.value : this.powder,
    powderChargeGr: powderChargeGr.present
        ? powderChargeGr.value
        : this.powderChargeGr,
    bullet: bullet.present ? bullet.value : this.bullet,
    bulletWeightGr: bulletWeightGr.present
        ? bulletWeightGr.value
        : this.bulletWeightGr,
    primer: primer.present ? primer.value : this.primer,
    brass: brass.present ? brass.value : this.brass,
    coalIn: coalIn.present ? coalIn.value : this.coalIn,
    cbtoIn: cbtoIn.present ? cbtoIn.value : this.cbtoIn,
    seatingDepthIn: seatingDepthIn.present
        ? seatingDepthIn.value
        : this.seatingDepthIn,
    primerDepthCps: primerDepthCps.present
        ? primerDepthCps.value
        : this.primerDepthCps,
    shoulderBumpIn: shoulderBumpIn.present
        ? shoulderBumpIn.value
        : this.shoulderBumpIn,
    mandrelSizeIn: mandrelSizeIn.present
        ? mandrelSizeIn.value
        : this.mandrelSizeIn,
    dateEstablished: dateEstablished.present
        ? dateEstablished.value
        : this.dateEstablished,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserLoadRow copyWithCompanion(UserLoadsCompanion data) {
    return UserLoadRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      caliber: data.caliber.present ? data.caliber.value : this.caliber,
      powder: data.powder.present ? data.powder.value : this.powder,
      powderChargeGr: data.powderChargeGr.present
          ? data.powderChargeGr.value
          : this.powderChargeGr,
      bullet: data.bullet.present ? data.bullet.value : this.bullet,
      bulletWeightGr: data.bulletWeightGr.present
          ? data.bulletWeightGr.value
          : this.bulletWeightGr,
      primer: data.primer.present ? data.primer.value : this.primer,
      brass: data.brass.present ? data.brass.value : this.brass,
      coalIn: data.coalIn.present ? data.coalIn.value : this.coalIn,
      cbtoIn: data.cbtoIn.present ? data.cbtoIn.value : this.cbtoIn,
      seatingDepthIn: data.seatingDepthIn.present
          ? data.seatingDepthIn.value
          : this.seatingDepthIn,
      primerDepthCps: data.primerDepthCps.present
          ? data.primerDepthCps.value
          : this.primerDepthCps,
      shoulderBumpIn: data.shoulderBumpIn.present
          ? data.shoulderBumpIn.value
          : this.shoulderBumpIn,
      mandrelSizeIn: data.mandrelSizeIn.present
          ? data.mandrelSizeIn.value
          : this.mandrelSizeIn,
      dateEstablished: data.dateEstablished.present
          ? data.dateEstablished.value
          : this.dateEstablished,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserLoadRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('caliber: $caliber, ')
          ..write('powder: $powder, ')
          ..write('powderChargeGr: $powderChargeGr, ')
          ..write('bullet: $bullet, ')
          ..write('bulletWeightGr: $bulletWeightGr, ')
          ..write('primer: $primer, ')
          ..write('brass: $brass, ')
          ..write('coalIn: $coalIn, ')
          ..write('cbtoIn: $cbtoIn, ')
          ..write('seatingDepthIn: $seatingDepthIn, ')
          ..write('primerDepthCps: $primerDepthCps, ')
          ..write('shoulderBumpIn: $shoulderBumpIn, ')
          ..write('mandrelSizeIn: $mandrelSizeIn, ')
          ..write('dateEstablished: $dateEstablished, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    caliber,
    powder,
    powderChargeGr,
    bullet,
    bulletWeightGr,
    primer,
    brass,
    coalIn,
    cbtoIn,
    seatingDepthIn,
    primerDepthCps,
    shoulderBumpIn,
    mandrelSizeIn,
    dateEstablished,
    notes,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserLoadRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.caliber == this.caliber &&
          other.powder == this.powder &&
          other.powderChargeGr == this.powderChargeGr &&
          other.bullet == this.bullet &&
          other.bulletWeightGr == this.bulletWeightGr &&
          other.primer == this.primer &&
          other.brass == this.brass &&
          other.coalIn == this.coalIn &&
          other.cbtoIn == this.cbtoIn &&
          other.seatingDepthIn == this.seatingDepthIn &&
          other.primerDepthCps == this.primerDepthCps &&
          other.shoulderBumpIn == this.shoulderBumpIn &&
          other.mandrelSizeIn == this.mandrelSizeIn &&
          other.dateEstablished == this.dateEstablished &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class UserLoadsCompanion extends UpdateCompanion<UserLoadRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> caliber;
  final Value<String?> powder;
  final Value<double?> powderChargeGr;
  final Value<String?> bullet;
  final Value<double?> bulletWeightGr;
  final Value<String?> primer;
  final Value<String?> brass;
  final Value<double?> coalIn;
  final Value<double?> cbtoIn;
  final Value<double?> seatingDepthIn;
  final Value<double?> primerDepthCps;
  final Value<double?> shoulderBumpIn;
  final Value<double?> mandrelSizeIn;
  final Value<DateTime?> dateEstablished;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const UserLoadsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.caliber = const Value.absent(),
    this.powder = const Value.absent(),
    this.powderChargeGr = const Value.absent(),
    this.bullet = const Value.absent(),
    this.bulletWeightGr = const Value.absent(),
    this.primer = const Value.absent(),
    this.brass = const Value.absent(),
    this.coalIn = const Value.absent(),
    this.cbtoIn = const Value.absent(),
    this.seatingDepthIn = const Value.absent(),
    this.primerDepthCps = const Value.absent(),
    this.shoulderBumpIn = const Value.absent(),
    this.mandrelSizeIn = const Value.absent(),
    this.dateEstablished = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  UserLoadsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.caliber = const Value.absent(),
    this.powder = const Value.absent(),
    this.powderChargeGr = const Value.absent(),
    this.bullet = const Value.absent(),
    this.bulletWeightGr = const Value.absent(),
    this.primer = const Value.absent(),
    this.brass = const Value.absent(),
    this.coalIn = const Value.absent(),
    this.cbtoIn = const Value.absent(),
    this.seatingDepthIn = const Value.absent(),
    this.primerDepthCps = const Value.absent(),
    this.shoulderBumpIn = const Value.absent(),
    this.mandrelSizeIn = const Value.absent(),
    this.dateEstablished = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<UserLoadRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? caliber,
    Expression<String>? powder,
    Expression<double>? powderChargeGr,
    Expression<String>? bullet,
    Expression<double>? bulletWeightGr,
    Expression<String>? primer,
    Expression<String>? brass,
    Expression<double>? coalIn,
    Expression<double>? cbtoIn,
    Expression<double>? seatingDepthIn,
    Expression<double>? primerDepthCps,
    Expression<double>? shoulderBumpIn,
    Expression<double>? mandrelSizeIn,
    Expression<DateTime>? dateEstablished,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (caliber != null) 'caliber': caliber,
      if (powder != null) 'powder': powder,
      if (powderChargeGr != null) 'powder_charge_gr': powderChargeGr,
      if (bullet != null) 'bullet': bullet,
      if (bulletWeightGr != null) 'bullet_weight_gr': bulletWeightGr,
      if (primer != null) 'primer': primer,
      if (brass != null) 'brass': brass,
      if (coalIn != null) 'coal_in': coalIn,
      if (cbtoIn != null) 'cbto_in': cbtoIn,
      if (seatingDepthIn != null) 'seating_depth_in': seatingDepthIn,
      if (primerDepthCps != null) 'primer_depth_cps': primerDepthCps,
      if (shoulderBumpIn != null) 'shoulder_bump_in': shoulderBumpIn,
      if (mandrelSizeIn != null) 'mandrel_size_in': mandrelSizeIn,
      if (dateEstablished != null) 'date_established': dateEstablished,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  UserLoadsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? caliber,
    Value<String?>? powder,
    Value<double?>? powderChargeGr,
    Value<String?>? bullet,
    Value<double?>? bulletWeightGr,
    Value<String?>? primer,
    Value<String?>? brass,
    Value<double?>? coalIn,
    Value<double?>? cbtoIn,
    Value<double?>? seatingDepthIn,
    Value<double?>? primerDepthCps,
    Value<double?>? shoulderBumpIn,
    Value<double?>? mandrelSizeIn,
    Value<DateTime?>? dateEstablished,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return UserLoadsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      caliber: caliber ?? this.caliber,
      powder: powder ?? this.powder,
      powderChargeGr: powderChargeGr ?? this.powderChargeGr,
      bullet: bullet ?? this.bullet,
      bulletWeightGr: bulletWeightGr ?? this.bulletWeightGr,
      primer: primer ?? this.primer,
      brass: brass ?? this.brass,
      coalIn: coalIn ?? this.coalIn,
      cbtoIn: cbtoIn ?? this.cbtoIn,
      seatingDepthIn: seatingDepthIn ?? this.seatingDepthIn,
      primerDepthCps: primerDepthCps ?? this.primerDepthCps,
      shoulderBumpIn: shoulderBumpIn ?? this.shoulderBumpIn,
      mandrelSizeIn: mandrelSizeIn ?? this.mandrelSizeIn,
      dateEstablished: dateEstablished ?? this.dateEstablished,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (caliber.present) {
      map['caliber'] = Variable<String>(caliber.value);
    }
    if (powder.present) {
      map['powder'] = Variable<String>(powder.value);
    }
    if (powderChargeGr.present) {
      map['powder_charge_gr'] = Variable<double>(powderChargeGr.value);
    }
    if (bullet.present) {
      map['bullet'] = Variable<String>(bullet.value);
    }
    if (bulletWeightGr.present) {
      map['bullet_weight_gr'] = Variable<double>(bulletWeightGr.value);
    }
    if (primer.present) {
      map['primer'] = Variable<String>(primer.value);
    }
    if (brass.present) {
      map['brass'] = Variable<String>(brass.value);
    }
    if (coalIn.present) {
      map['coal_in'] = Variable<double>(coalIn.value);
    }
    if (cbtoIn.present) {
      map['cbto_in'] = Variable<double>(cbtoIn.value);
    }
    if (seatingDepthIn.present) {
      map['seating_depth_in'] = Variable<double>(seatingDepthIn.value);
    }
    if (primerDepthCps.present) {
      map['primer_depth_cps'] = Variable<double>(primerDepthCps.value);
    }
    if (shoulderBumpIn.present) {
      map['shoulder_bump_in'] = Variable<double>(shoulderBumpIn.value);
    }
    if (mandrelSizeIn.present) {
      map['mandrel_size_in'] = Variable<double>(mandrelSizeIn.value);
    }
    if (dateEstablished.present) {
      map['date_established'] = Variable<DateTime>(dateEstablished.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserLoadsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('caliber: $caliber, ')
          ..write('powder: $powder, ')
          ..write('powderChargeGr: $powderChargeGr, ')
          ..write('bullet: $bullet, ')
          ..write('bulletWeightGr: $bulletWeightGr, ')
          ..write('primer: $primer, ')
          ..write('brass: $brass, ')
          ..write('coalIn: $coalIn, ')
          ..write('cbtoIn: $cbtoIn, ')
          ..write('seatingDepthIn: $seatingDepthIn, ')
          ..write('primerDepthCps: $primerDepthCps, ')
          ..write('shoulderBumpIn: $shoulderBumpIn, ')
          ..write('mandrelSizeIn: $mandrelSizeIn, ')
          ..write('dateEstablished: $dateEstablished, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $UserFirearmsTable extends UserFirearms
    with TableInfo<$UserFirearmsTable, UserFirearmRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserFirearmsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _manufacturerMeta = const VerificationMeta(
    'manufacturer',
  );
  @override
  late final GeneratedColumn<String> manufacturer = GeneratedColumn<String>(
    'manufacturer',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _caliberMeta = const VerificationMeta(
    'caliber',
  );
  @override
  late final GeneratedColumn<String> caliber = GeneratedColumn<String>(
    'caliber',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _barrelLengthInMeta = const VerificationMeta(
    'barrelLengthIn',
  );
  @override
  late final GeneratedColumn<double> barrelLengthIn = GeneratedColumn<double>(
    'barrel_length_in',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _twistRateMeta = const VerificationMeta(
    'twistRate',
  );
  @override
  late final GeneratedColumn<String> twistRate = GeneratedColumn<String>(
    'twist_rate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shotsFiredMeta = const VerificationMeta(
    'shotsFired',
  );
  @override
  late final GeneratedColumn<int> shotsFired = GeneratedColumn<int>(
    'shots_fired',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _referenceFirearmIdMeta =
      const VerificationMeta('referenceFirearmId');
  @override
  late final GeneratedColumn<int> referenceFirearmId = GeneratedColumn<int>(
    'reference_firearm_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    manufacturer,
    model,
    type,
    action,
    caliber,
    barrelLengthIn,
    twistRate,
    shotsFired,
    referenceFirearmId,
    notes,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_firearms';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserFirearmRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('manufacturer')) {
      context.handle(
        _manufacturerMeta,
        manufacturer.isAcceptableOrUnknown(
          data['manufacturer']!,
          _manufacturerMeta,
        ),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    }
    if (data.containsKey('caliber')) {
      context.handle(
        _caliberMeta,
        caliber.isAcceptableOrUnknown(data['caliber']!, _caliberMeta),
      );
    }
    if (data.containsKey('barrel_length_in')) {
      context.handle(
        _barrelLengthInMeta,
        barrelLengthIn.isAcceptableOrUnknown(
          data['barrel_length_in']!,
          _barrelLengthInMeta,
        ),
      );
    }
    if (data.containsKey('twist_rate')) {
      context.handle(
        _twistRateMeta,
        twistRate.isAcceptableOrUnknown(data['twist_rate']!, _twistRateMeta),
      );
    }
    if (data.containsKey('shots_fired')) {
      context.handle(
        _shotsFiredMeta,
        shotsFired.isAcceptableOrUnknown(data['shots_fired']!, _shotsFiredMeta),
      );
    }
    if (data.containsKey('reference_firearm_id')) {
      context.handle(
        _referenceFirearmIdMeta,
        referenceFirearmId.isAcceptableOrUnknown(
          data['reference_firearm_id']!,
          _referenceFirearmIdMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserFirearmRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserFirearmRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      manufacturer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manufacturer'],
      ),
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      ),
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      ),
      caliber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}caliber'],
      ),
      barrelLengthIn: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}barrel_length_in'],
      ),
      twistRate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}twist_rate'],
      ),
      shotsFired: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}shots_fired'],
      )!,
      referenceFirearmId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reference_firearm_id'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UserFirearmsTable createAlias(String alias) {
    return $UserFirearmsTable(attachedDatabase, alias);
  }
}

class UserFirearmRow extends DataClass implements Insertable<UserFirearmRow> {
  final int id;
  final String name;
  final String? manufacturer;
  final String? model;
  final String? type;
  final String? action;
  final String? caliber;
  final double? barrelLengthIn;
  final String? twistRate;
  final int shotsFired;

  /// If picked from reference catalog, the FirearmsRef.id; null for custom.
  final int? referenceFirearmId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  const UserFirearmRow({
    required this.id,
    required this.name,
    this.manufacturer,
    this.model,
    this.type,
    this.action,
    this.caliber,
    this.barrelLengthIn,
    this.twistRate,
    required this.shotsFired,
    this.referenceFirearmId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || manufacturer != null) {
      map['manufacturer'] = Variable<String>(manufacturer);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<String>(type);
    }
    if (!nullToAbsent || action != null) {
      map['action'] = Variable<String>(action);
    }
    if (!nullToAbsent || caliber != null) {
      map['caliber'] = Variable<String>(caliber);
    }
    if (!nullToAbsent || barrelLengthIn != null) {
      map['barrel_length_in'] = Variable<double>(barrelLengthIn);
    }
    if (!nullToAbsent || twistRate != null) {
      map['twist_rate'] = Variable<String>(twistRate);
    }
    map['shots_fired'] = Variable<int>(shotsFired);
    if (!nullToAbsent || referenceFirearmId != null) {
      map['reference_firearm_id'] = Variable<int>(referenceFirearmId);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserFirearmsCompanion toCompanion(bool nullToAbsent) {
    return UserFirearmsCompanion(
      id: Value(id),
      name: Value(name),
      manufacturer: manufacturer == null && nullToAbsent
          ? const Value.absent()
          : Value(manufacturer),
      model: model == null && nullToAbsent
          ? const Value.absent()
          : Value(model),
      type: type == null && nullToAbsent ? const Value.absent() : Value(type),
      action: action == null && nullToAbsent
          ? const Value.absent()
          : Value(action),
      caliber: caliber == null && nullToAbsent
          ? const Value.absent()
          : Value(caliber),
      barrelLengthIn: barrelLengthIn == null && nullToAbsent
          ? const Value.absent()
          : Value(barrelLengthIn),
      twistRate: twistRate == null && nullToAbsent
          ? const Value.absent()
          : Value(twistRate),
      shotsFired: Value(shotsFired),
      referenceFirearmId: referenceFirearmId == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceFirearmId),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserFirearmRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserFirearmRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      manufacturer: serializer.fromJson<String?>(json['manufacturer']),
      model: serializer.fromJson<String?>(json['model']),
      type: serializer.fromJson<String?>(json['type']),
      action: serializer.fromJson<String?>(json['action']),
      caliber: serializer.fromJson<String?>(json['caliber']),
      barrelLengthIn: serializer.fromJson<double?>(json['barrelLengthIn']),
      twistRate: serializer.fromJson<String?>(json['twistRate']),
      shotsFired: serializer.fromJson<int>(json['shotsFired']),
      referenceFirearmId: serializer.fromJson<int?>(json['referenceFirearmId']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'manufacturer': serializer.toJson<String?>(manufacturer),
      'model': serializer.toJson<String?>(model),
      'type': serializer.toJson<String?>(type),
      'action': serializer.toJson<String?>(action),
      'caliber': serializer.toJson<String?>(caliber),
      'barrelLengthIn': serializer.toJson<double?>(barrelLengthIn),
      'twistRate': serializer.toJson<String?>(twistRate),
      'shotsFired': serializer.toJson<int>(shotsFired),
      'referenceFirearmId': serializer.toJson<int?>(referenceFirearmId),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserFirearmRow copyWith({
    int? id,
    String? name,
    Value<String?> manufacturer = const Value.absent(),
    Value<String?> model = const Value.absent(),
    Value<String?> type = const Value.absent(),
    Value<String?> action = const Value.absent(),
    Value<String?> caliber = const Value.absent(),
    Value<double?> barrelLengthIn = const Value.absent(),
    Value<String?> twistRate = const Value.absent(),
    int? shotsFired,
    Value<int?> referenceFirearmId = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => UserFirearmRow(
    id: id ?? this.id,
    name: name ?? this.name,
    manufacturer: manufacturer.present ? manufacturer.value : this.manufacturer,
    model: model.present ? model.value : this.model,
    type: type.present ? type.value : this.type,
    action: action.present ? action.value : this.action,
    caliber: caliber.present ? caliber.value : this.caliber,
    barrelLengthIn: barrelLengthIn.present
        ? barrelLengthIn.value
        : this.barrelLengthIn,
    twistRate: twistRate.present ? twistRate.value : this.twistRate,
    shotsFired: shotsFired ?? this.shotsFired,
    referenceFirearmId: referenceFirearmId.present
        ? referenceFirearmId.value
        : this.referenceFirearmId,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserFirearmRow copyWithCompanion(UserFirearmsCompanion data) {
    return UserFirearmRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      manufacturer: data.manufacturer.present
          ? data.manufacturer.value
          : this.manufacturer,
      model: data.model.present ? data.model.value : this.model,
      type: data.type.present ? data.type.value : this.type,
      action: data.action.present ? data.action.value : this.action,
      caliber: data.caliber.present ? data.caliber.value : this.caliber,
      barrelLengthIn: data.barrelLengthIn.present
          ? data.barrelLengthIn.value
          : this.barrelLengthIn,
      twistRate: data.twistRate.present ? data.twistRate.value : this.twistRate,
      shotsFired: data.shotsFired.present
          ? data.shotsFired.value
          : this.shotsFired,
      referenceFirearmId: data.referenceFirearmId.present
          ? data.referenceFirearmId.value
          : this.referenceFirearmId,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserFirearmRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('manufacturer: $manufacturer, ')
          ..write('model: $model, ')
          ..write('type: $type, ')
          ..write('action: $action, ')
          ..write('caliber: $caliber, ')
          ..write('barrelLengthIn: $barrelLengthIn, ')
          ..write('twistRate: $twistRate, ')
          ..write('shotsFired: $shotsFired, ')
          ..write('referenceFirearmId: $referenceFirearmId, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    manufacturer,
    model,
    type,
    action,
    caliber,
    barrelLengthIn,
    twistRate,
    shotsFired,
    referenceFirearmId,
    notes,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserFirearmRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.manufacturer == this.manufacturer &&
          other.model == this.model &&
          other.type == this.type &&
          other.action == this.action &&
          other.caliber == this.caliber &&
          other.barrelLengthIn == this.barrelLengthIn &&
          other.twistRate == this.twistRate &&
          other.shotsFired == this.shotsFired &&
          other.referenceFirearmId == this.referenceFirearmId &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class UserFirearmsCompanion extends UpdateCompanion<UserFirearmRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> manufacturer;
  final Value<String?> model;
  final Value<String?> type;
  final Value<String?> action;
  final Value<String?> caliber;
  final Value<double?> barrelLengthIn;
  final Value<String?> twistRate;
  final Value<int> shotsFired;
  final Value<int?> referenceFirearmId;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const UserFirearmsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.manufacturer = const Value.absent(),
    this.model = const Value.absent(),
    this.type = const Value.absent(),
    this.action = const Value.absent(),
    this.caliber = const Value.absent(),
    this.barrelLengthIn = const Value.absent(),
    this.twistRate = const Value.absent(),
    this.shotsFired = const Value.absent(),
    this.referenceFirearmId = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  UserFirearmsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.manufacturer = const Value.absent(),
    this.model = const Value.absent(),
    this.type = const Value.absent(),
    this.action = const Value.absent(),
    this.caliber = const Value.absent(),
    this.barrelLengthIn = const Value.absent(),
    this.twistRate = const Value.absent(),
    this.shotsFired = const Value.absent(),
    this.referenceFirearmId = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<UserFirearmRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? manufacturer,
    Expression<String>? model,
    Expression<String>? type,
    Expression<String>? action,
    Expression<String>? caliber,
    Expression<double>? barrelLengthIn,
    Expression<String>? twistRate,
    Expression<int>? shotsFired,
    Expression<int>? referenceFirearmId,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (manufacturer != null) 'manufacturer': manufacturer,
      if (model != null) 'model': model,
      if (type != null) 'type': type,
      if (action != null) 'action': action,
      if (caliber != null) 'caliber': caliber,
      if (barrelLengthIn != null) 'barrel_length_in': barrelLengthIn,
      if (twistRate != null) 'twist_rate': twistRate,
      if (shotsFired != null) 'shots_fired': shotsFired,
      if (referenceFirearmId != null)
        'reference_firearm_id': referenceFirearmId,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  UserFirearmsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? manufacturer,
    Value<String?>? model,
    Value<String?>? type,
    Value<String?>? action,
    Value<String?>? caliber,
    Value<double?>? barrelLengthIn,
    Value<String?>? twistRate,
    Value<int>? shotsFired,
    Value<int?>? referenceFirearmId,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return UserFirearmsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      type: type ?? this.type,
      action: action ?? this.action,
      caliber: caliber ?? this.caliber,
      barrelLengthIn: barrelLengthIn ?? this.barrelLengthIn,
      twistRate: twistRate ?? this.twistRate,
      shotsFired: shotsFired ?? this.shotsFired,
      referenceFirearmId: referenceFirearmId ?? this.referenceFirearmId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (manufacturer.present) {
      map['manufacturer'] = Variable<String>(manufacturer.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (caliber.present) {
      map['caliber'] = Variable<String>(caliber.value);
    }
    if (barrelLengthIn.present) {
      map['barrel_length_in'] = Variable<double>(barrelLengthIn.value);
    }
    if (twistRate.present) {
      map['twist_rate'] = Variable<String>(twistRate.value);
    }
    if (shotsFired.present) {
      map['shots_fired'] = Variable<int>(shotsFired.value);
    }
    if (referenceFirearmId.present) {
      map['reference_firearm_id'] = Variable<int>(referenceFirearmId.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserFirearmsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('manufacturer: $manufacturer, ')
          ..write('model: $model, ')
          ..write('type: $type, ')
          ..write('action: $action, ')
          ..write('caliber: $caliber, ')
          ..write('barrelLengthIn: $barrelLengthIn, ')
          ..write('twistRate: $twistRate, ')
          ..write('shotsFired: $shotsFired, ')
          ..write('referenceFirearmId: $referenceFirearmId, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ManufacturersTable manufacturers = $ManufacturersTable(this);
  late final $CartridgesTable cartridges = $CartridgesTable(this);
  late final $PowdersTable powders = $PowdersTable(this);
  late final $BulletsTable bullets = $BulletsTable(this);
  late final $PrimersTable primers = $PrimersTable(this);
  late final $BrassProductsTable brassProducts = $BrassProductsTable(this);
  late final $FirearmsRefTable firearmsRef = $FirearmsRefTable(this);
  late final $FirearmPartsTable firearmParts = $FirearmPartsTable(this);
  late final $CustomComponentsTable customComponents = $CustomComponentsTable(
    this,
  );
  late final $UserLoadsTable userLoads = $UserLoadsTable(this);
  late final $UserFirearmsTable userFirearms = $UserFirearmsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    manufacturers,
    cartridges,
    powders,
    bullets,
    primers,
    brassProducts,
    firearmsRef,
    firearmParts,
    customComponents,
    userLoads,
    userFirearms,
  ];
}

typedef $$ManufacturersTableCreateCompanionBuilder =
    ManufacturersCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> country,
      required String kind,
    });
typedef $$ManufacturersTableUpdateCompanionBuilder =
    ManufacturersCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> country,
      Value<String> kind,
    });

final class $$ManufacturersTableReferences
    extends
        BaseReferences<_$AppDatabase, $ManufacturersTable, ManufacturerRow> {
  $$ManufacturersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$PowdersTable, List<PowderRow>> _powdersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.powders,
    aliasName: $_aliasNameGenerator(
      db.manufacturers.id,
      db.powders.manufacturerId,
    ),
  );

  $$PowdersTableProcessedTableManager get powdersRefs {
    final manager = $$PowdersTableTableManager(
      $_db,
      $_db.powders,
    ).filter((f) => f.manufacturerId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_powdersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BulletsTable, List<BulletRow>> _bulletsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.bullets,
    aliasName: $_aliasNameGenerator(
      db.manufacturers.id,
      db.bullets.manufacturerId,
    ),
  );

  $$BulletsTableProcessedTableManager get bulletsRefs {
    final manager = $$BulletsTableTableManager(
      $_db,
      $_db.bullets,
    ).filter((f) => f.manufacturerId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_bulletsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PrimersTable, List<PrimerRow>> _primersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.primers,
    aliasName: $_aliasNameGenerator(
      db.manufacturers.id,
      db.primers.manufacturerId,
    ),
  );

  $$PrimersTableProcessedTableManager get primersRefs {
    final manager = $$PrimersTableTableManager(
      $_db,
      $_db.primers,
    ).filter((f) => f.manufacturerId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_primersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BrassProductsTable, List<BrassProductRow>>
  _brassProductsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.brassProducts,
    aliasName: $_aliasNameGenerator(
      db.manufacturers.id,
      db.brassProducts.manufacturerId,
    ),
  );

  $$BrassProductsTableProcessedTableManager get brassProductsRefs {
    final manager = $$BrassProductsTableTableManager(
      $_db,
      $_db.brassProducts,
    ).filter((f) => f.manufacturerId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_brassProductsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FirearmsRefTable, List<FirearmRefRow>>
  _firearmsRefRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.firearmsRef,
    aliasName: $_aliasNameGenerator(
      db.manufacturers.id,
      db.firearmsRef.manufacturerId,
    ),
  );

  $$FirearmsRefTableProcessedTableManager get firearmsRefRefs {
    final manager = $$FirearmsRefTableTableManager(
      $_db,
      $_db.firearmsRef,
    ).filter((f) => f.manufacturerId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_firearmsRefRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FirearmPartsTable, List<FirearmPartRow>>
  _firearmPartsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.firearmParts,
    aliasName: $_aliasNameGenerator(
      db.manufacturers.id,
      db.firearmParts.manufacturerId,
    ),
  );

  $$FirearmPartsTableProcessedTableManager get firearmPartsRefs {
    final manager = $$FirearmPartsTableTableManager(
      $_db,
      $_db.firearmParts,
    ).filter((f) => f.manufacturerId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_firearmPartsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ManufacturersTableFilterComposer
    extends Composer<_$AppDatabase, $ManufacturersTable> {
  $$ManufacturersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> powdersRefs(
    Expression<bool> Function($$PowdersTableFilterComposer f) f,
  ) {
    final $$PowdersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.powders,
      getReferencedColumn: (t) => t.manufacturerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PowdersTableFilterComposer(
            $db: $db,
            $table: $db.powders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bulletsRefs(
    Expression<bool> Function($$BulletsTableFilterComposer f) f,
  ) {
    final $$BulletsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bullets,
      getReferencedColumn: (t) => t.manufacturerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BulletsTableFilterComposer(
            $db: $db,
            $table: $db.bullets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> primersRefs(
    Expression<bool> Function($$PrimersTableFilterComposer f) f,
  ) {
    final $$PrimersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.primers,
      getReferencedColumn: (t) => t.manufacturerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrimersTableFilterComposer(
            $db: $db,
            $table: $db.primers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> brassProductsRefs(
    Expression<bool> Function($$BrassProductsTableFilterComposer f) f,
  ) {
    final $$BrassProductsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.brassProducts,
      getReferencedColumn: (t) => t.manufacturerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BrassProductsTableFilterComposer(
            $db: $db,
            $table: $db.brassProducts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> firearmsRefRefs(
    Expression<bool> Function($$FirearmsRefTableFilterComposer f) f,
  ) {
    final $$FirearmsRefTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.firearmsRef,
      getReferencedColumn: (t) => t.manufacturerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FirearmsRefTableFilterComposer(
            $db: $db,
            $table: $db.firearmsRef,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> firearmPartsRefs(
    Expression<bool> Function($$FirearmPartsTableFilterComposer f) f,
  ) {
    final $$FirearmPartsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.firearmParts,
      getReferencedColumn: (t) => t.manufacturerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FirearmPartsTableFilterComposer(
            $db: $db,
            $table: $db.firearmParts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ManufacturersTableOrderingComposer
    extends Composer<_$AppDatabase, $ManufacturersTable> {
  $$ManufacturersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ManufacturersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ManufacturersTable> {
  $$ManufacturersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get country =>
      $composableBuilder(column: $table.country, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  Expression<T> powdersRefs<T extends Object>(
    Expression<T> Function($$PowdersTableAnnotationComposer a) f,
  ) {
    final $$PowdersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.powders,
      getReferencedColumn: (t) => t.manufacturerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PowdersTableAnnotationComposer(
            $db: $db,
            $table: $db.powders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> bulletsRefs<T extends Object>(
    Expression<T> Function($$BulletsTableAnnotationComposer a) f,
  ) {
    final $$BulletsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bullets,
      getReferencedColumn: (t) => t.manufacturerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BulletsTableAnnotationComposer(
            $db: $db,
            $table: $db.bullets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> primersRefs<T extends Object>(
    Expression<T> Function($$PrimersTableAnnotationComposer a) f,
  ) {
    final $$PrimersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.primers,
      getReferencedColumn: (t) => t.manufacturerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrimersTableAnnotationComposer(
            $db: $db,
            $table: $db.primers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> brassProductsRefs<T extends Object>(
    Expression<T> Function($$BrassProductsTableAnnotationComposer a) f,
  ) {
    final $$BrassProductsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.brassProducts,
      getReferencedColumn: (t) => t.manufacturerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BrassProductsTableAnnotationComposer(
            $db: $db,
            $table: $db.brassProducts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> firearmsRefRefs<T extends Object>(
    Expression<T> Function($$FirearmsRefTableAnnotationComposer a) f,
  ) {
    final $$FirearmsRefTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.firearmsRef,
      getReferencedColumn: (t) => t.manufacturerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FirearmsRefTableAnnotationComposer(
            $db: $db,
            $table: $db.firearmsRef,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> firearmPartsRefs<T extends Object>(
    Expression<T> Function($$FirearmPartsTableAnnotationComposer a) f,
  ) {
    final $$FirearmPartsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.firearmParts,
      getReferencedColumn: (t) => t.manufacturerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FirearmPartsTableAnnotationComposer(
            $db: $db,
            $table: $db.firearmParts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ManufacturersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ManufacturersTable,
          ManufacturerRow,
          $$ManufacturersTableFilterComposer,
          $$ManufacturersTableOrderingComposer,
          $$ManufacturersTableAnnotationComposer,
          $$ManufacturersTableCreateCompanionBuilder,
          $$ManufacturersTableUpdateCompanionBuilder,
          (ManufacturerRow, $$ManufacturersTableReferences),
          ManufacturerRow,
          PrefetchHooks Function({
            bool powdersRefs,
            bool bulletsRefs,
            bool primersRefs,
            bool brassProductsRefs,
            bool firearmsRefRefs,
            bool firearmPartsRefs,
          })
        > {
  $$ManufacturersTableTableManager(_$AppDatabase db, $ManufacturersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ManufacturersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ManufacturersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ManufacturersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> country = const Value.absent(),
                Value<String> kind = const Value.absent(),
              }) => ManufacturersCompanion(
                id: id,
                name: name,
                country: country,
                kind: kind,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> country = const Value.absent(),
                required String kind,
              }) => ManufacturersCompanion.insert(
                id: id,
                name: name,
                country: country,
                kind: kind,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ManufacturersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                powdersRefs = false,
                bulletsRefs = false,
                primersRefs = false,
                brassProductsRefs = false,
                firearmsRefRefs = false,
                firearmPartsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (powdersRefs) db.powders,
                    if (bulletsRefs) db.bullets,
                    if (primersRefs) db.primers,
                    if (brassProductsRefs) db.brassProducts,
                    if (firearmsRefRefs) db.firearmsRef,
                    if (firearmPartsRefs) db.firearmParts,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (powdersRefs)
                        await $_getPrefetchedData<
                          ManufacturerRow,
                          $ManufacturersTable,
                          PowderRow
                        >(
                          currentTable: table,
                          referencedTable: $$ManufacturersTableReferences
                              ._powdersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ManufacturersTableReferences(
                                db,
                                table,
                                p0,
                              ).powdersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.manufacturerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (bulletsRefs)
                        await $_getPrefetchedData<
                          ManufacturerRow,
                          $ManufacturersTable,
                          BulletRow
                        >(
                          currentTable: table,
                          referencedTable: $$ManufacturersTableReferences
                              ._bulletsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ManufacturersTableReferences(
                                db,
                                table,
                                p0,
                              ).bulletsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.manufacturerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (primersRefs)
                        await $_getPrefetchedData<
                          ManufacturerRow,
                          $ManufacturersTable,
                          PrimerRow
                        >(
                          currentTable: table,
                          referencedTable: $$ManufacturersTableReferences
                              ._primersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ManufacturersTableReferences(
                                db,
                                table,
                                p0,
                              ).primersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.manufacturerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (brassProductsRefs)
                        await $_getPrefetchedData<
                          ManufacturerRow,
                          $ManufacturersTable,
                          BrassProductRow
                        >(
                          currentTable: table,
                          referencedTable: $$ManufacturersTableReferences
                              ._brassProductsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ManufacturersTableReferences(
                                db,
                                table,
                                p0,
                              ).brassProductsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.manufacturerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (firearmsRefRefs)
                        await $_getPrefetchedData<
                          ManufacturerRow,
                          $ManufacturersTable,
                          FirearmRefRow
                        >(
                          currentTable: table,
                          referencedTable: $$ManufacturersTableReferences
                              ._firearmsRefRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ManufacturersTableReferences(
                                db,
                                table,
                                p0,
                              ).firearmsRefRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.manufacturerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (firearmPartsRefs)
                        await $_getPrefetchedData<
                          ManufacturerRow,
                          $ManufacturersTable,
                          FirearmPartRow
                        >(
                          currentTable: table,
                          referencedTable: $$ManufacturersTableReferences
                              ._firearmPartsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ManufacturersTableReferences(
                                db,
                                table,
                                p0,
                              ).firearmPartsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.manufacturerId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ManufacturersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ManufacturersTable,
      ManufacturerRow,
      $$ManufacturersTableFilterComposer,
      $$ManufacturersTableOrderingComposer,
      $$ManufacturersTableAnnotationComposer,
      $$ManufacturersTableCreateCompanionBuilder,
      $$ManufacturersTableUpdateCompanionBuilder,
      (ManufacturerRow, $$ManufacturersTableReferences),
      ManufacturerRow,
      PrefetchHooks Function({
        bool powdersRefs,
        bool bulletsRefs,
        bool primersRefs,
        bool brassProductsRefs,
        bool firearmsRefRefs,
        bool firearmPartsRefs,
      })
    >;
typedef $$CartridgesTableCreateCompanionBuilder =
    CartridgesCompanion Function({
      Value<int> id,
      required String name,
      required String type,
      Value<double?> bulletDiameterIn,
      Value<double?> caseLengthIn,
      Value<double?> maxCoalIn,
      Value<double?> gauge,
      Value<double?> shellLengthIn,
      Value<String?> parentCase,
      Value<int?> yearIntroduced,
      Value<String> aliasesJson,
      Value<double?> bodyDiameterIn,
      Value<double?> shoulderDiameterIn,
      Value<double?> shoulderAngleDeg,
      Value<double?> neckDiameterIn,
      Value<double?> neckLengthIn,
      Value<double?> baseToShoulderIn,
      Value<double?> baseToNeckIn,
      Value<double?> rimDiameterIn,
      Value<double?> rimThicknessIn,
      Value<String?> primerType,
      Value<String?> twistRate,
      Value<int?> maxAvgPressurePsi,
      Value<double?> boreDiameterIn,
      Value<double?> grooveDiameterIn,
      Value<String?> caseSubtype,
      Value<String?> saamiDoc,
    });
typedef $$CartridgesTableUpdateCompanionBuilder =
    CartridgesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> type,
      Value<double?> bulletDiameterIn,
      Value<double?> caseLengthIn,
      Value<double?> maxCoalIn,
      Value<double?> gauge,
      Value<double?> shellLengthIn,
      Value<String?> parentCase,
      Value<int?> yearIntroduced,
      Value<String> aliasesJson,
      Value<double?> bodyDiameterIn,
      Value<double?> shoulderDiameterIn,
      Value<double?> shoulderAngleDeg,
      Value<double?> neckDiameterIn,
      Value<double?> neckLengthIn,
      Value<double?> baseToShoulderIn,
      Value<double?> baseToNeckIn,
      Value<double?> rimDiameterIn,
      Value<double?> rimThicknessIn,
      Value<String?> primerType,
      Value<String?> twistRate,
      Value<int?> maxAvgPressurePsi,
      Value<double?> boreDiameterIn,
      Value<double?> grooveDiameterIn,
      Value<String?> caseSubtype,
      Value<String?> saamiDoc,
    });

class $$CartridgesTableFilterComposer
    extends Composer<_$AppDatabase, $CartridgesTable> {
  $$CartridgesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bulletDiameterIn => $composableBuilder(
    column: $table.bulletDiameterIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get caseLengthIn => $composableBuilder(
    column: $table.caseLengthIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxCoalIn => $composableBuilder(
    column: $table.maxCoalIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gauge => $composableBuilder(
    column: $table.gauge,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get shellLengthIn => $composableBuilder(
    column: $table.shellLengthIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentCase => $composableBuilder(
    column: $table.parentCase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get yearIntroduced => $composableBuilder(
    column: $table.yearIntroduced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aliasesJson => $composableBuilder(
    column: $table.aliasesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bodyDiameterIn => $composableBuilder(
    column: $table.bodyDiameterIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get shoulderDiameterIn => $composableBuilder(
    column: $table.shoulderDiameterIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get shoulderAngleDeg => $composableBuilder(
    column: $table.shoulderAngleDeg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get neckDiameterIn => $composableBuilder(
    column: $table.neckDiameterIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get neckLengthIn => $composableBuilder(
    column: $table.neckLengthIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get baseToShoulderIn => $composableBuilder(
    column: $table.baseToShoulderIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get baseToNeckIn => $composableBuilder(
    column: $table.baseToNeckIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rimDiameterIn => $composableBuilder(
    column: $table.rimDiameterIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rimThicknessIn => $composableBuilder(
    column: $table.rimThicknessIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get primerType => $composableBuilder(
    column: $table.primerType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get twistRate => $composableBuilder(
    column: $table.twistRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxAvgPressurePsi => $composableBuilder(
    column: $table.maxAvgPressurePsi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get boreDiameterIn => $composableBuilder(
    column: $table.boreDiameterIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get grooveDiameterIn => $composableBuilder(
    column: $table.grooveDiameterIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caseSubtype => $composableBuilder(
    column: $table.caseSubtype,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get saamiDoc => $composableBuilder(
    column: $table.saamiDoc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CartridgesTableOrderingComposer
    extends Composer<_$AppDatabase, $CartridgesTable> {
  $$CartridgesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bulletDiameterIn => $composableBuilder(
    column: $table.bulletDiameterIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get caseLengthIn => $composableBuilder(
    column: $table.caseLengthIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxCoalIn => $composableBuilder(
    column: $table.maxCoalIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gauge => $composableBuilder(
    column: $table.gauge,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get shellLengthIn => $composableBuilder(
    column: $table.shellLengthIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentCase => $composableBuilder(
    column: $table.parentCase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get yearIntroduced => $composableBuilder(
    column: $table.yearIntroduced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aliasesJson => $composableBuilder(
    column: $table.aliasesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bodyDiameterIn => $composableBuilder(
    column: $table.bodyDiameterIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get shoulderDiameterIn => $composableBuilder(
    column: $table.shoulderDiameterIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get shoulderAngleDeg => $composableBuilder(
    column: $table.shoulderAngleDeg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get neckDiameterIn => $composableBuilder(
    column: $table.neckDiameterIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get neckLengthIn => $composableBuilder(
    column: $table.neckLengthIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get baseToShoulderIn => $composableBuilder(
    column: $table.baseToShoulderIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get baseToNeckIn => $composableBuilder(
    column: $table.baseToNeckIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rimDiameterIn => $composableBuilder(
    column: $table.rimDiameterIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rimThicknessIn => $composableBuilder(
    column: $table.rimThicknessIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get primerType => $composableBuilder(
    column: $table.primerType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get twistRate => $composableBuilder(
    column: $table.twistRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxAvgPressurePsi => $composableBuilder(
    column: $table.maxAvgPressurePsi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get boreDiameterIn => $composableBuilder(
    column: $table.boreDiameterIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get grooveDiameterIn => $composableBuilder(
    column: $table.grooveDiameterIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caseSubtype => $composableBuilder(
    column: $table.caseSubtype,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get saamiDoc => $composableBuilder(
    column: $table.saamiDoc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CartridgesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CartridgesTable> {
  $$CartridgesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get bulletDiameterIn => $composableBuilder(
    column: $table.bulletDiameterIn,
    builder: (column) => column,
  );

  GeneratedColumn<double> get caseLengthIn => $composableBuilder(
    column: $table.caseLengthIn,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maxCoalIn =>
      $composableBuilder(column: $table.maxCoalIn, builder: (column) => column);

  GeneratedColumn<double> get gauge =>
      $composableBuilder(column: $table.gauge, builder: (column) => column);

  GeneratedColumn<double> get shellLengthIn => $composableBuilder(
    column: $table.shellLengthIn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentCase => $composableBuilder(
    column: $table.parentCase,
    builder: (column) => column,
  );

  GeneratedColumn<int> get yearIntroduced => $composableBuilder(
    column: $table.yearIntroduced,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aliasesJson => $composableBuilder(
    column: $table.aliasesJson,
    builder: (column) => column,
  );

  GeneratedColumn<double> get bodyDiameterIn => $composableBuilder(
    column: $table.bodyDiameterIn,
    builder: (column) => column,
  );

  GeneratedColumn<double> get shoulderDiameterIn => $composableBuilder(
    column: $table.shoulderDiameterIn,
    builder: (column) => column,
  );

  GeneratedColumn<double> get shoulderAngleDeg => $composableBuilder(
    column: $table.shoulderAngleDeg,
    builder: (column) => column,
  );

  GeneratedColumn<double> get neckDiameterIn => $composableBuilder(
    column: $table.neckDiameterIn,
    builder: (column) => column,
  );

  GeneratedColumn<double> get neckLengthIn => $composableBuilder(
    column: $table.neckLengthIn,
    builder: (column) => column,
  );

  GeneratedColumn<double> get baseToShoulderIn => $composableBuilder(
    column: $table.baseToShoulderIn,
    builder: (column) => column,
  );

  GeneratedColumn<double> get baseToNeckIn => $composableBuilder(
    column: $table.baseToNeckIn,
    builder: (column) => column,
  );

  GeneratedColumn<double> get rimDiameterIn => $composableBuilder(
    column: $table.rimDiameterIn,
    builder: (column) => column,
  );

  GeneratedColumn<double> get rimThicknessIn => $composableBuilder(
    column: $table.rimThicknessIn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get primerType => $composableBuilder(
    column: $table.primerType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get twistRate =>
      $composableBuilder(column: $table.twistRate, builder: (column) => column);

  GeneratedColumn<int> get maxAvgPressurePsi => $composableBuilder(
    column: $table.maxAvgPressurePsi,
    builder: (column) => column,
  );

  GeneratedColumn<double> get boreDiameterIn => $composableBuilder(
    column: $table.boreDiameterIn,
    builder: (column) => column,
  );

  GeneratedColumn<double> get grooveDiameterIn => $composableBuilder(
    column: $table.grooveDiameterIn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get caseSubtype => $composableBuilder(
    column: $table.caseSubtype,
    builder: (column) => column,
  );

  GeneratedColumn<String> get saamiDoc =>
      $composableBuilder(column: $table.saamiDoc, builder: (column) => column);
}

class $$CartridgesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CartridgesTable,
          CartridgeRow,
          $$CartridgesTableFilterComposer,
          $$CartridgesTableOrderingComposer,
          $$CartridgesTableAnnotationComposer,
          $$CartridgesTableCreateCompanionBuilder,
          $$CartridgesTableUpdateCompanionBuilder,
          (
            CartridgeRow,
            BaseReferences<_$AppDatabase, $CartridgesTable, CartridgeRow>,
          ),
          CartridgeRow,
          PrefetchHooks Function()
        > {
  $$CartridgesTableTableManager(_$AppDatabase db, $CartridgesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CartridgesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CartridgesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CartridgesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<double?> bulletDiameterIn = const Value.absent(),
                Value<double?> caseLengthIn = const Value.absent(),
                Value<double?> maxCoalIn = const Value.absent(),
                Value<double?> gauge = const Value.absent(),
                Value<double?> shellLengthIn = const Value.absent(),
                Value<String?> parentCase = const Value.absent(),
                Value<int?> yearIntroduced = const Value.absent(),
                Value<String> aliasesJson = const Value.absent(),
                Value<double?> bodyDiameterIn = const Value.absent(),
                Value<double?> shoulderDiameterIn = const Value.absent(),
                Value<double?> shoulderAngleDeg = const Value.absent(),
                Value<double?> neckDiameterIn = const Value.absent(),
                Value<double?> neckLengthIn = const Value.absent(),
                Value<double?> baseToShoulderIn = const Value.absent(),
                Value<double?> baseToNeckIn = const Value.absent(),
                Value<double?> rimDiameterIn = const Value.absent(),
                Value<double?> rimThicknessIn = const Value.absent(),
                Value<String?> primerType = const Value.absent(),
                Value<String?> twistRate = const Value.absent(),
                Value<int?> maxAvgPressurePsi = const Value.absent(),
                Value<double?> boreDiameterIn = const Value.absent(),
                Value<double?> grooveDiameterIn = const Value.absent(),
                Value<String?> caseSubtype = const Value.absent(),
                Value<String?> saamiDoc = const Value.absent(),
              }) => CartridgesCompanion(
                id: id,
                name: name,
                type: type,
                bulletDiameterIn: bulletDiameterIn,
                caseLengthIn: caseLengthIn,
                maxCoalIn: maxCoalIn,
                gauge: gauge,
                shellLengthIn: shellLengthIn,
                parentCase: parentCase,
                yearIntroduced: yearIntroduced,
                aliasesJson: aliasesJson,
                bodyDiameterIn: bodyDiameterIn,
                shoulderDiameterIn: shoulderDiameterIn,
                shoulderAngleDeg: shoulderAngleDeg,
                neckDiameterIn: neckDiameterIn,
                neckLengthIn: neckLengthIn,
                baseToShoulderIn: baseToShoulderIn,
                baseToNeckIn: baseToNeckIn,
                rimDiameterIn: rimDiameterIn,
                rimThicknessIn: rimThicknessIn,
                primerType: primerType,
                twistRate: twistRate,
                maxAvgPressurePsi: maxAvgPressurePsi,
                boreDiameterIn: boreDiameterIn,
                grooveDiameterIn: grooveDiameterIn,
                caseSubtype: caseSubtype,
                saamiDoc: saamiDoc,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String type,
                Value<double?> bulletDiameterIn = const Value.absent(),
                Value<double?> caseLengthIn = const Value.absent(),
                Value<double?> maxCoalIn = const Value.absent(),
                Value<double?> gauge = const Value.absent(),
                Value<double?> shellLengthIn = const Value.absent(),
                Value<String?> parentCase = const Value.absent(),
                Value<int?> yearIntroduced = const Value.absent(),
                Value<String> aliasesJson = const Value.absent(),
                Value<double?> bodyDiameterIn = const Value.absent(),
                Value<double?> shoulderDiameterIn = const Value.absent(),
                Value<double?> shoulderAngleDeg = const Value.absent(),
                Value<double?> neckDiameterIn = const Value.absent(),
                Value<double?> neckLengthIn = const Value.absent(),
                Value<double?> baseToShoulderIn = const Value.absent(),
                Value<double?> baseToNeckIn = const Value.absent(),
                Value<double?> rimDiameterIn = const Value.absent(),
                Value<double?> rimThicknessIn = const Value.absent(),
                Value<String?> primerType = const Value.absent(),
                Value<String?> twistRate = const Value.absent(),
                Value<int?> maxAvgPressurePsi = const Value.absent(),
                Value<double?> boreDiameterIn = const Value.absent(),
                Value<double?> grooveDiameterIn = const Value.absent(),
                Value<String?> caseSubtype = const Value.absent(),
                Value<String?> saamiDoc = const Value.absent(),
              }) => CartridgesCompanion.insert(
                id: id,
                name: name,
                type: type,
                bulletDiameterIn: bulletDiameterIn,
                caseLengthIn: caseLengthIn,
                maxCoalIn: maxCoalIn,
                gauge: gauge,
                shellLengthIn: shellLengthIn,
                parentCase: parentCase,
                yearIntroduced: yearIntroduced,
                aliasesJson: aliasesJson,
                bodyDiameterIn: bodyDiameterIn,
                shoulderDiameterIn: shoulderDiameterIn,
                shoulderAngleDeg: shoulderAngleDeg,
                neckDiameterIn: neckDiameterIn,
                neckLengthIn: neckLengthIn,
                baseToShoulderIn: baseToShoulderIn,
                baseToNeckIn: baseToNeckIn,
                rimDiameterIn: rimDiameterIn,
                rimThicknessIn: rimThicknessIn,
                primerType: primerType,
                twistRate: twistRate,
                maxAvgPressurePsi: maxAvgPressurePsi,
                boreDiameterIn: boreDiameterIn,
                grooveDiameterIn: grooveDiameterIn,
                caseSubtype: caseSubtype,
                saamiDoc: saamiDoc,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CartridgesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CartridgesTable,
      CartridgeRow,
      $$CartridgesTableFilterComposer,
      $$CartridgesTableOrderingComposer,
      $$CartridgesTableAnnotationComposer,
      $$CartridgesTableCreateCompanionBuilder,
      $$CartridgesTableUpdateCompanionBuilder,
      (
        CartridgeRow,
        BaseReferences<_$AppDatabase, $CartridgesTable, CartridgeRow>,
      ),
      CartridgeRow,
      PrefetchHooks Function()
    >;
typedef $$PowdersTableCreateCompanionBuilder =
    PowdersCompanion Function({
      Value<int> id,
      required int manufacturerId,
      required String name,
      required String type,
      Value<String?> form,
      Value<String?> burnRate,
      Value<String?> notes,
    });
typedef $$PowdersTableUpdateCompanionBuilder =
    PowdersCompanion Function({
      Value<int> id,
      Value<int> manufacturerId,
      Value<String> name,
      Value<String> type,
      Value<String?> form,
      Value<String?> burnRate,
      Value<String?> notes,
    });

final class $$PowdersTableReferences
    extends BaseReferences<_$AppDatabase, $PowdersTable, PowderRow> {
  $$PowdersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ManufacturersTable _manufacturerIdTable(_$AppDatabase db) =>
      db.manufacturers.createAlias(
        $_aliasNameGenerator(db.powders.manufacturerId, db.manufacturers.id),
      );

  $$ManufacturersTableProcessedTableManager get manufacturerId {
    final $_column = $_itemColumn<int>('manufacturer_id')!;

    final manager = $$ManufacturersTableTableManager(
      $_db,
      $_db.manufacturers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_manufacturerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PowdersTableFilterComposer
    extends Composer<_$AppDatabase, $PowdersTable> {
  $$PowdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get form => $composableBuilder(
    column: $table.form,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get burnRate => $composableBuilder(
    column: $table.burnRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$ManufacturersTableFilterComposer get manufacturerId {
    final $$ManufacturersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.manufacturerId,
      referencedTable: $db.manufacturers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ManufacturersTableFilterComposer(
            $db: $db,
            $table: $db.manufacturers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PowdersTableOrderingComposer
    extends Composer<_$AppDatabase, $PowdersTable> {
  $$PowdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get form => $composableBuilder(
    column: $table.form,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get burnRate => $composableBuilder(
    column: $table.burnRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$ManufacturersTableOrderingComposer get manufacturerId {
    final $$ManufacturersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.manufacturerId,
      referencedTable: $db.manufacturers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ManufacturersTableOrderingComposer(
            $db: $db,
            $table: $db.manufacturers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PowdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PowdersTable> {
  $$PowdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get form =>
      $composableBuilder(column: $table.form, builder: (column) => column);

  GeneratedColumn<String> get burnRate =>
      $composableBuilder(column: $table.burnRate, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$ManufacturersTableAnnotationComposer get manufacturerId {
    final $$ManufacturersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.manufacturerId,
      referencedTable: $db.manufacturers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ManufacturersTableAnnotationComposer(
            $db: $db,
            $table: $db.manufacturers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PowdersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PowdersTable,
          PowderRow,
          $$PowdersTableFilterComposer,
          $$PowdersTableOrderingComposer,
          $$PowdersTableAnnotationComposer,
          $$PowdersTableCreateCompanionBuilder,
          $$PowdersTableUpdateCompanionBuilder,
          (PowderRow, $$PowdersTableReferences),
          PowderRow,
          PrefetchHooks Function({bool manufacturerId})
        > {
  $$PowdersTableTableManager(_$AppDatabase db, $PowdersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PowdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PowdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PowdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> manufacturerId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> form = const Value.absent(),
                Value<String?> burnRate = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => PowdersCompanion(
                id: id,
                manufacturerId: manufacturerId,
                name: name,
                type: type,
                form: form,
                burnRate: burnRate,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int manufacturerId,
                required String name,
                required String type,
                Value<String?> form = const Value.absent(),
                Value<String?> burnRate = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => PowdersCompanion.insert(
                id: id,
                manufacturerId: manufacturerId,
                name: name,
                type: type,
                form: form,
                burnRate: burnRate,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PowdersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({manufacturerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (manufacturerId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.manufacturerId,
                                referencedTable: $$PowdersTableReferences
                                    ._manufacturerIdTable(db),
                                referencedColumn: $$PowdersTableReferences
                                    ._manufacturerIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PowdersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PowdersTable,
      PowderRow,
      $$PowdersTableFilterComposer,
      $$PowdersTableOrderingComposer,
      $$PowdersTableAnnotationComposer,
      $$PowdersTableCreateCompanionBuilder,
      $$PowdersTableUpdateCompanionBuilder,
      (PowderRow, $$PowdersTableReferences),
      PowderRow,
      PrefetchHooks Function({bool manufacturerId})
    >;
typedef $$BulletsTableCreateCompanionBuilder =
    BulletsCompanion Function({
      Value<int> id,
      required int manufacturerId,
      required String line,
      required double diameterIn,
      required double weightGr,
      Value<String?> design,
      Value<String?> jacket,
      Value<String?> application,
      Value<double?> bcG1,
      Value<double?> bcG7,
      Value<String?> notes,
    });
typedef $$BulletsTableUpdateCompanionBuilder =
    BulletsCompanion Function({
      Value<int> id,
      Value<int> manufacturerId,
      Value<String> line,
      Value<double> diameterIn,
      Value<double> weightGr,
      Value<String?> design,
      Value<String?> jacket,
      Value<String?> application,
      Value<double?> bcG1,
      Value<double?> bcG7,
      Value<String?> notes,
    });

final class $$BulletsTableReferences
    extends BaseReferences<_$AppDatabase, $BulletsTable, BulletRow> {
  $$BulletsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ManufacturersTable _manufacturerIdTable(_$AppDatabase db) =>
      db.manufacturers.createAlias(
        $_aliasNameGenerator(db.bullets.manufacturerId, db.manufacturers.id),
      );

  $$ManufacturersTableProcessedTableManager get manufacturerId {
    final $_column = $_itemColumn<int>('manufacturer_id')!;

    final manager = $$ManufacturersTableTableManager(
      $_db,
      $_db.manufacturers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_manufacturerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BulletsTableFilterComposer
    extends Composer<_$AppDatabase, $BulletsTable> {
  $$BulletsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get line => $composableBuilder(
    column: $table.line,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get diameterIn => $composableBuilder(
    column: $table.diameterIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightGr => $composableBuilder(
    column: $table.weightGr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get design => $composableBuilder(
    column: $table.design,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jacket => $composableBuilder(
    column: $table.jacket,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get application => $composableBuilder(
    column: $table.application,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bcG1 => $composableBuilder(
    column: $table.bcG1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bcG7 => $composableBuilder(
    column: $table.bcG7,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$ManufacturersTableFilterComposer get manufacturerId {
    final $$ManufacturersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.manufacturerId,
      referencedTable: $db.manufacturers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ManufacturersTableFilterComposer(
            $db: $db,
            $table: $db.manufacturers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BulletsTableOrderingComposer
    extends Composer<_$AppDatabase, $BulletsTable> {
  $$BulletsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get line => $composableBuilder(
    column: $table.line,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get diameterIn => $composableBuilder(
    column: $table.diameterIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightGr => $composableBuilder(
    column: $table.weightGr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get design => $composableBuilder(
    column: $table.design,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jacket => $composableBuilder(
    column: $table.jacket,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get application => $composableBuilder(
    column: $table.application,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bcG1 => $composableBuilder(
    column: $table.bcG1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bcG7 => $composableBuilder(
    column: $table.bcG7,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$ManufacturersTableOrderingComposer get manufacturerId {
    final $$ManufacturersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.manufacturerId,
      referencedTable: $db.manufacturers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ManufacturersTableOrderingComposer(
            $db: $db,
            $table: $db.manufacturers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BulletsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BulletsTable> {
  $$BulletsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get line =>
      $composableBuilder(column: $table.line, builder: (column) => column);

  GeneratedColumn<double> get diameterIn => $composableBuilder(
    column: $table.diameterIn,
    builder: (column) => column,
  );

  GeneratedColumn<double> get weightGr =>
      $composableBuilder(column: $table.weightGr, builder: (column) => column);

  GeneratedColumn<String> get design =>
      $composableBuilder(column: $table.design, builder: (column) => column);

  GeneratedColumn<String> get jacket =>
      $composableBuilder(column: $table.jacket, builder: (column) => column);

  GeneratedColumn<String> get application => $composableBuilder(
    column: $table.application,
    builder: (column) => column,
  );

  GeneratedColumn<double> get bcG1 =>
      $composableBuilder(column: $table.bcG1, builder: (column) => column);

  GeneratedColumn<double> get bcG7 =>
      $composableBuilder(column: $table.bcG7, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$ManufacturersTableAnnotationComposer get manufacturerId {
    final $$ManufacturersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.manufacturerId,
      referencedTable: $db.manufacturers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ManufacturersTableAnnotationComposer(
            $db: $db,
            $table: $db.manufacturers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BulletsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BulletsTable,
          BulletRow,
          $$BulletsTableFilterComposer,
          $$BulletsTableOrderingComposer,
          $$BulletsTableAnnotationComposer,
          $$BulletsTableCreateCompanionBuilder,
          $$BulletsTableUpdateCompanionBuilder,
          (BulletRow, $$BulletsTableReferences),
          BulletRow,
          PrefetchHooks Function({bool manufacturerId})
        > {
  $$BulletsTableTableManager(_$AppDatabase db, $BulletsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BulletsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BulletsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BulletsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> manufacturerId = const Value.absent(),
                Value<String> line = const Value.absent(),
                Value<double> diameterIn = const Value.absent(),
                Value<double> weightGr = const Value.absent(),
                Value<String?> design = const Value.absent(),
                Value<String?> jacket = const Value.absent(),
                Value<String?> application = const Value.absent(),
                Value<double?> bcG1 = const Value.absent(),
                Value<double?> bcG7 = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => BulletsCompanion(
                id: id,
                manufacturerId: manufacturerId,
                line: line,
                diameterIn: diameterIn,
                weightGr: weightGr,
                design: design,
                jacket: jacket,
                application: application,
                bcG1: bcG1,
                bcG7: bcG7,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int manufacturerId,
                required String line,
                required double diameterIn,
                required double weightGr,
                Value<String?> design = const Value.absent(),
                Value<String?> jacket = const Value.absent(),
                Value<String?> application = const Value.absent(),
                Value<double?> bcG1 = const Value.absent(),
                Value<double?> bcG7 = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => BulletsCompanion.insert(
                id: id,
                manufacturerId: manufacturerId,
                line: line,
                diameterIn: diameterIn,
                weightGr: weightGr,
                design: design,
                jacket: jacket,
                application: application,
                bcG1: bcG1,
                bcG7: bcG7,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BulletsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({manufacturerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (manufacturerId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.manufacturerId,
                                referencedTable: $$BulletsTableReferences
                                    ._manufacturerIdTable(db),
                                referencedColumn: $$BulletsTableReferences
                                    ._manufacturerIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BulletsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BulletsTable,
      BulletRow,
      $$BulletsTableFilterComposer,
      $$BulletsTableOrderingComposer,
      $$BulletsTableAnnotationComposer,
      $$BulletsTableCreateCompanionBuilder,
      $$BulletsTableUpdateCompanionBuilder,
      (BulletRow, $$BulletsTableReferences),
      BulletRow,
      PrefetchHooks Function({bool manufacturerId})
    >;
typedef $$PrimersTableCreateCompanionBuilder =
    PrimersCompanion Function({
      Value<int> id,
      required int manufacturerId,
      required String name,
      required String size,
      Value<bool> magnum,
      Value<String?> grade,
      Value<String?> productLine,
      Value<String?> notes,
    });
typedef $$PrimersTableUpdateCompanionBuilder =
    PrimersCompanion Function({
      Value<int> id,
      Value<int> manufacturerId,
      Value<String> name,
      Value<String> size,
      Value<bool> magnum,
      Value<String?> grade,
      Value<String?> productLine,
      Value<String?> notes,
    });

final class $$PrimersTableReferences
    extends BaseReferences<_$AppDatabase, $PrimersTable, PrimerRow> {
  $$PrimersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ManufacturersTable _manufacturerIdTable(_$AppDatabase db) =>
      db.manufacturers.createAlias(
        $_aliasNameGenerator(db.primers.manufacturerId, db.manufacturers.id),
      );

  $$ManufacturersTableProcessedTableManager get manufacturerId {
    final $_column = $_itemColumn<int>('manufacturer_id')!;

    final manager = $$ManufacturersTableTableManager(
      $_db,
      $_db.manufacturers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_manufacturerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PrimersTableFilterComposer
    extends Composer<_$AppDatabase, $PrimersTable> {
  $$PrimersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get magnum => $composableBuilder(
    column: $table.magnum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get grade => $composableBuilder(
    column: $table.grade,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productLine => $composableBuilder(
    column: $table.productLine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$ManufacturersTableFilterComposer get manufacturerId {
    final $$ManufacturersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.manufacturerId,
      referencedTable: $db.manufacturers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ManufacturersTableFilterComposer(
            $db: $db,
            $table: $db.manufacturers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PrimersTableOrderingComposer
    extends Composer<_$AppDatabase, $PrimersTable> {
  $$PrimersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get magnum => $composableBuilder(
    column: $table.magnum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get grade => $composableBuilder(
    column: $table.grade,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productLine => $composableBuilder(
    column: $table.productLine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$ManufacturersTableOrderingComposer get manufacturerId {
    final $$ManufacturersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.manufacturerId,
      referencedTable: $db.manufacturers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ManufacturersTableOrderingComposer(
            $db: $db,
            $table: $db.manufacturers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PrimersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PrimersTable> {
  $$PrimersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<bool> get magnum =>
      $composableBuilder(column: $table.magnum, builder: (column) => column);

  GeneratedColumn<String> get grade =>
      $composableBuilder(column: $table.grade, builder: (column) => column);

  GeneratedColumn<String> get productLine => $composableBuilder(
    column: $table.productLine,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$ManufacturersTableAnnotationComposer get manufacturerId {
    final $$ManufacturersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.manufacturerId,
      referencedTable: $db.manufacturers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ManufacturersTableAnnotationComposer(
            $db: $db,
            $table: $db.manufacturers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PrimersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PrimersTable,
          PrimerRow,
          $$PrimersTableFilterComposer,
          $$PrimersTableOrderingComposer,
          $$PrimersTableAnnotationComposer,
          $$PrimersTableCreateCompanionBuilder,
          $$PrimersTableUpdateCompanionBuilder,
          (PrimerRow, $$PrimersTableReferences),
          PrimerRow,
          PrefetchHooks Function({bool manufacturerId})
        > {
  $$PrimersTableTableManager(_$AppDatabase db, $PrimersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrimersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrimersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PrimersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> manufacturerId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> size = const Value.absent(),
                Value<bool> magnum = const Value.absent(),
                Value<String?> grade = const Value.absent(),
                Value<String?> productLine = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => PrimersCompanion(
                id: id,
                manufacturerId: manufacturerId,
                name: name,
                size: size,
                magnum: magnum,
                grade: grade,
                productLine: productLine,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int manufacturerId,
                required String name,
                required String size,
                Value<bool> magnum = const Value.absent(),
                Value<String?> grade = const Value.absent(),
                Value<String?> productLine = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => PrimersCompanion.insert(
                id: id,
                manufacturerId: manufacturerId,
                name: name,
                size: size,
                magnum: magnum,
                grade: grade,
                productLine: productLine,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PrimersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({manufacturerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (manufacturerId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.manufacturerId,
                                referencedTable: $$PrimersTableReferences
                                    ._manufacturerIdTable(db),
                                referencedColumn: $$PrimersTableReferences
                                    ._manufacturerIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PrimersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PrimersTable,
      PrimerRow,
      $$PrimersTableFilterComposer,
      $$PrimersTableOrderingComposer,
      $$PrimersTableAnnotationComposer,
      $$PrimersTableCreateCompanionBuilder,
      $$PrimersTableUpdateCompanionBuilder,
      (PrimerRow, $$PrimersTableReferences),
      PrimerRow,
      PrefetchHooks Function({bool manufacturerId})
    >;
typedef $$BrassProductsTableCreateCompanionBuilder =
    BrassProductsCompanion Function({
      Value<int> id,
      required int manufacturerId,
      Value<String?> tier,
      Value<String> calibersJson,
      Value<String?> notes,
    });
typedef $$BrassProductsTableUpdateCompanionBuilder =
    BrassProductsCompanion Function({
      Value<int> id,
      Value<int> manufacturerId,
      Value<String?> tier,
      Value<String> calibersJson,
      Value<String?> notes,
    });

final class $$BrassProductsTableReferences
    extends
        BaseReferences<_$AppDatabase, $BrassProductsTable, BrassProductRow> {
  $$BrassProductsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ManufacturersTable _manufacturerIdTable(_$AppDatabase db) =>
      db.manufacturers.createAlias(
        $_aliasNameGenerator(
          db.brassProducts.manufacturerId,
          db.manufacturers.id,
        ),
      );

  $$ManufacturersTableProcessedTableManager get manufacturerId {
    final $_column = $_itemColumn<int>('manufacturer_id')!;

    final manager = $$ManufacturersTableTableManager(
      $_db,
      $_db.manufacturers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_manufacturerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BrassProductsTableFilterComposer
    extends Composer<_$AppDatabase, $BrassProductsTable> {
  $$BrassProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get calibersJson => $composableBuilder(
    column: $table.calibersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$ManufacturersTableFilterComposer get manufacturerId {
    final $$ManufacturersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.manufacturerId,
      referencedTable: $db.manufacturers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ManufacturersTableFilterComposer(
            $db: $db,
            $table: $db.manufacturers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BrassProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $BrassProductsTable> {
  $$BrassProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get calibersJson => $composableBuilder(
    column: $table.calibersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$ManufacturersTableOrderingComposer get manufacturerId {
    final $$ManufacturersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.manufacturerId,
      referencedTable: $db.manufacturers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ManufacturersTableOrderingComposer(
            $db: $db,
            $table: $db.manufacturers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BrassProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BrassProductsTable> {
  $$BrassProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tier =>
      $composableBuilder(column: $table.tier, builder: (column) => column);

  GeneratedColumn<String> get calibersJson => $composableBuilder(
    column: $table.calibersJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$ManufacturersTableAnnotationComposer get manufacturerId {
    final $$ManufacturersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.manufacturerId,
      referencedTable: $db.manufacturers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ManufacturersTableAnnotationComposer(
            $db: $db,
            $table: $db.manufacturers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BrassProductsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BrassProductsTable,
          BrassProductRow,
          $$BrassProductsTableFilterComposer,
          $$BrassProductsTableOrderingComposer,
          $$BrassProductsTableAnnotationComposer,
          $$BrassProductsTableCreateCompanionBuilder,
          $$BrassProductsTableUpdateCompanionBuilder,
          (BrassProductRow, $$BrassProductsTableReferences),
          BrassProductRow,
          PrefetchHooks Function({bool manufacturerId})
        > {
  $$BrassProductsTableTableManager(_$AppDatabase db, $BrassProductsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BrassProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BrassProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BrassProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> manufacturerId = const Value.absent(),
                Value<String?> tier = const Value.absent(),
                Value<String> calibersJson = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => BrassProductsCompanion(
                id: id,
                manufacturerId: manufacturerId,
                tier: tier,
                calibersJson: calibersJson,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int manufacturerId,
                Value<String?> tier = const Value.absent(),
                Value<String> calibersJson = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => BrassProductsCompanion.insert(
                id: id,
                manufacturerId: manufacturerId,
                tier: tier,
                calibersJson: calibersJson,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BrassProductsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({manufacturerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (manufacturerId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.manufacturerId,
                                referencedTable: $$BrassProductsTableReferences
                                    ._manufacturerIdTable(db),
                                referencedColumn: $$BrassProductsTableReferences
                                    ._manufacturerIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BrassProductsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BrassProductsTable,
      BrassProductRow,
      $$BrassProductsTableFilterComposer,
      $$BrassProductsTableOrderingComposer,
      $$BrassProductsTableAnnotationComposer,
      $$BrassProductsTableCreateCompanionBuilder,
      $$BrassProductsTableUpdateCompanionBuilder,
      (BrassProductRow, $$BrassProductsTableReferences),
      BrassProductRow,
      PrefetchHooks Function({bool manufacturerId})
    >;
typedef $$FirearmsRefTableCreateCompanionBuilder =
    FirearmsRefCompanion Function({
      Value<int> id,
      required int manufacturerId,
      required String model,
      required String type,
      Value<String?> action,
      Value<String> calibersJson,
      Value<String?> notes,
    });
typedef $$FirearmsRefTableUpdateCompanionBuilder =
    FirearmsRefCompanion Function({
      Value<int> id,
      Value<int> manufacturerId,
      Value<String> model,
      Value<String> type,
      Value<String?> action,
      Value<String> calibersJson,
      Value<String?> notes,
    });

final class $$FirearmsRefTableReferences
    extends BaseReferences<_$AppDatabase, $FirearmsRefTable, FirearmRefRow> {
  $$FirearmsRefTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ManufacturersTable _manufacturerIdTable(_$AppDatabase db) =>
      db.manufacturers.createAlias(
        $_aliasNameGenerator(
          db.firearmsRef.manufacturerId,
          db.manufacturers.id,
        ),
      );

  $$ManufacturersTableProcessedTableManager get manufacturerId {
    final $_column = $_itemColumn<int>('manufacturer_id')!;

    final manager = $$ManufacturersTableTableManager(
      $_db,
      $_db.manufacturers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_manufacturerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FirearmsRefTableFilterComposer
    extends Composer<_$AppDatabase, $FirearmsRefTable> {
  $$FirearmsRefTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get calibersJson => $composableBuilder(
    column: $table.calibersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$ManufacturersTableFilterComposer get manufacturerId {
    final $$ManufacturersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.manufacturerId,
      referencedTable: $db.manufacturers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ManufacturersTableFilterComposer(
            $db: $db,
            $table: $db.manufacturers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FirearmsRefTableOrderingComposer
    extends Composer<_$AppDatabase, $FirearmsRefTable> {
  $$FirearmsRefTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get calibersJson => $composableBuilder(
    column: $table.calibersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$ManufacturersTableOrderingComposer get manufacturerId {
    final $$ManufacturersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.manufacturerId,
      referencedTable: $db.manufacturers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ManufacturersTableOrderingComposer(
            $db: $db,
            $table: $db.manufacturers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FirearmsRefTableAnnotationComposer
    extends Composer<_$AppDatabase, $FirearmsRefTable> {
  $$FirearmsRefTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get calibersJson => $composableBuilder(
    column: $table.calibersJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$ManufacturersTableAnnotationComposer get manufacturerId {
    final $$ManufacturersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.manufacturerId,
      referencedTable: $db.manufacturers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ManufacturersTableAnnotationComposer(
            $db: $db,
            $table: $db.manufacturers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FirearmsRefTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FirearmsRefTable,
          FirearmRefRow,
          $$FirearmsRefTableFilterComposer,
          $$FirearmsRefTableOrderingComposer,
          $$FirearmsRefTableAnnotationComposer,
          $$FirearmsRefTableCreateCompanionBuilder,
          $$FirearmsRefTableUpdateCompanionBuilder,
          (FirearmRefRow, $$FirearmsRefTableReferences),
          FirearmRefRow,
          PrefetchHooks Function({bool manufacturerId})
        > {
  $$FirearmsRefTableTableManager(_$AppDatabase db, $FirearmsRefTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FirearmsRefTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FirearmsRefTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FirearmsRefTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> manufacturerId = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> action = const Value.absent(),
                Value<String> calibersJson = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => FirearmsRefCompanion(
                id: id,
                manufacturerId: manufacturerId,
                model: model,
                type: type,
                action: action,
                calibersJson: calibersJson,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int manufacturerId,
                required String model,
                required String type,
                Value<String?> action = const Value.absent(),
                Value<String> calibersJson = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => FirearmsRefCompanion.insert(
                id: id,
                manufacturerId: manufacturerId,
                model: model,
                type: type,
                action: action,
                calibersJson: calibersJson,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FirearmsRefTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({manufacturerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (manufacturerId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.manufacturerId,
                                referencedTable: $$FirearmsRefTableReferences
                                    ._manufacturerIdTable(db),
                                referencedColumn: $$FirearmsRefTableReferences
                                    ._manufacturerIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FirearmsRefTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FirearmsRefTable,
      FirearmRefRow,
      $$FirearmsRefTableFilterComposer,
      $$FirearmsRefTableOrderingComposer,
      $$FirearmsRefTableAnnotationComposer,
      $$FirearmsRefTableCreateCompanionBuilder,
      $$FirearmsRefTableUpdateCompanionBuilder,
      (FirearmRefRow, $$FirearmsRefTableReferences),
      FirearmRefRow,
      PrefetchHooks Function({bool manufacturerId})
    >;
typedef $$FirearmPartsTableCreateCompanionBuilder =
    FirearmPartsCompanion Function({
      Value<int> id,
      required int manufacturerId,
      required String name,
      required String category,
      Value<String> compatibleWithJson,
      Value<String?> notes,
    });
typedef $$FirearmPartsTableUpdateCompanionBuilder =
    FirearmPartsCompanion Function({
      Value<int> id,
      Value<int> manufacturerId,
      Value<String> name,
      Value<String> category,
      Value<String> compatibleWithJson,
      Value<String?> notes,
    });

final class $$FirearmPartsTableReferences
    extends BaseReferences<_$AppDatabase, $FirearmPartsTable, FirearmPartRow> {
  $$FirearmPartsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ManufacturersTable _manufacturerIdTable(_$AppDatabase db) =>
      db.manufacturers.createAlias(
        $_aliasNameGenerator(
          db.firearmParts.manufacturerId,
          db.manufacturers.id,
        ),
      );

  $$ManufacturersTableProcessedTableManager get manufacturerId {
    final $_column = $_itemColumn<int>('manufacturer_id')!;

    final manager = $$ManufacturersTableTableManager(
      $_db,
      $_db.manufacturers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_manufacturerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FirearmPartsTableFilterComposer
    extends Composer<_$AppDatabase, $FirearmPartsTable> {
  $$FirearmPartsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get compatibleWithJson => $composableBuilder(
    column: $table.compatibleWithJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$ManufacturersTableFilterComposer get manufacturerId {
    final $$ManufacturersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.manufacturerId,
      referencedTable: $db.manufacturers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ManufacturersTableFilterComposer(
            $db: $db,
            $table: $db.manufacturers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FirearmPartsTableOrderingComposer
    extends Composer<_$AppDatabase, $FirearmPartsTable> {
  $$FirearmPartsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get compatibleWithJson => $composableBuilder(
    column: $table.compatibleWithJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$ManufacturersTableOrderingComposer get manufacturerId {
    final $$ManufacturersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.manufacturerId,
      referencedTable: $db.manufacturers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ManufacturersTableOrderingComposer(
            $db: $db,
            $table: $db.manufacturers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FirearmPartsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FirearmPartsTable> {
  $$FirearmPartsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get compatibleWithJson => $composableBuilder(
    column: $table.compatibleWithJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$ManufacturersTableAnnotationComposer get manufacturerId {
    final $$ManufacturersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.manufacturerId,
      referencedTable: $db.manufacturers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ManufacturersTableAnnotationComposer(
            $db: $db,
            $table: $db.manufacturers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FirearmPartsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FirearmPartsTable,
          FirearmPartRow,
          $$FirearmPartsTableFilterComposer,
          $$FirearmPartsTableOrderingComposer,
          $$FirearmPartsTableAnnotationComposer,
          $$FirearmPartsTableCreateCompanionBuilder,
          $$FirearmPartsTableUpdateCompanionBuilder,
          (FirearmPartRow, $$FirearmPartsTableReferences),
          FirearmPartRow,
          PrefetchHooks Function({bool manufacturerId})
        > {
  $$FirearmPartsTableTableManager(_$AppDatabase db, $FirearmPartsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FirearmPartsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FirearmPartsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FirearmPartsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> manufacturerId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> compatibleWithJson = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => FirearmPartsCompanion(
                id: id,
                manufacturerId: manufacturerId,
                name: name,
                category: category,
                compatibleWithJson: compatibleWithJson,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int manufacturerId,
                required String name,
                required String category,
                Value<String> compatibleWithJson = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => FirearmPartsCompanion.insert(
                id: id,
                manufacturerId: manufacturerId,
                name: name,
                category: category,
                compatibleWithJson: compatibleWithJson,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FirearmPartsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({manufacturerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (manufacturerId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.manufacturerId,
                                referencedTable: $$FirearmPartsTableReferences
                                    ._manufacturerIdTable(db),
                                referencedColumn: $$FirearmPartsTableReferences
                                    ._manufacturerIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FirearmPartsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FirearmPartsTable,
      FirearmPartRow,
      $$FirearmPartsTableFilterComposer,
      $$FirearmPartsTableOrderingComposer,
      $$FirearmPartsTableAnnotationComposer,
      $$FirearmPartsTableCreateCompanionBuilder,
      $$FirearmPartsTableUpdateCompanionBuilder,
      (FirearmPartRow, $$FirearmPartsTableReferences),
      FirearmPartRow,
      PrefetchHooks Function({bool manufacturerId})
    >;
typedef $$CustomComponentsTableCreateCompanionBuilder =
    CustomComponentsCompanion Function({
      Value<int> id,
      required String kind,
      required String name,
      Value<String?> notes,
      Value<DateTime> createdAt,
    });
typedef $$CustomComponentsTableUpdateCompanionBuilder =
    CustomComponentsCompanion Function({
      Value<int> id,
      Value<String> kind,
      Value<String> name,
      Value<String?> notes,
      Value<DateTime> createdAt,
    });

class $$CustomComponentsTableFilterComposer
    extends Composer<_$AppDatabase, $CustomComponentsTable> {
  $$CustomComponentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CustomComponentsTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomComponentsTable> {
  $$CustomComponentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomComponentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomComponentsTable> {
  $$CustomComponentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CustomComponentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomComponentsTable,
          CustomComponentRow,
          $$CustomComponentsTableFilterComposer,
          $$CustomComponentsTableOrderingComposer,
          $$CustomComponentsTableAnnotationComposer,
          $$CustomComponentsTableCreateCompanionBuilder,
          $$CustomComponentsTableUpdateCompanionBuilder,
          (
            CustomComponentRow,
            BaseReferences<
              _$AppDatabase,
              $CustomComponentsTable,
              CustomComponentRow
            >,
          ),
          CustomComponentRow,
          PrefetchHooks Function()
        > {
  $$CustomComponentsTableTableManager(
    _$AppDatabase db,
    $CustomComponentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomComponentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomComponentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomComponentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CustomComponentsCompanion(
                id: id,
                kind: kind,
                name: name,
                notes: notes,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String kind,
                required String name,
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CustomComponentsCompanion.insert(
                id: id,
                kind: kind,
                name: name,
                notes: notes,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomComponentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomComponentsTable,
      CustomComponentRow,
      $$CustomComponentsTableFilterComposer,
      $$CustomComponentsTableOrderingComposer,
      $$CustomComponentsTableAnnotationComposer,
      $$CustomComponentsTableCreateCompanionBuilder,
      $$CustomComponentsTableUpdateCompanionBuilder,
      (
        CustomComponentRow,
        BaseReferences<
          _$AppDatabase,
          $CustomComponentsTable,
          CustomComponentRow
        >,
      ),
      CustomComponentRow,
      PrefetchHooks Function()
    >;
typedef $$UserLoadsTableCreateCompanionBuilder =
    UserLoadsCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> caliber,
      Value<String?> powder,
      Value<double?> powderChargeGr,
      Value<String?> bullet,
      Value<double?> bulletWeightGr,
      Value<String?> primer,
      Value<String?> brass,
      Value<double?> coalIn,
      Value<double?> cbtoIn,
      Value<double?> seatingDepthIn,
      Value<double?> primerDepthCps,
      Value<double?> shoulderBumpIn,
      Value<double?> mandrelSizeIn,
      Value<DateTime?> dateEstablished,
      Value<String?> notes,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$UserLoadsTableUpdateCompanionBuilder =
    UserLoadsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> caliber,
      Value<String?> powder,
      Value<double?> powderChargeGr,
      Value<String?> bullet,
      Value<double?> bulletWeightGr,
      Value<String?> primer,
      Value<String?> brass,
      Value<double?> coalIn,
      Value<double?> cbtoIn,
      Value<double?> seatingDepthIn,
      Value<double?> primerDepthCps,
      Value<double?> shoulderBumpIn,
      Value<double?> mandrelSizeIn,
      Value<DateTime?> dateEstablished,
      Value<String?> notes,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$UserLoadsTableFilterComposer
    extends Composer<_$AppDatabase, $UserLoadsTable> {
  $$UserLoadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caliber => $composableBuilder(
    column: $table.caliber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get powder => $composableBuilder(
    column: $table.powder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get powderChargeGr => $composableBuilder(
    column: $table.powderChargeGr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bullet => $composableBuilder(
    column: $table.bullet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bulletWeightGr => $composableBuilder(
    column: $table.bulletWeightGr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get primer => $composableBuilder(
    column: $table.primer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get brass => $composableBuilder(
    column: $table.brass,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get coalIn => $composableBuilder(
    column: $table.coalIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cbtoIn => $composableBuilder(
    column: $table.cbtoIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get seatingDepthIn => $composableBuilder(
    column: $table.seatingDepthIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get primerDepthCps => $composableBuilder(
    column: $table.primerDepthCps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get shoulderBumpIn => $composableBuilder(
    column: $table.shoulderBumpIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get mandrelSizeIn => $composableBuilder(
    column: $table.mandrelSizeIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dateEstablished => $composableBuilder(
    column: $table.dateEstablished,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserLoadsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserLoadsTable> {
  $$UserLoadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caliber => $composableBuilder(
    column: $table.caliber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get powder => $composableBuilder(
    column: $table.powder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get powderChargeGr => $composableBuilder(
    column: $table.powderChargeGr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bullet => $composableBuilder(
    column: $table.bullet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bulletWeightGr => $composableBuilder(
    column: $table.bulletWeightGr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get primer => $composableBuilder(
    column: $table.primer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get brass => $composableBuilder(
    column: $table.brass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get coalIn => $composableBuilder(
    column: $table.coalIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cbtoIn => $composableBuilder(
    column: $table.cbtoIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get seatingDepthIn => $composableBuilder(
    column: $table.seatingDepthIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get primerDepthCps => $composableBuilder(
    column: $table.primerDepthCps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get shoulderBumpIn => $composableBuilder(
    column: $table.shoulderBumpIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get mandrelSizeIn => $composableBuilder(
    column: $table.mandrelSizeIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dateEstablished => $composableBuilder(
    column: $table.dateEstablished,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserLoadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserLoadsTable> {
  $$UserLoadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get caliber =>
      $composableBuilder(column: $table.caliber, builder: (column) => column);

  GeneratedColumn<String> get powder =>
      $composableBuilder(column: $table.powder, builder: (column) => column);

  GeneratedColumn<double> get powderChargeGr => $composableBuilder(
    column: $table.powderChargeGr,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bullet =>
      $composableBuilder(column: $table.bullet, builder: (column) => column);

  GeneratedColumn<double> get bulletWeightGr => $composableBuilder(
    column: $table.bulletWeightGr,
    builder: (column) => column,
  );

  GeneratedColumn<String> get primer =>
      $composableBuilder(column: $table.primer, builder: (column) => column);

  GeneratedColumn<String> get brass =>
      $composableBuilder(column: $table.brass, builder: (column) => column);

  GeneratedColumn<double> get coalIn =>
      $composableBuilder(column: $table.coalIn, builder: (column) => column);

  GeneratedColumn<double> get cbtoIn =>
      $composableBuilder(column: $table.cbtoIn, builder: (column) => column);

  GeneratedColumn<double> get seatingDepthIn => $composableBuilder(
    column: $table.seatingDepthIn,
    builder: (column) => column,
  );

  GeneratedColumn<double> get primerDepthCps => $composableBuilder(
    column: $table.primerDepthCps,
    builder: (column) => column,
  );

  GeneratedColumn<double> get shoulderBumpIn => $composableBuilder(
    column: $table.shoulderBumpIn,
    builder: (column) => column,
  );

  GeneratedColumn<double> get mandrelSizeIn => $composableBuilder(
    column: $table.mandrelSizeIn,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dateEstablished => $composableBuilder(
    column: $table.dateEstablished,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserLoadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserLoadsTable,
          UserLoadRow,
          $$UserLoadsTableFilterComposer,
          $$UserLoadsTableOrderingComposer,
          $$UserLoadsTableAnnotationComposer,
          $$UserLoadsTableCreateCompanionBuilder,
          $$UserLoadsTableUpdateCompanionBuilder,
          (
            UserLoadRow,
            BaseReferences<_$AppDatabase, $UserLoadsTable, UserLoadRow>,
          ),
          UserLoadRow,
          PrefetchHooks Function()
        > {
  $$UserLoadsTableTableManager(_$AppDatabase db, $UserLoadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserLoadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserLoadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserLoadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> caliber = const Value.absent(),
                Value<String?> powder = const Value.absent(),
                Value<double?> powderChargeGr = const Value.absent(),
                Value<String?> bullet = const Value.absent(),
                Value<double?> bulletWeightGr = const Value.absent(),
                Value<String?> primer = const Value.absent(),
                Value<String?> brass = const Value.absent(),
                Value<double?> coalIn = const Value.absent(),
                Value<double?> cbtoIn = const Value.absent(),
                Value<double?> seatingDepthIn = const Value.absent(),
                Value<double?> primerDepthCps = const Value.absent(),
                Value<double?> shoulderBumpIn = const Value.absent(),
                Value<double?> mandrelSizeIn = const Value.absent(),
                Value<DateTime?> dateEstablished = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => UserLoadsCompanion(
                id: id,
                name: name,
                caliber: caliber,
                powder: powder,
                powderChargeGr: powderChargeGr,
                bullet: bullet,
                bulletWeightGr: bulletWeightGr,
                primer: primer,
                brass: brass,
                coalIn: coalIn,
                cbtoIn: cbtoIn,
                seatingDepthIn: seatingDepthIn,
                primerDepthCps: primerDepthCps,
                shoulderBumpIn: shoulderBumpIn,
                mandrelSizeIn: mandrelSizeIn,
                dateEstablished: dateEstablished,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> caliber = const Value.absent(),
                Value<String?> powder = const Value.absent(),
                Value<double?> powderChargeGr = const Value.absent(),
                Value<String?> bullet = const Value.absent(),
                Value<double?> bulletWeightGr = const Value.absent(),
                Value<String?> primer = const Value.absent(),
                Value<String?> brass = const Value.absent(),
                Value<double?> coalIn = const Value.absent(),
                Value<double?> cbtoIn = const Value.absent(),
                Value<double?> seatingDepthIn = const Value.absent(),
                Value<double?> primerDepthCps = const Value.absent(),
                Value<double?> shoulderBumpIn = const Value.absent(),
                Value<double?> mandrelSizeIn = const Value.absent(),
                Value<DateTime?> dateEstablished = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => UserLoadsCompanion.insert(
                id: id,
                name: name,
                caliber: caliber,
                powder: powder,
                powderChargeGr: powderChargeGr,
                bullet: bullet,
                bulletWeightGr: bulletWeightGr,
                primer: primer,
                brass: brass,
                coalIn: coalIn,
                cbtoIn: cbtoIn,
                seatingDepthIn: seatingDepthIn,
                primerDepthCps: primerDepthCps,
                shoulderBumpIn: shoulderBumpIn,
                mandrelSizeIn: mandrelSizeIn,
                dateEstablished: dateEstablished,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserLoadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserLoadsTable,
      UserLoadRow,
      $$UserLoadsTableFilterComposer,
      $$UserLoadsTableOrderingComposer,
      $$UserLoadsTableAnnotationComposer,
      $$UserLoadsTableCreateCompanionBuilder,
      $$UserLoadsTableUpdateCompanionBuilder,
      (
        UserLoadRow,
        BaseReferences<_$AppDatabase, $UserLoadsTable, UserLoadRow>,
      ),
      UserLoadRow,
      PrefetchHooks Function()
    >;
typedef $$UserFirearmsTableCreateCompanionBuilder =
    UserFirearmsCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> manufacturer,
      Value<String?> model,
      Value<String?> type,
      Value<String?> action,
      Value<String?> caliber,
      Value<double?> barrelLengthIn,
      Value<String?> twistRate,
      Value<int> shotsFired,
      Value<int?> referenceFirearmId,
      Value<String?> notes,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$UserFirearmsTableUpdateCompanionBuilder =
    UserFirearmsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> manufacturer,
      Value<String?> model,
      Value<String?> type,
      Value<String?> action,
      Value<String?> caliber,
      Value<double?> barrelLengthIn,
      Value<String?> twistRate,
      Value<int> shotsFired,
      Value<int?> referenceFirearmId,
      Value<String?> notes,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$UserFirearmsTableFilterComposer
    extends Composer<_$AppDatabase, $UserFirearmsTable> {
  $$UserFirearmsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manufacturer => $composableBuilder(
    column: $table.manufacturer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caliber => $composableBuilder(
    column: $table.caliber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get barrelLengthIn => $composableBuilder(
    column: $table.barrelLengthIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get twistRate => $composableBuilder(
    column: $table.twistRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get shotsFired => $composableBuilder(
    column: $table.shotsFired,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get referenceFirearmId => $composableBuilder(
    column: $table.referenceFirearmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserFirearmsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserFirearmsTable> {
  $$UserFirearmsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manufacturer => $composableBuilder(
    column: $table.manufacturer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caliber => $composableBuilder(
    column: $table.caliber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get barrelLengthIn => $composableBuilder(
    column: $table.barrelLengthIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get twistRate => $composableBuilder(
    column: $table.twistRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get shotsFired => $composableBuilder(
    column: $table.shotsFired,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get referenceFirearmId => $composableBuilder(
    column: $table.referenceFirearmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserFirearmsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserFirearmsTable> {
  $$UserFirearmsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get manufacturer => $composableBuilder(
    column: $table.manufacturer,
    builder: (column) => column,
  );

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get caliber =>
      $composableBuilder(column: $table.caliber, builder: (column) => column);

  GeneratedColumn<double> get barrelLengthIn => $composableBuilder(
    column: $table.barrelLengthIn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get twistRate =>
      $composableBuilder(column: $table.twistRate, builder: (column) => column);

  GeneratedColumn<int> get shotsFired => $composableBuilder(
    column: $table.shotsFired,
    builder: (column) => column,
  );

  GeneratedColumn<int> get referenceFirearmId => $composableBuilder(
    column: $table.referenceFirearmId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserFirearmsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserFirearmsTable,
          UserFirearmRow,
          $$UserFirearmsTableFilterComposer,
          $$UserFirearmsTableOrderingComposer,
          $$UserFirearmsTableAnnotationComposer,
          $$UserFirearmsTableCreateCompanionBuilder,
          $$UserFirearmsTableUpdateCompanionBuilder,
          (
            UserFirearmRow,
            BaseReferences<_$AppDatabase, $UserFirearmsTable, UserFirearmRow>,
          ),
          UserFirearmRow,
          PrefetchHooks Function()
        > {
  $$UserFirearmsTableTableManager(_$AppDatabase db, $UserFirearmsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserFirearmsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserFirearmsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserFirearmsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> manufacturer = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String?> type = const Value.absent(),
                Value<String?> action = const Value.absent(),
                Value<String?> caliber = const Value.absent(),
                Value<double?> barrelLengthIn = const Value.absent(),
                Value<String?> twistRate = const Value.absent(),
                Value<int> shotsFired = const Value.absent(),
                Value<int?> referenceFirearmId = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => UserFirearmsCompanion(
                id: id,
                name: name,
                manufacturer: manufacturer,
                model: model,
                type: type,
                action: action,
                caliber: caliber,
                barrelLengthIn: barrelLengthIn,
                twistRate: twistRate,
                shotsFired: shotsFired,
                referenceFirearmId: referenceFirearmId,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> manufacturer = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String?> type = const Value.absent(),
                Value<String?> action = const Value.absent(),
                Value<String?> caliber = const Value.absent(),
                Value<double?> barrelLengthIn = const Value.absent(),
                Value<String?> twistRate = const Value.absent(),
                Value<int> shotsFired = const Value.absent(),
                Value<int?> referenceFirearmId = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => UserFirearmsCompanion.insert(
                id: id,
                name: name,
                manufacturer: manufacturer,
                model: model,
                type: type,
                action: action,
                caliber: caliber,
                barrelLengthIn: barrelLengthIn,
                twistRate: twistRate,
                shotsFired: shotsFired,
                referenceFirearmId: referenceFirearmId,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserFirearmsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserFirearmsTable,
      UserFirearmRow,
      $$UserFirearmsTableFilterComposer,
      $$UserFirearmsTableOrderingComposer,
      $$UserFirearmsTableAnnotationComposer,
      $$UserFirearmsTableCreateCompanionBuilder,
      $$UserFirearmsTableUpdateCompanionBuilder,
      (
        UserFirearmRow,
        BaseReferences<_$AppDatabase, $UserFirearmsTable, UserFirearmRow>,
      ),
      UserFirearmRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ManufacturersTableTableManager get manufacturers =>
      $$ManufacturersTableTableManager(_db, _db.manufacturers);
  $$CartridgesTableTableManager get cartridges =>
      $$CartridgesTableTableManager(_db, _db.cartridges);
  $$PowdersTableTableManager get powders =>
      $$PowdersTableTableManager(_db, _db.powders);
  $$BulletsTableTableManager get bullets =>
      $$BulletsTableTableManager(_db, _db.bullets);
  $$PrimersTableTableManager get primers =>
      $$PrimersTableTableManager(_db, _db.primers);
  $$BrassProductsTableTableManager get brassProducts =>
      $$BrassProductsTableTableManager(_db, _db.brassProducts);
  $$FirearmsRefTableTableManager get firearmsRef =>
      $$FirearmsRefTableTableManager(_db, _db.firearmsRef);
  $$FirearmPartsTableTableManager get firearmParts =>
      $$FirearmPartsTableTableManager(_db, _db.firearmParts);
  $$CustomComponentsTableTableManager get customComponents =>
      $$CustomComponentsTableTableManager(_db, _db.customComponents);
  $$UserLoadsTableTableManager get userLoads =>
      $$UserLoadsTableTableManager(_db, _db.userLoads);
  $$UserFirearmsTableTableManager get userFirearms =>
      $$UserFirearmsTableTableManager(_db, _db.userFirearms);
}
