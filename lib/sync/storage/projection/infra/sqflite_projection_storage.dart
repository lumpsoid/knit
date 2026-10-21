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
    for (final ddl in [
      ...ProjectionTables.createStatements,
      ...ProjectionTables.indexStatements,
    ]) {
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
  Future<List<Snapshot>> feedPage(
    String collectionId, {
    FeedKey? before,
    FeedKey? atOrAfter,
    int? limit,
    StorageContext? ctx,
  }) async {
    const pos = CardSchema.colPosition;
    const id = EnvelopeColumns.colId;
    final where = [
      '${CardSchema.colCollectionId} = ?',
      '${EnvelopeColumns.colDeleted} = 0',
      // Expanded keyset compare (no row-value syntax: older Android SQLite).
      if (before != null) '($pos < ? OR ($pos = ? AND $id < ?))',
      if (atOrAfter != null) '($pos > ? OR ($pos = ? AND $id >= ?))',
    ];
    final rows = await _exec(ctx).query(
      CardSchema.table,
      where: where.join(' AND '),
      whereArgs: [
        collectionId,
        if (before != null) ...[before.position, before.position, before.id],
        if (atOrAfter != null) ...[
          atOrAfter.position,
          atOrAfter.position,
          atOrAfter.id,
        ],
      ],
      orderBy: '$pos DESC, $id DESC',
      limit: limit,
    );
    return rows
        .map((r) => ProjectionRowMapper.fromRow(EntityType.card, r))
        .toList();
  }

  @override
  Future<List<Snapshot>> getMany(
    EntityType type,
    Iterable<String> ids, {
    StorageContext? ctx,
  }) async {
    final db = _exec(ctx);
    final out = <Snapshot>[];
    for (final chunk in _chunks(ids.toSet().toList(), _maxInArgs)) {
      final rows = await db.query(
        ProjectionTables.of(type),
        where: '${EnvelopeColumns.colId} IN (${_marks(chunk.length)})',
        whereArgs: chunk,
      );
      out.addAll(rows.map((r) => ProjectionRowMapper.fromRow(type, r)));
    }
    return out;
  }

  @override
  Future<void> deleteMany(
    EntityType type,
    Iterable<String> ids, {
    StorageContext? ctx,
  }) async {
    final db = _exec(ctx);
    for (final chunk in _chunks(ids.toSet().toList(), _maxInArgs)) {
      await db.delete(
        ProjectionTables.of(type),
        where: '${EnvelopeColumns.colId} IN (${_marks(chunk.length)})',
        whereArgs: chunk,
      );
    }
  }

  @override
  Future<Map<String, int>> linkCounts(
    Iterable<String> entityIds, {
    StorageContext? ctx,
  }) async {
    final db = _exec(ctx);
    final counts = <String, int>{};
    // Each chunk binds its ids twice (source side + target side).
    for (final chunk in _chunks(entityIds.toSet().toList(), _maxInArgs ~/ 2)) {
      final marks = _marks(chunk.length);
      final rows = await db.rawQuery(
        'SELECT eid, COUNT(*) AS n FROM ('
        'SELECT ${LinkSchema.colSourceId} AS eid FROM ${LinkSchema.table} '
        'WHERE ${EnvelopeColumns.colDeleted} = 0 '
        'AND ${LinkSchema.colSourceId} IN ($marks) '
        'UNION ALL '
        'SELECT ${LinkSchema.colTargetId} AS eid FROM ${LinkSchema.table} '
        'WHERE ${EnvelopeColumns.colDeleted} = 0 '
        'AND ${LinkSchema.colTargetId} IN ($marks)'
        ') GROUP BY eid',
        [...chunk, ...chunk],
      );
      for (final r in rows) {
        counts[r['eid']! as String] = r['n']! as int;
      }
    }
    return counts;
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
  Future<List<Snapshot>> linksOutOf(
    Iterable<String> sourceIds, {
    StorageContext? ctx,
  }) => _liveWhereIn(EntityType.link, LinkSchema.colSourceId, sourceIds, ctx);

  @override
  Future<List<Snapshot>> backlinksTo(
    Iterable<String> targetIds, {
    StorageContext? ctx,
  }) => _liveWhereIn(EntityType.link, LinkSchema.colTargetId, targetIds, ctx);

  @override
  Future<List<Snapshot>> liveCardsIn(
    Iterable<String> collectionIds, {
    StorageContext? ctx,
  }) => _liveWhereIn(
    EntityType.card,
    CardSchema.colCollectionId,
    collectionIds,
    ctx,
  );

  /// The live rows of [type] whose [column] is one of [values], read in
  /// chunks under the bound-parameter budget.
  Future<List<Snapshot>> _liveWhereIn(
    EntityType type,
    String column,
    Iterable<String> values,
    StorageContext? ctx,
  ) async {
    final db = _exec(ctx);
    final out = <Snapshot>[];
    for (final chunk in _chunks(values.toSet().toList(), _maxInArgs)) {
      final rows = await db.query(
        ProjectionTables.of(type),
        where:
            '$column IN (${_marks(chunk.length)}) '
            'AND ${EnvelopeColumns.colDeleted} = 0',
        whereArgs: chunk,
      );
      out.addAll(rows.map((r) => ProjectionRowMapper.fromRow(type, r)));
    }
    return out;
  }

  @override
  Future<void> clear({StorageContext? ctx}) async {
    final db = _exec(ctx);
    for (final type in ProjectionTables.all) {
      await db.delete(ProjectionTables.of(type));
    }
  }
}
