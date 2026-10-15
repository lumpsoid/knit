import 'package:knit/core/storage/domain/storage_context.dart';
import 'package:knit/core/storage/infra/sqflite/sqlite_storage_context.dart';
import 'package:knit/sync/storage/change_log/domain/domain.dart';
import 'package:sqflite/sqflite.dart';

/// sqflite-backed [ChangeLogStorage]. Resolves its executor from the ambient
/// [SqliteStorageContext] when present (so an append can ride the same
/// transaction as the entity write and clock advance), else uses the default db.
class SqfliteChangeLogStorage implements ChangeLogStorage {
  SqfliteChangeLogStorage({required Database db}) : _db = db;

  final Database _db;

  DatabaseExecutor _exec(StorageContext? ctx) =>
      ctx is SqliteStorageContext ? ctx.executor : _db;

  @override
  Future<void> ensureSchema({StorageContext? ctx}) =>
      _exec(ctx).execute(ChangeLogSchema.createTable);

  @override
  Future<bool> hasOp(String opId, {StorageContext? ctx}) async {
    final rows = await _exec(ctx).query(
      ChangeLogSchema.table,
      columns: [ChangeLogSchema.colSeq],
      where: '${ChangeLogSchema.colOpId} = ?',
      whereArgs: [opId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> append(PersistedOp op, {StorageContext? ctx}) async {
    // op_id is UNIQUE; a duplicate is a true resend (spec §7.3) → ignore.
    await _exec(ctx).insert(
      ChangeLogSchema.table,
      op.toDb(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<List<PersistedOp>> readOrdered({StorageContext? ctx}) async {
    final rows = await _exec(
      ctx,
    ).query(ChangeLogSchema.table, orderBy: '${ChangeLogSchema.colSeq} ASC');
    return rows.map(PersistedOp.fromDb).toList();
  }

  @override
  Future<List<PersistedOp>> readPending({StorageContext? ctx}) async {
    final rows = await _exec(ctx).query(
      ChangeLogSchema.table,
      where:
          '${ChangeLogSchema.colOrigin} = ? AND ${ChangeLogSchema.colAcked} = 0',
      whereArgs: [SyncOrigin.local.toDb()],
      orderBy: '${ChangeLogSchema.colSeq} ASC',
    );
    return rows.map(PersistedOp.fromDb).toList();
  }

  @override
  Future<int> pendingCount({StorageContext? ctx}) async {
    final rows = await _exec(ctx).rawQuery(
      'SELECT COUNT(*) AS c FROM ${ChangeLogSchema.table} '
      'WHERE ${ChangeLogSchema.colOrigin} = ? AND ${ChangeLogSchema.colAcked} = 0',
      [SyncOrigin.local.toDb()],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  @override
  Future<void> markAcked(String opId, {StorageContext? ctx}) async {
    await _exec(ctx).update(
      ChangeLogSchema.table,
      {ChangeLogSchema.colAcked: 1},
      where: '${ChangeLogSchema.colOpId} = ?',
      whereArgs: [opId],
    );
  }

  @override
  Future<void> clear({StorageContext? ctx}) =>
      _exec(ctx).delete(ChangeLogSchema.table);
}
