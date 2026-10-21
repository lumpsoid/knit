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
  Future<List<PersistedOp>> readForEntities(
    Iterable<String> entityIds, {
    StorageContext? ctx,
  }) async {
    final db = _exec(ctx);
    final out = <PersistedOp>[];
    for (final chunk in _chunks(entityIds.toSet().toList(), _maxInArgs)) {
      final rows = await db.query(
        ChangeLogSchema.table,
        where: '${ChangeLogSchema.colEntityId} IN (${_marks(chunk.length)})',
        whereArgs: chunk,
      );
      out.addAll(rows.map(PersistedOp.fromDb));
    }
    // Chunks each come back in seq order; merge them into one.
    return out..sort((a, b) => a.seq!.compareTo(b.seq!));
  }

  @override
  Future<void> deleteForEntities(
    Iterable<String> entityIds, {
    StorageContext? ctx,
  }) async {
    final db = _exec(ctx);
    for (final chunk in _chunks(entityIds.toSet().toList(), _maxInArgs)) {
      await db.delete(
        ChangeLogSchema.table,
        where: '${ChangeLogSchema.colEntityId} IN (${_marks(chunk.length)})',
        whereArgs: chunk,
      );
    }
  }

  /// Bound-parameter budget per `IN (…)` query — under SQLite's historic
  /// 999-variable limit, which older Android builds still enforce.
  static const int _maxInArgs = 800;

  static String _marks(int n) => List.filled(n, '?').join(', ');

  static Iterable<List<T>> _chunks<T>(List<T> items, int size) sync* {
    for (var i = 0; i < items.length; i += size) {
      yield items.sublist(i, i + size > items.length ? items.length : i + size);
    }
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
