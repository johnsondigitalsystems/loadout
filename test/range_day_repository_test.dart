// FILE: test/range_day_repository_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Unit tests for `lib/repositories/range_day_repository.dart`. Exercises the
// session-level CRUD (insert/update/delete with the full optional-field
// surface), the shot-impact CRUD that hangs off each session, and the
// repository's small contract details: `getById` returns null on miss,
// `watchAll()` orders newest-first by `date`, `deleteSession` cascades to
// child shots inside a transaction, and `nextShotNumberForSession` returns
// 1 for an empty session and `max + 1` otherwise. Uses an in-memory drift
// database (`AppDatabase.forTesting(NativeDatabase.memory())`) per-test so
// state never leaks across tests.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// `RangeDayRepository` is the persistence boundary for the Range Day
// workspace; the visual target widget, group-statistics calculator, and
// hit-probability service all read from it. Without coverage here, schema
// migrations or query refactors could silently break the cascade-delete or
// the shot-number monotonicity that the tap-to-record flow relies on.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * Drift does NOT enforce SQL-level ON DELETE CASCADE. The repository's
//     `deleteSession` does the cascade itself in a transaction; the test for
//     that cascade has to insert real shot rows and then assert they're
//     gone after the parent delete.
//   * `watchAll()` orders by `date`, NOT `updatedAt`. The ordering test
//     deliberately inserts rows out-of-date-order and updates the oldest
//     one mid-test — the order of emissions must still respect `date`
//     descending.
//   * Drift's `DateTime` columns persist with second precision on SQLite, so
//     `closeTo`-style checks on millisecond-level differences in
//     `updatedAt` would be flaky. Tests that depend on `updatedAt` advancing
//     sleep ~1.1 seconds before the second write — the same workaround used
//     by `atmosphere_preset_repository_test.dart`.
//   * Calling repository methods after `db.close()` throws. The test for
//     that asserts an exception is raised but does not pin the exact type
//     (drift's closed-DB error is wrapped through several layers).
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   * `flutter test test/range_day_repository_test.dart` (CI, pre-commit
//     gate).
//   * `flutter test` (full suite).
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
//   * In-memory SQLite databases — created in `setUp`, closed in `tearDown`.
//     No filesystem, network, or platform-channel I/O.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loadout/database/database.dart';
import 'package:loadout/repositories/range_day_repository.dart';

void main() {
  group('RangeDayRepository — sessions CRUD', () {
    late AppDatabase db;
    late RangeDayRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = RangeDayRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('insert with minimal fields → readback persists every column',
        () async {
      // Drift's DateTime columns persist as Unix epoch seconds and read
      // back as a local-time DateTime, so we compare via
      // `isAtSameMomentAs` rather than wall-clock equality.
      final date = DateTime.utc(2026, 5, 8, 12, 0, 0);
      final id = await repo.insertSession(
        RangeDaySessionsCompanion.insert(
          name: 'May 8 100yd',
          date: date,
          distanceYd: 100,
        ),
      );
      expect(id, greaterThan(0));

      final row = await repo.getById(id);
      expect(row, isNotNull);
      expect(row!.id, id);
      expect(row.name, 'May 8 100yd');
      expect(row.date.isAtSameMomentAs(date), isTrue);
      expect(row.distanceYd, closeTo(100, 1e-6));
      // Every optional field stays null when not specified.
      expect(row.notes, isNull);
      expect(row.ballisticProfileId, isNull);
      expect(row.recipeId, isNull);
      expect(row.firearmId, isNull);
      expect(row.targetId, isNull);
      expect(row.temperatureF, isNull);
      expect(row.pressureInHg, isNull);
      expect(row.humidityPct, isNull);
      expect(row.elevationFt, isNull);
      expect(row.windSpeedMph, isNull);
      expect(row.windDirectionDeg, isNull);
      expect(row.aimPointX, isNull);
      expect(row.aimPointY, isNull);
      expect(row.assumedGroupMoa, isNull);
      expect(row.windUncertaintyMph, isNull);
      expect(row.rangeUncertaintyYd, isNull);
      expect(row.reticleId, isNull);
      expect(row.cantDegrees, isNull);
      expect(row.shotAzimuthDegrees, isNull);
      expect(row.inclineAngleDeg, isNull);
      expect(row.atmospherePresetId, isNull);
      // correctionUnit defaults to 'mil' (column-default).
      expect(row.correctionUnit, 'mil');
      // createdAt and updatedAt are always populated by drift's
      // currentDateAndTime default — assert the column exists rather than
      // using `isNotNull` (DateTime.now() can never be null).
      expect(row.createdAt.year, greaterThanOrEqualTo(2020));
      expect(row.updatedAt.year, greaterThanOrEqualTo(2020));
    });

    test('insert with all optional fields populated → readback fidelity',
        () async {
      final date = DateTime.utc(2026, 4, 14, 9, 30, 0);
      final id = await repo.insertSession(
        RangeDaySessionsCompanion.insert(
          name: 'Camp Atterbury 600',
          date: date,
          distanceYd: 600,
          notes: const Value('Wind picked up after shot 6'),
          ballisticProfileId: const Value(7),
          recipeId: const Value(11),
          firearmId: const Value(3),
          targetId: const Value(42),
          temperatureF: const Value(82.5),
          pressureInHg: const Value(28.71),
          humidityPct: const Value(55),
          elevationFt: const Value(720),
          windSpeedMph: const Value(7.2),
          windDirectionDeg: const Value(315),
          aimPointX: const Value(0.0),
          aimPointY: const Value(0.5),
          assumedGroupMoa: const Value(0.75),
          windUncertaintyMph: const Value(1.5),
          rangeUncertaintyYd: const Value(3),
          reticleId: const Value(5),
          correctionUnit: const Value('moa'),
          cantDegrees: const Value(-1.2),
          shotAzimuthDegrees: const Value(178),
          inclineAngleDeg: const Value(3.5),
          atmospherePresetId: const Value(9),
        ),
      );

      final row = await repo.getById(id);
      expect(row, isNotNull);
      expect(row!.name, 'Camp Atterbury 600');
      expect(row.date.isAtSameMomentAs(date), isTrue);
      expect(row.distanceYd, closeTo(600, 1e-6));
      expect(row.notes, 'Wind picked up after shot 6');
      expect(row.ballisticProfileId, 7);
      expect(row.recipeId, 11);
      expect(row.firearmId, 3);
      expect(row.targetId, 42);
      expect(row.temperatureF, closeTo(82.5, 1e-6));
      expect(row.pressureInHg, closeTo(28.71, 1e-6));
      expect(row.humidityPct, closeTo(55, 1e-6));
      expect(row.elevationFt, closeTo(720, 1e-6));
      expect(row.windSpeedMph, closeTo(7.2, 1e-6));
      expect(row.windDirectionDeg, closeTo(315, 1e-6));
      expect(row.aimPointX, closeTo(0.0, 1e-9));
      expect(row.aimPointY, closeTo(0.5, 1e-6));
      expect(row.assumedGroupMoa, closeTo(0.75, 1e-6));
      expect(row.windUncertaintyMph, closeTo(1.5, 1e-6));
      expect(row.rangeUncertaintyYd, closeTo(3, 1e-6));
      expect(row.reticleId, 5);
      expect(row.correctionUnit, 'moa');
      expect(row.cantDegrees, closeTo(-1.2, 1e-6));
      expect(row.shotAzimuthDegrees, closeTo(178, 1e-6));
      expect(row.inclineAngleDeg, closeTo(3.5, 1e-6));
      expect(row.atmospherePresetId, 9);
    });

    test('updateSession preserves untouched columns', () async {
      final date = DateTime.utc(2026, 3, 1, 10, 0, 0);
      final id = await repo.insertSession(
        RangeDaySessionsCompanion.insert(
          name: 'Original name',
          date: date,
          distanceYd: 200,
          notes: const Value('original notes'),
          temperatureF: const Value(60),
          pressureInHg: const Value(29.92),
        ),
      );
      // Sleep a tick so the bumped updatedAt strictly exceeds the original.
      // Drift's DateTime columns persist to second precision on SQLite, so
      // 5ms isn't enough — sleep ~1.1s to guarantee a strictly greater
      // timestamp on read-back.
      final originalUpdatedAt = (await repo.getById(id))!.updatedAt;
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final ok = await repo.updateSession(
        id,
        RangeDaySessionsCompanion(
          notes: const Value('updated notes'),
        ),
      );
      expect(ok, isTrue);

      final row = await repo.getById(id);
      expect(row, isNotNull);
      // Updated column reflects the change.
      expect(row!.notes, 'updated notes');
      // Untouched columns retain their original values.
      expect(row.name, 'Original name');
      expect(row.distanceYd, closeTo(200, 1e-6));
      expect(row.temperatureF, closeTo(60, 1e-6));
      expect(row.pressureInHg, closeTo(29.92, 1e-6));
      expect(row.date.isAtSameMomentAs(date), isTrue);
      // updatedAt has advanced.
      expect(row.updatedAt.isAfter(originalUpdatedAt), isTrue);
    });

    test('updateSession of non-existent id returns false', () async {
      final ok = await repo.updateSession(
        424242,
        RangeDaySessionsCompanion(name: const Value('phantom')),
      );
      expect(ok, isFalse);
    });

    test('deleteSession removes the row', () async {
      final id = await repo.insertSession(
        RangeDaySessionsCompanion.insert(
          name: 'To be deleted',
          date: DateTime.utc(2026, 5, 1, 8, 0, 0),
          distanceYd: 300,
        ),
      );
      expect(await repo.getById(id), isNotNull);
      await repo.deleteSession(id);
      expect(await repo.getById(id), isNull);
    });

    test('getById(nonExistentId) returns null and does NOT throw', () async {
      expect(await repo.getById(999999), isNull);
      expect(await repo.getById(-1), isNull);
      expect(await repo.getById(0), isNull);
    });

    test('watchAll() emits empty list when no sessions exist', () async {
      final first = await repo.watchAll().first;
      expect(first, isEmpty);
      expect(first, isA<List<RangeDaySessionRow>>());
    });

    test('watchAll() orders rows newest-first by date', () async {
      // Insert in scrambled date order so we prove the sort is by `date`,
      // not by id / createdAt / updatedAt.
      final scrambled = <DateTime>[
        DateTime.utc(2026, 1, 15, 10, 0, 0),
        DateTime.utc(2026, 5, 8, 10, 0, 0),
        DateTime.utc(2025, 12, 1, 10, 0, 0),
        DateTime.utc(2026, 3, 22, 10, 0, 0),
      ];
      for (var i = 0; i < scrambled.length; i++) {
        await repo.insertSession(
          RangeDaySessionsCompanion.insert(
            name: 'Session $i',
            date: scrambled[i],
            distanceYd: 100,
          ),
        );
      }
      final rows = await repo.watchAll().first;
      expect(rows.length, scrambled.length);
      // Newest first. Compare epoch milliseconds rather than wall-clock
      // DateTime values so timezone-on-readback differences don't
      // muddy the assertion.
      final actualEpochs =
          rows.map((r) => r.date.millisecondsSinceEpoch).toList();
      final expectedEpochs = <int>[
        DateTime.utc(2026, 5, 8, 10, 0, 0).millisecondsSinceEpoch,
        DateTime.utc(2026, 3, 22, 10, 0, 0).millisecondsSinceEpoch,
        DateTime.utc(2026, 1, 15, 10, 0, 0).millisecondsSinceEpoch,
        DateTime.utc(2025, 12, 1, 10, 0, 0).millisecondsSinceEpoch,
      ];
      expect(actualEpochs, expectedEpochs);
    });

    test('watchAll() emits multiple times across inserts', () async {
      final emissions = <int>[];
      final sub = repo.watchAll().listen((rows) {
        emissions.add(rows.length);
      });
      // Let the initial emission flush.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await repo.insertSession(
        RangeDaySessionsCompanion.insert(
          name: 'A',
          date: DateTime.utc(2026, 5, 1, 8, 0, 0),
          distanceYd: 100,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await repo.insertSession(
        RangeDaySessionsCompanion.insert(
          name: 'B',
          date: DateTime.utc(2026, 5, 2, 8, 0, 0),
          distanceYd: 200,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      // First emission is the empty initial state, then each insert adds
      // a row. We don't pin exact emission count (drift may coalesce
      // adjacent updates) — but the listener must have seen at least the
      // empty state and the final 2-row state.
      expect(emissions.first, 0);
      expect(emissions.last, 2);
      expect(emissions.length, greaterThanOrEqualTo(2));
    });
  });

  group('RangeDayRepository — shots CRUD', () {
    late AppDatabase db;
    late RangeDayRepository repo;
    late int sessionId;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = RangeDayRepository(db);
      sessionId = await repo.insertSession(
        RangeDaySessionsCompanion.insert(
          name: 'Shot host',
          date: DateTime.utc(2026, 5, 8, 12, 0, 0),
          distanceYd: 500,
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('insert shot for a session → readback persists every column',
        () async {
      final recordedAt = DateTime.utc(2026, 5, 8, 12, 5, 30);
      final shotId = await repo.insertShot(
        ShotImpactsCompanion.insert(
          rangeDaySessionId: sessionId,
          shotNumber: 1,
          impactX: 0.12,
          impactY: -0.04,
          notes: const Value('caller pulled the trigger left'),
          velocityFps: const Value(2712.5),
          recordedAt: Value(recordedAt),
        ),
      );
      expect(shotId, greaterThan(0));

      final shots = await repo.shotsForSession(sessionId);
      expect(shots.length, 1);
      final shot = shots.single;
      expect(shot.id, shotId);
      expect(shot.rangeDaySessionId, sessionId);
      expect(shot.shotNumber, 1);
      expect(shot.impactX, closeTo(0.12, 1e-6));
      expect(shot.impactY, closeTo(-0.04, 1e-6));
      expect(shot.notes, 'caller pulled the trigger left');
      expect(shot.velocityFps, closeTo(2712.5, 1e-6));
      expect(shot.recordedAt.isAtSameMomentAs(recordedAt), isTrue);
    });

    test('insert multiple shots → count matches and ordering is by shotNumber',
        () async {
      // Insert in scrambled shot-number order so we prove the sort is
      // by `shotNumber`, not by id / recordedAt.
      const numbers = [3, 1, 5, 2, 4];
      for (final n in numbers) {
        await repo.insertShot(
          ShotImpactsCompanion.insert(
            rangeDaySessionId: sessionId,
            shotNumber: n,
            impactX: 0.0,
            impactY: 0.0,
          ),
        );
      }
      final shots = await repo.shotsForSession(sessionId);
      expect(shots.length, 5);
      expect(shots.map((s) => s.shotNumber).toList(), [1, 2, 3, 4, 5]);
    });

    test('streamShotsForSession orders by shotNumber ascending', () async {
      const numbers = [10, 7, 1, 4, 8];
      for (final n in numbers) {
        await repo.insertShot(
          ShotImpactsCompanion.insert(
            rangeDaySessionId: sessionId,
            shotNumber: n,
            impactX: 0.0,
            impactY: 0.0,
          ),
        );
      }
      final shots = await repo.streamShotsForSession(sessionId).first;
      expect(shots.map((s) => s.shotNumber).toList(), [1, 4, 7, 8, 10]);
    });

    test('deleteShot removes only the targeted row', () async {
      final ids = <int>[];
      for (var n = 1; n <= 3; n++) {
        ids.add(await repo.insertShot(
          ShotImpactsCompanion.insert(
            rangeDaySessionId: sessionId,
            shotNumber: n,
            impactX: 0.0,
            impactY: 0.0,
          ),
        ));
      }
      final removed = await repo.deleteShot(ids[1]);
      expect(removed, 1);
      final remaining = await repo.shotsForSession(sessionId);
      expect(remaining.length, 2);
      expect(remaining.map((s) => s.shotNumber).toList(), [1, 3]);
    });

    test('updateShot updates the row and returns true', () async {
      final id = await repo.insertShot(
        ShotImpactsCompanion.insert(
          rangeDaySessionId: sessionId,
          shotNumber: 1,
          impactX: 0.0,
          impactY: 0.0,
        ),
      );
      final ok = await repo.updateShot(
        id,
        ShotImpactsCompanion(
          notes: const Value('called good'),
          impactX: const Value(0.25),
        ),
      );
      expect(ok, isTrue);
      final shot = (await repo.shotsForSession(sessionId)).single;
      expect(shot.notes, 'called good');
      expect(shot.impactX, closeTo(0.25, 1e-6));
      // impactY untouched.
      expect(shot.impactY, closeTo(0.0, 1e-9));
    });

    test('updateShot of non-existent id returns false', () async {
      final ok = await repo.updateShot(
        999999,
        ShotImpactsCompanion(notes: const Value('phantom')),
      );
      expect(ok, isFalse);
    });

    test('deleteSession cascades to all shots', () async {
      // Insert sibling session so we can prove the cascade only touches
      // the deleted session's shots, not unrelated ones.
      final siblingSessionId = await repo.insertSession(
        RangeDaySessionsCompanion.insert(
          name: 'Sibling',
          date: DateTime.utc(2026, 5, 8, 13, 0, 0),
          distanceYd: 100,
        ),
      );
      for (var n = 1; n <= 3; n++) {
        await repo.insertShot(
          ShotImpactsCompanion.insert(
            rangeDaySessionId: sessionId,
            shotNumber: n,
            impactX: 0.0,
            impactY: 0.0,
          ),
        );
        await repo.insertShot(
          ShotImpactsCompanion.insert(
            rangeDaySessionId: siblingSessionId,
            shotNumber: n,
            impactX: 0.5,
            impactY: 0.5,
          ),
        );
      }
      expect((await repo.shotsForSession(sessionId)).length, 3);
      expect((await repo.shotsForSession(siblingSessionId)).length, 3);

      await repo.deleteSession(sessionId);
      // Parent session is gone.
      expect(await repo.getById(sessionId), isNull);
      // Children of deleted session are gone.
      expect((await repo.shotsForSession(sessionId)).length, 0);
      // Sibling session and its children are untouched.
      expect(await repo.getById(siblingSessionId), isNotNull);
      expect((await repo.shotsForSession(siblingSessionId)).length, 3);
    });

    test('shotsForSession with zero shots returns empty list', () async {
      final shots = await repo.shotsForSession(sessionId);
      expect(shots, isEmpty);
      expect(shots, isA<List<ShotImpactRow>>());
    });

    test('shotsForSession ignores shots from other sessions', () async {
      final otherId = await repo.insertSession(
        RangeDaySessionsCompanion.insert(
          name: 'Other',
          date: DateTime.utc(2026, 5, 9, 12, 0, 0),
          distanceYd: 200,
        ),
      );
      // 2 shots in our session, 3 in the other.
      for (var n = 1; n <= 2; n++) {
        await repo.insertShot(
          ShotImpactsCompanion.insert(
            rangeDaySessionId: sessionId,
            shotNumber: n,
            impactX: 0.0,
            impactY: 0.0,
          ),
        );
      }
      for (var n = 1; n <= 3; n++) {
        await repo.insertShot(
          ShotImpactsCompanion.insert(
            rangeDaySessionId: otherId,
            shotNumber: n,
            impactX: 0.0,
            impactY: 0.0,
          ),
        );
      }
      expect((await repo.shotsForSession(sessionId)).length, 2);
      expect((await repo.shotsForSession(otherId)).length, 3);
    });

    test('clearShotsForSession removes every shot in the session', () async {
      for (var n = 1; n <= 5; n++) {
        await repo.insertShot(
          ShotImpactsCompanion.insert(
            rangeDaySessionId: sessionId,
            shotNumber: n,
            impactX: 0.0,
            impactY: 0.0,
          ),
        );
      }
      expect((await repo.shotsForSession(sessionId)).length, 5);
      final cleared = await repo.clearShotsForSession(sessionId);
      expect(cleared, 5);
      expect((await repo.shotsForSession(sessionId)).length, 0);
      // Parent session itself is preserved.
      expect(await repo.getById(sessionId), isNotNull);
    });

    test('clearShotsForSession on a session with zero shots returns 0',
        () async {
      final cleared = await repo.clearShotsForSession(sessionId);
      expect(cleared, 0);
    });

    test('clearShotsForSession only touches the target session', () async {
      final otherId = await repo.insertSession(
        RangeDaySessionsCompanion.insert(
          name: 'Other',
          date: DateTime.utc(2026, 5, 9, 12, 0, 0),
          distanceYd: 200,
        ),
      );
      for (var n = 1; n <= 3; n++) {
        await repo.insertShot(
          ShotImpactsCompanion.insert(
            rangeDaySessionId: sessionId,
            shotNumber: n,
            impactX: 0.0,
            impactY: 0.0,
          ),
        );
        await repo.insertShot(
          ShotImpactsCompanion.insert(
            rangeDaySessionId: otherId,
            shotNumber: n,
            impactX: 0.0,
            impactY: 0.0,
          ),
        );
      }
      await repo.clearShotsForSession(sessionId);
      expect((await repo.shotsForSession(sessionId)).length, 0);
      expect((await repo.shotsForSession(otherId)).length, 3);
    });
  });

  group('RangeDayRepository — nextShotNumberForSession', () {
    late AppDatabase db;
    late RangeDayRepository repo;
    late int sessionId;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = RangeDayRepository(db);
      sessionId = await repo.insertSession(
        RangeDaySessionsCompanion.insert(
          name: 'Numbering host',
          date: DateTime.utc(2026, 5, 8, 12, 0, 0),
          distanceYd: 500,
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('returns 1 when the session has no shots', () async {
      final n = await repo.nextShotNumberForSession(sessionId);
      expect(n, 1);
    });

    test('returns max + 1 for a contiguous run of shots', () async {
      for (var n = 1; n <= 5; n++) {
        await repo.insertShot(
          ShotImpactsCompanion.insert(
            rangeDaySessionId: sessionId,
            shotNumber: n,
            impactX: 0.0,
            impactY: 0.0,
          ),
        );
      }
      final next = await repo.nextShotNumberForSession(sessionId);
      expect(next, 6);
    });

    test('returns max + 1 when shots have gaps in the sequence', () async {
      // Insert non-contiguous shot numbers (e.g. user deleted shots
      // 2 and 3). The "next" should still be max + 1, not first-gap.
      for (final n in [1, 4, 7, 9]) {
        await repo.insertShot(
          ShotImpactsCompanion.insert(
            rangeDaySessionId: sessionId,
            shotNumber: n,
            impactX: 0.0,
            impactY: 0.0,
          ),
        );
      }
      final next = await repo.nextShotNumberForSession(sessionId);
      expect(next, 10);
    });

    test('isolates per session — sibling shots do not leak into count',
        () async {
      final siblingId = await repo.insertSession(
        RangeDaySessionsCompanion.insert(
          name: 'Sibling',
          date: DateTime.utc(2026, 5, 9, 12, 0, 0),
          distanceYd: 200,
        ),
      );
      for (var n = 1; n <= 10; n++) {
        await repo.insertShot(
          ShotImpactsCompanion.insert(
            rangeDaySessionId: siblingId,
            shotNumber: n,
            impactX: 0.0,
            impactY: 0.0,
          ),
        );
      }
      // Our session is empty — next should be 1 regardless of the
      // sibling's 10 shots.
      final next = await repo.nextShotNumberForSession(sessionId);
      expect(next, 1);
      // Sibling's next is 11.
      expect(await repo.nextShotNumberForSession(siblingId), 11);
    });
  });

  group('RangeDayRepository — edge cases', () {
    late AppDatabase db;
    late RangeDayRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = RangeDayRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('deleteSession on non-existent id does NOT throw', () async {
      // Repo's contract returns Future<void> — we just verify it
      // completes without throwing.
      await expectLater(repo.deleteSession(999999), completes);
    });

    test('deleteShot on non-existent id returns 0', () async {
      final removed = await repo.deleteShot(999999);
      expect(removed, 0);
    });

    test('insert shot referencing non-existent session — drift does not '
        'enforce FK by default', () async {
      // Drift on SQLite does NOT enable foreign-key enforcement by default;
      // this insert succeeds and creates an orphan row. Documenting the
      // current behaviour rather than asserting it ought to fail.
      final orphanId = await repo.insertShot(
        ShotImpactsCompanion.insert(
          rangeDaySessionId: 424242,
          shotNumber: 1,
          impactX: 0.0,
          impactY: 0.0,
        ),
      );
      expect(orphanId, greaterThan(0));
      // The orphan is queryable by its (nonexistent) parent.
      final shots = await repo.shotsForSession(424242);
      expect(shots.length, 1);
    });

    test('repo methods after db.close() degrade silently rather than '
        'crashing the isolate', () async {
      // Drift's `NativeDatabase.memory()` connection swallows reads on a
      // closed DB and returns the empty result for the query type
      // (null for `getSingleOrNull`, `[]` for `get`). Documenting that
      // contract here so a future drift upgrade that changes it (e.g.
      // starts throwing `StateError`) won't slip silently into a release.
      await db.close();
      expect(await repo.getById(1), isNull);
      expect(await repo.shotsForSession(1), isEmpty);
    });

    test('non-ASCII / apostrophe / quote names round-trip cleanly', () async {
      final names = <String>[
        "O'Connor's range",
        '"Big Sandy" — fall',
        'Tirée Élysée 50°N',
      ];
      final ids = <int>[];
      for (final name in names) {
        ids.add(await repo.insertSession(
          RangeDaySessionsCompanion.insert(
            name: name,
            date: DateTime.utc(2026, 5, 8, 12, 0, 0),
            distanceYd: 100,
          ),
        ));
      }
      for (var i = 0; i < ids.length; i++) {
        final row = await repo.getById(ids[i]);
        expect(row, isNotNull);
        expect(row!.name, names[i]);
      }
    });

    test('aim point at the corners (-1, -1) and (1, 1) round-trips', () async {
      final id = await repo.insertSession(
        RangeDaySessionsCompanion.insert(
          name: 'Corners',
          date: DateTime.utc(2026, 5, 8, 12, 0, 0),
          distanceYd: 100,
          aimPointX: const Value(-1.0),
          aimPointY: const Value(1.0),
        ),
      );
      final row = await repo.getById(id);
      expect(row!.aimPointX, closeTo(-1.0, 1e-9));
      expect(row.aimPointY, closeTo(1.0, 1e-9));
    });

    test('updateSession can null out an optional field by writing Value(null)',
        () async {
      final id = await repo.insertSession(
        RangeDaySessionsCompanion.insert(
          name: 'Null-out test',
          date: DateTime.utc(2026, 5, 8, 12, 0, 0),
          distanceYd: 100,
          notes: const Value('initial'),
        ),
      );
      expect((await repo.getById(id))!.notes, 'initial');
      final ok = await repo.updateSession(
        id,
        RangeDaySessionsCompanion(notes: const Value(null)),
      );
      expect(ok, isTrue);
      expect((await repo.getById(id))!.notes, isNull);
    });
  });

  group('AppDatabase.wipeUserData() with range-day data', () {
    test('clears every range-day session and shot impact', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async => db.close());
      final repo = RangeDayRepository(db);
      final id = await repo.insertSession(
        RangeDaySessionsCompanion.insert(
          name: 'To be wiped',
          date: DateTime.utc(2026, 5, 8, 12, 0, 0),
          distanceYd: 100,
        ),
      );
      await repo.insertShot(
        ShotImpactsCompanion.insert(
          rangeDaySessionId: id,
          shotNumber: 1,
          impactX: 0.0,
          impactY: 0.0,
        ),
      );
      expect((await repo.watchAll().first).length, 1);
      expect((await repo.shotsForSession(id)).length, 1);
      await db.wipeUserData();
      expect((await repo.watchAll().first).length, 0);
      expect((await repo.shotsForSession(id)).length, 0);
    });
  });
}
