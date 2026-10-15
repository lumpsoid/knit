import 'package:knit/core/storage/domain/storage_context.dart';
import 'package:knit/core/storage/infra/sqflite/sqlite_storage_context.dart';
import 'package:knit/sync/storage/quarantine/domain/domain.dart';
import 'package:sqflite/sqflite.dart';

/// sqflite-backed [QuarantineStorage] over the `quarantine` table (spec §6.7).
class SqfliteQuarantineStorage implements QuarantineStorage {
  SqfliteQuarantineStorage({required Database db}) : _db = db;

  final Database _db;

  DatabaseExecutor _exec(StorageContext? ctx) =>
      ctx is SqliteStorageContext ? ctx.executor : _db;

  @override
  Future<void> ensureSchema({StorageContext? ctx}) =>
      _exec(ctx).execute(QuarantineSchema.createTable);

  @override
  Future<void> add(QuarantinedOp op, {StorageContext? ctx}) async {
    await _exec(ctx).insert(
      QuarantineSchema.table,
      op.toDb(),
      conflictAlgorithm: ConflictAlgorithm.ignore, // re-seen op_id ignored
    );
  }

  @override
  Future<List<QuarantinedOp>> readAll({StorageContext? ctx}) async {
    final rows = await _exec(ctx).query(QuarantineSchema.table);
    return rows.map(QuarantinedOp.fromDb).toList();
  }

  @override
  Future<void> remove(String opId, {StorageContext? ctx}) => _exec(ctx).delete(
    QuarantineSchema.table,
    where: '${QuarantineSchema.colOpId} = ?',
    whereArgs: [opId],
  );

  @override
  Future<void> clear({StorageContext? ctx}) =>
      _exec(ctx).delete(QuarantineSchema.table);
}
