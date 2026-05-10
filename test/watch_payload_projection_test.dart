// FILE: test/watch_payload_projection_test.dart
//
// Verifies the [WatchPayloadProjection] static helpers map domain rows
// to the right wire-shape payloads. Each projection is a pure
// function — no widget tree needed, no providers, no I/O.

import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/database/database.dart';
import 'package:loadout/services/ballistics/drag_functions.dart';
import 'package:loadout/services/ballistics/projectile.dart';
import 'package:loadout/services/ballistics/solver.dart';
import 'package:loadout/services/common_loads_catalog.dart';
import 'package:loadout/services/watch_payload_projection.dart';

void main() {
  group('WatchPayloadProjection.activeLoadFromUserLoad', () {
    test('packs every field the watch surface uses', () {
      final row = UserLoadRow(
        id: 1,
        name: 'PRS Match Load',
        caliber: '6.5 Creedmoor',
        powder: 'H4350',
        powderChargeGr: 41.5,
        bullet: '140 ELD-M',
        bulletWeightGr: 140,
        primer: 'CCI 200',
        brass: 'Lapua',
        coalIn: 2.825,
        cbtoIn: 2.255,
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
        bulletMeplatTrimmed: false,
        bulletPointed: false,
        bulletWeightSorted: false,
        bulletBtoSorted: false,
        bulletDiameterSorted: false,
        ejectorMarks: false,
        crateredPrimers: false,
        powderReferenceTempCelsius: 15.6,
        isFavorite: false,
      );

      final snap = WatchPayloadProjection.activeLoadFromUserLoad(row);
      expect(snap.name, 'PRS Match Load');
      expect(snap.cartridgeName, '6.5 Creedmoor');
      expect(snap.powderName, 'H4350');
      expect(snap.powderChargeGr, 41.5);
      expect(snap.bulletName, '140 ELD-M');
      expect(snap.bulletWeightGr, 140);
      expect(snap.primer, 'CCI 200');
      expect(snap.brass, 'Lapua');
      expect(snap.coalIn, 2.825);
      expect(snap.cbtoIn, 2.255);
    });

    test('falls back to empty cartridge when caliber is null', () {
      final row = UserLoadRow(
        id: 2,
        name: 'Untitled',
        // caliber: null,
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
        bulletMeplatTrimmed: false,
        bulletPointed: false,
        bulletWeightSorted: false,
        bulletBtoSorted: false,
        bulletDiameterSorted: false,
        ejectorMarks: false,
        crateredPrimers: false,
        powderReferenceTempCelsius: 15.6,
        isFavorite: false,
      );
      final snap = WatchPayloadProjection.activeLoadFromUserLoad(row);
      expect(snap.cartridgeName, '');
    });
  });

  group('WatchPayloadProjection.activeLoadFromBallisticProfile', () {
    test('uses profile name as snapshot name and leaves cartridge empty', () {
      final p = BallisticProfileRow(
        id: 5,
        name: 'PRS Match Load',
        bulletWeightGr: 140,
        bulletDiameterIn: 0.264,
        ballisticCoefficient: 0.315,
        dragModel: 'g7',
        muzzleVelocityFps: 2750,
        zeroRangeYd: 100,
        sightHeightIn: 2.0,
        rangeIncrementYd: 100,
        rangeMinYd: 100,
        rangeMaxYd: 1000,
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
        isFavorite: false,
      );
      final snap = WatchPayloadProjection.activeLoadFromBallisticProfile(p);
      expect(snap.name, 'PRS Match Load');
      expect(snap.cartridgeName, '');
      expect(snap.bulletWeightGr, 140);
      expect(snap.powderName, isNull);
      expect(snap.bulletName, isNull);
    });
  });

  group('WatchPayloadProjection.activeLoadFromCommonLoad', () {
    test('uses cartridge family + display name', () {
      const load = CommonLoad(
        cartridge: '6.5 Creedmoor',
        name: 'Hornady Match 140 ELD-M',
        bulletWeightGr: 140,
        bulletDiameterIn: 0.264,
        bc: 0.315,
        dragModel: DragModel.g7,
        muzzleVelocityFps: 2710,
      );
      final snap = WatchPayloadProjection.activeLoadFromCommonLoad(load);
      expect(snap.name, 'Hornady Match 140 ELD-M');
      expect(snap.cartridgeName, '6.5 Creedmoor');
      expect(snap.bulletName, 'Hornady Match 140 ELD-M');
      expect(snap.bulletWeightGr, 140);
    });
  });

  group('WatchPayloadProjection.firearmGlanceFromUserFirearm', () {
    test('forwards name, shotsFired, and caliber', () {
      final f = UserFirearmRow(
        id: 1,
        name: 'Tikka T3x CTR',
        caliber: '6.5 Creedmoor',
        shotsFired: 1234,
        twistDirection: 'right',
        sightScaleVertical: 1.0,
        sightScaleHorizontal: 1.0,
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
        isFavorite: false,
        isCustomBuild: false,
      );
      final glance = WatchPayloadProjection.firearmGlanceFromUserFirearm(f);
      expect(glance.name, 'Tikka T3x CTR');
      expect(glance.shotsFired, 1234);
      expect(glance.caliber, '6.5 Creedmoor');
      expect(
        glance.barrelLifeRemainingPct,
        isNull,
        reason:
            'LoadOut does not track expected barrel life today; the field '
            'must stay null until the schema gains it.',
      );
    });
  });

  group('WatchPayloadProjection.dopeFromSolverOutput', () {
    test('builds a snapshot with the right per-row mil conversions', () {
      final samples = <TrajectorySample>[
        TrajectorySample(
          rangeYards: 100,
          timeSec: 0.12,
          dropInches: 0,
          windDriftInches: 0.5,
          spinDriftInches: 0,
          velocityFps: 2700,
          energyFtLb: 2200,
          machNumber: 2.41,
        ),
        TrajectorySample(
          rangeYards: 600,
          timeSec: 0.92,
          dropInches: 117.0,
          windDriftInches: 18.0,
          spinDriftInches: 1.0,
          velocityFps: 1780,
          energyFtLb: 980,
          machNumber: 1.59,
        ),
      ];
      final projectile = Projectile(
        diameterIn: 0.264,
        weightGr: 140,
        bc: 0.315,
        dragModel: DragModel.g7,
      );
      const shot = ShotInputs(
        muzzleVelocityFps: 2750,
        sightHeightIn: 2.0,
        zeroRangeYards: 100,
      );
      final snap = WatchPayloadProjection.dopeFromSolverOutput(
        samples: samples,
        projectile: projectile,
        shot: shot,
        windSpeedMph: 8,
        windFromDeg: 270,
        generatedAtMs: 1730000000000,
        cartridgeName: '6.5 Creedmoor',
        bulletName: '140 ELD-M',
        profileName: 'PRS Match Load',
        firearmName: 'Tikka T3x CTR',
      );
      expect(snap.cartridgeName, '6.5 Creedmoor');
      expect(snap.bulletGr, 140);
      expect(snap.dragModel, 'g7');
      expect(snap.zeroRangeYd, 100);
      expect(snap.muzzleVelocityFps, 2750);
      expect(snap.profileName, 'PRS Match Load');
      expect(snap.firearmName, 'Tikka T3x CTR');
      expect(snap.rows, hasLength(2));
      expect(snap.rows.first.rangeYd, 100);
      expect(snap.rows[1].rangeYd, 600);
      // Sanity check the unit conversion: 117 inches drop at 600 yd
      // ≈ 5.4 mil. Use a generous tolerance because the projection
      // uses the small-angle-approximation arctangent.
      expect(snap.rows[1].dropMil, closeTo(5.4, 0.1));
      expect(snap.rows[1].windMil, closeTo(0.83, 0.1));
    });

    test('drag model g1 maps to lower-case "g1" on the wire', () {
      final samples = <TrajectorySample>[
        TrajectorySample(
          rangeYards: 100,
          timeSec: 0.10,
          dropInches: 0,
          windDriftInches: 0,
          spinDriftInches: 0,
          velocityFps: 2700,
          energyFtLb: 2200,
          machNumber: 2.41,
        ),
      ];
      final projectile = Projectile(
        diameterIn: 0.264,
        weightGr: 140,
        bc: 0.500,
        dragModel: DragModel.g1,
      );
      const shot = ShotInputs(
        muzzleVelocityFps: 2700,
        sightHeightIn: 2.0,
        zeroRangeYards: 100,
      );
      final snap = WatchPayloadProjection.dopeFromSolverOutput(
        samples: samples,
        projectile: projectile,
        shot: shot,
        windSpeedMph: 0,
        windFromDeg: 0,
        generatedAtMs: 0,
      );
      expect(snap.dragModel, 'g1');
    });

    test('empty samples list still produces a valid (empty-rows) snapshot',
        () {
      final projectile = Projectile(
        diameterIn: 0.264,
        weightGr: 140,
        bc: 0.315,
        dragModel: DragModel.g7,
      );
      const shot = ShotInputs(
        muzzleVelocityFps: 2750,
        sightHeightIn: 2.0,
        zeroRangeYards: 100,
      );
      final snap = WatchPayloadProjection.dopeFromSolverOutput(
        samples: const <TrajectorySample>[],
        projectile: projectile,
        shot: shot,
        windSpeedMph: 0,
        windFromDeg: 0,
        generatedAtMs: 0,
      );
      expect(snap.rows, isEmpty);
    });
  });
}
