import 'package:drift/drift.dart';

import '../database/database.dart';

/// Repository for user-saved recipes (load records).
///
/// Note: the underlying Drift table is still named `user_loads` /
/// [UserLoads] / [UserLoadRow] / [UserLoadsCompanion] for compatibility.
/// User-facing terminology says "recipe"; the schema kept its original
/// names to avoid a migration.
class RecipeRepository {
  RecipeRepository(this.db);
  final AppDatabase db;

  Stream<List<UserLoadRow>> watchAll() =>
      (db.select(db.userLoads)..orderBy([(l) => OrderingTerm.desc(l.updatedAt)]))
          .watch();

  Future<UserLoadRow?> getById(int id) =>
      (db.select(db.userLoads)..where((l) => l.id.equals(id)))
          .getSingleOrNull();

  Future<int> insert(UserLoadsCompanion entry) =>
      db.into(db.userLoads).insert(entry);

  Future<bool> update(int id, UserLoadsCompanion entry) =>
      (db.update(db.userLoads)..where((l) => l.id.equals(id)))
          .write(entry.copyWith(updatedAt: Value(DateTime.now())))
          .then((rows) => rows > 0);

  Future<int> delete(int id) =>
      (db.delete(db.userLoads)..where((l) => l.id.equals(id))).go();
}
