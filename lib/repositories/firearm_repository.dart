import 'package:drift/drift.dart';

import '../database/database.dart';

class FirearmRepository {
  FirearmRepository(this.db);
  final AppDatabase db;

  Stream<List<UserFirearmRow>> watchAll() =>
      (db.select(db.userFirearms)..orderBy([(f) => OrderingTerm.asc(f.name)]))
          .watch();

  Future<UserFirearmRow?> getById(int id) =>
      (db.select(db.userFirearms)..where((f) => f.id.equals(id)))
          .getSingleOrNull();

  Future<int> insert(UserFirearmsCompanion entry) =>
      db.into(db.userFirearms).insert(entry);

  Future<bool> update(int id, UserFirearmsCompanion entry) =>
      (db.update(db.userFirearms)..where((f) => f.id.equals(id)))
          .write(entry.copyWith(updatedAt: Value(DateTime.now())))
          .then((rows) => rows > 0);

  Future<int> delete(int id) =>
      (db.delete(db.userFirearms)..where((f) => f.id.equals(id))).go();

  /// Increment shots fired by [delta] (can be negative).
  Future<void> adjustShotsFired(int id, int delta) async {
    final current = await getById(id);
    if (current == null) return;
    final next = (current.shotsFired + delta).clamp(0, 1 << 31);
    await (db.update(db.userFirearms)..where((f) => f.id.equals(id))).write(
      UserFirearmsCompanion(
        shotsFired: Value(next),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
