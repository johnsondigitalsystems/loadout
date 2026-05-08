// FILE: test/atmosphere_preset_snapshot_test.dart
//
// Unit tests for `AtmosphereSnapshot.matches()` in
// `lib/widgets/atmosphere_preset_picker.dart`. The tolerance windows are
// what the inline picker uses to decide whether to show a preset name or
// fall back to "Custom" — they are part of the user-facing contract.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loadout/database/database.dart';
import 'package:loadout/widgets/atmosphere_preset_picker.dart';

Future<AtmospherePresetRow> _insertPreset(
  AppDatabase db, {
  required String name,
  required double pressure,
  required double temp,
  required double humidity,
  double? altitude,
}) async {
  final id = await db.into(db.atmospherePresets).insert(
        AtmospherePresetsCompanion.insert(
          name: name,
          stationPressureInHg: pressure,
          temperatureF: temp,
          humidityPct: humidity,
          altitudeFt: altitude == null
              ? const Value.absent()
              : Value(altitude),
        ),
      );
  return (await (db.select(db.atmospherePresets)
            ..where((p) => p.id.equals(id)))
          .getSingle());
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  group('AtmosphereSnapshot.matches', () {
    test('exact-equals match returns true', () async {
      final preset = await _insertPreset(
        db,
        name: 'A',
        pressure: 28.7,
        temp: 88,
        humidity: 62,
      );
      final snap = const AtmosphereSnapshot(
        stationPressureInHg: 28.7,
        temperatureF: 88,
        humidityPct: 62,
      );
      expect(snap.matches(preset), isTrue);
    });

    test('within-tolerance match returns true', () async {
      final preset = await _insertPreset(
        db,
        name: 'A',
        pressure: 28.7,
        temp: 88,
        humidity: 62,
      );
      // Pressure within 0.005, temp within 0.5, humidity within 0.5.
      final snap = const AtmosphereSnapshot(
        stationPressureInHg: 28.703,
        temperatureF: 88.4,
        humidityPct: 62.4,
      );
      expect(snap.matches(preset), isTrue);
    });

    test('pressure outside tolerance returns false', () async {
      final preset = await _insertPreset(
        db,
        name: 'A',
        pressure: 28.7,
        temp: 88,
        humidity: 62,
      );
      final snap = const AtmosphereSnapshot(
        stationPressureInHg: 28.71, // 0.01 inHg off → outside 0.005 window
        temperatureF: 88,
        humidityPct: 62,
      );
      expect(snap.matches(preset), isFalse);
    });

    test('temperature outside tolerance returns false', () async {
      final preset = await _insertPreset(
        db,
        name: 'A',
        pressure: 28.7,
        temp: 88,
        humidity: 62,
      );
      final snap = const AtmosphereSnapshot(
        stationPressureInHg: 28.7,
        temperatureF: 89, // 1°F off → outside 0.5°F window
        humidityPct: 62,
      );
      expect(snap.matches(preset), isFalse);
    });

    test('humidity outside tolerance returns false', () async {
      final preset = await _insertPreset(
        db,
        name: 'A',
        pressure: 28.7,
        temp: 88,
        humidity: 62,
      );
      final snap = const AtmosphereSnapshot(
        stationPressureInHg: 28.7,
        temperatureF: 88,
        humidityPct: 65, // 3% off → outside 0.5% window
      );
      expect(snap.matches(preset), isFalse);
    });

    test('null required field on snapshot returns false', () async {
      final preset = await _insertPreset(
        db,
        name: 'A',
        pressure: 28.7,
        temp: 88,
        humidity: 62,
      );
      const snap = AtmosphereSnapshot(
        stationPressureInHg: null, // user has typed nothing
        temperatureF: 88,
        humidityPct: 62,
      );
      expect(snap.matches(preset), isFalse);
    });

    test('preset with altitude fails when snapshot altitude missing',
        () async {
      final preset = await _insertPreset(
        db,
        name: 'A',
        pressure: 28.7,
        temp: 88,
        humidity: 62,
        altitude: 720,
      );
      const snap = AtmosphereSnapshot(
        stationPressureInHg: 28.7,
        temperatureF: 88,
        humidityPct: 62,
        // altitudeFt deliberately omitted — preset requires it.
      );
      expect(snap.matches(preset), isFalse);
    });

    test('preset with altitude succeeds when snapshot altitude in tolerance',
        () async {
      final preset = await _insertPreset(
        db,
        name: 'A',
        pressure: 28.7,
        temp: 88,
        humidity: 62,
        altitude: 720,
      );
      const snap = AtmosphereSnapshot(
        stationPressureInHg: 28.7,
        temperatureF: 88,
        humidityPct: 62,
        altitudeFt: 723, // 3 ft off — within 5-ft window
      );
      expect(snap.matches(preset), isTrue);
    });

    test('preset without altitude ignores snapshot altitude entirely',
        () async {
      // Symmetric to the above — the picker should not rule out a
      // preset that didn't capture altitude just because the live form
      // happens to have an Elevation field set.
      final preset = await _insertPreset(
        db,
        name: 'A',
        pressure: 28.7,
        temp: 88,
        humidity: 62,
        // no altitude
      );
      const snap = AtmosphereSnapshot(
        stationPressureInHg: 28.7,
        temperatureF: 88,
        humidityPct: 62,
        altitudeFt: 1500,
      );
      expect(snap.matches(preset), isTrue);
    });
  });
}
