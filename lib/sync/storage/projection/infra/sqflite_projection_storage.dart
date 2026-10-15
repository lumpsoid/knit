import 'package:knit/core/storage/domain/storage_context.dart';
import 'package:knit/core/storage/infra/sqflite/sqlite_storage_context.dart';
import 'package:knit/sync/snapshot.dart';
import 'package:knit/sync/storage/projection/domain/domain.dart';
import 'package:knit/sync/storage/projection/infra/projection_row_mapper.dart';
import 'package:sqflite/sqflite.dart';

/// sqflite-backed [ProjectionStorage] over the §6.4 entity tables. Routes each
/// snapshot to its table via [ProjectionTables]/[ProjectionRowMapper].
class SqfliteProjectionStorage implements ProjectionStorage {
  SqfliteProjectionStorage({required Database db}) : _db = db;

  final Database _db;

  DatabaseExecutor _exec(StorageContext? ctx) =>
      ctx is SqliteStorageContext ? ctx.executor : _db;

  @override
  Future<void> ensureSchema({StorageContext? ctx}) async {
    final db = _exec(ctx);
    for (final ddl in ProjectionTables.createStatements) {
      await db.execute(ddl);
    }
  }

  @override
  Future<Snapshot?> get(
    EntityType type,
    String id, {
    StorageContext? ctx,
  }) async {
    final rows = await _exec(ctx).query(
      ProjectionTables.of(type),
      where: '${EnvelopeColumns.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : ProjectionRowMapper.fromRow(type, rows.first);
  }

  @override
  Future<void> upsert(Snapshot snapshot, {StorageContext? ctx}) async {
    await _exec(ctx).insert(
      ProjectionTables.of(snapshot.type),
      ProjectionRowMapper.toRow(snapshot),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<Snapshot>> readAll({StorageContext? ctx}) async {
    final db = _exec(ctx);
    final out = <Snapshot>[];
    for (final type in ProjectionTables.all) {
      final rows = await db.query(ProjectionTables.of(type));
      out.addAll(rows.map((r) => ProjectionRowMapper.fromRow(type, r)));
    }
    return out;
  }

  @override
  Future<List<Snapshot>> feed(
    String collectionId, {
    StorageContext? ctx,
  }) async {
    final rows = await _exec(ctx).query(
      CardSchema.table,
      where:
          '${CardSchema.colCollectionId} = ? AND ${EnvelopeColumns.colDeleted} = 0',
      whereArgs: [collectionId],
      // spec §8.7 — position lexicographic, id (UUIDv7) breaks ties.
      orderBy: '${CardSchema.colPosition} ASC, ${EnvelopeColumns.colId} ASC',
    );
    return rows
        .map((r) => ProjectionRowMapper.fromRow(EntityType.card, r))
        .toList();
  }

  @override
  Future<List<Snapshot>> backlinks(
    String targetId, {
    StorageContext? ctx,
  }) async {
    final rows = await _exec(ctx).query(
      LinkSchema.table,
      where:
          '${LinkSchema.colTargetId} = ? AND ${EnvelopeColumns.colDeleted} = 0',
      whereArgs: [targetId],
    );
    return rows
        .map((r) => ProjectionRowMapper.fromRow(EntityType.link, r))
        .toList();
  }

  @override
  Future<List<Snapshot>> linksOut(
    String sourceId, {
    StorageContext? ctx,
  }) async {
    final rows = await _exec(ctx).query(
      LinkSchema.table,
      where:
          '${LinkSchema.colSourceId} = ? AND ${EnvelopeColumns.colDeleted} = 0',
      whereArgs: [sourceId],
    );
    return rows
        .map((r) => ProjectionRowMapper.fromRow(EntityType.link, r))
        .toList();
  }

  @override
  Future<void> clear({StorageContext? ctx}) async {
    final db = _exec(ctx);
    for (final type in ProjectionTables.all) {
      await db.delete(ProjectionTables.of(type));
    }
  }
}
