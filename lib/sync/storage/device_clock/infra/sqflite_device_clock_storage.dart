import 'package:knit/core/storage/domain/storage_context.dart';
import 'package:knit/core/storage/infra/sqflite/sqlite_storage_context.dart';
import 'package:knit/sync/hlc.dart';
import 'package:knit/sync/storage/device_clock/domain/domain.dart';
import 'package:sqflite/sqflite.dart';

/// sqflite-backed [DeviceClockStorage] over the single-row `device_clock` table.
class SqfliteDeviceClockStorage implements DeviceClockStorage {
  SqfliteDeviceClockStorage({required Database db}) : _db = db;

  final Database _db;

  DatabaseExecutor _exec(StorageContext? ctx) =>
      ctx is SqliteStorageContext ? ctx.executor : _db;

  @override
  Future<void> ensureSchema({StorageContext? ctx}) =>
      _exec(ctx).execute(DeviceClockSchema.createTable);

  @override
  Future<Hlc?> load({StorageContext? ctx}) async {
    final rows = await _exec(ctx).query(
      DeviceClockSchema.table,
      where: '${DeviceClockSchema.colId} = ?',
      whereArgs: [DeviceClockSchema.rowId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return Hlc(
      row[DeviceClockSchema.colHlcMs]! as int,
      row[DeviceClockSchema.colHlcCounter]! as int,
    );
  }

  @override
  Future<void> save(Hlc clock, {StorageContext? ctx}) async {
    await _exec(ctx).insert(
      DeviceClockSchema.table,
      {
        DeviceClockSchema.colId: DeviceClockSchema.rowId,
        DeviceClockSchema.colHlcMs: clock.ms,
        DeviceClockSchema.colHlcCounter: clock.counter,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> clear({StorageContext? ctx}) =>
      _exec(ctx).delete(DeviceClockSchema.table);
}
