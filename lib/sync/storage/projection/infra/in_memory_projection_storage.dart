import 'package:knit/core/storage/domain/storage_context.dart';
import 'package:knit/sync/snapshot.dart';
import 'package:knit/sync/storage/projection/domain/domain.dart';

/// In-memory [ProjectionStorage] for dev mode and tests — stores [Snapshot]s
/// directly (no row mapping). Mirrors the sqflite impl's read semantics.
class InMemoryProjectionStorage implements ProjectionStorage {
  // type -> (id -> snapshot)
  final Map<EntityType, Map<String, Snapshot>> _tables = {
    for (final t in EntityType.values) t: {},
  };

  @override
  Future<void> ensureSchema({StorageContext? ctx}) async {}

  @override
  Future<Snapshot?> get(
    EntityType type,
    String id, {
    StorageContext? ctx,
  }) async => _tables[type]![id];

  @override
  Future<void> upsert(Snapshot snapshot, {StorageContext? ctx}) async {
    _tables[snapshot.type]![snapshot.id] = snapshot;
  }

  @override
  Future<List<Snapshot>> readAll({StorageContext? ctx}) async => [
    for (final table in _tables.values) ...table.values,
  ];

  @override
  Future<List<Snapshot>> feed(
    String collectionId, {
    StorageContext? ctx,
  }) async {
    final cards = _tables[EntityType.card]!.values.where(
      (s) => !s.deleted && s.content['collection_id'] == collectionId,
    );
    return cards.toList()..sort((a, b) {
      final p = a.position!.compareTo(b.position!);
      return p != 0 ? p : a.id.compareTo(b.id);
    });
  }

  @override
  Future<List<Snapshot>> feedPage(
    String collectionId, {
    FeedKey? before,
    FeedKey? atOrAfter,
    int? limit,
    StorageContext? ctx,
  }) async {
    int cmp(Snapshot s, FeedKey k) {
      final p = s.position!.compareTo(k.position);
      return p != 0 ? p : s.id.compareTo(k.id);
    }

    final page = (await feed(collectionId)).reversed.where(
      (s) =>
          (before == null || cmp(s, before) < 0) &&
          (atOrAfter == null || cmp(s, atOrAfter) >= 0),
    );
    return (limit == null ? page : page.take(limit)).toList();
  }

  @override
  Future<List<Snapshot>> getMany(
    EntityType type,
    Iterable<String> ids, {
    StorageContext? ctx,
  }) async {
    final table = _tables[type]!;
    return [for (final id in ids.toSet()) ?table[id]];
  }

  @override
  Future<Map<String, int>> linkCounts(
    Iterable<String> entityIds, {
    StorageContext? ctx,
  }) async {
    final wanted = entityIds.toSet();
    final counts = <String, int>{};
    void bump(Object? id) {
      if (id is String && wanted.contains(id)) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }

    for (final link in _tables[EntityType.link]!.values) {
      if (link.deleted) continue;
      bump(link.content['source_id']);
      bump(link.content['target_id']);
    }
    return counts;
  }

  @override
  Future<List<Snapshot>> backlinks(
    String targetId, {
    StorageContext? ctx,
  }) async => _tables[EntityType.link]!.values
      .where((s) => !s.deleted && s.content['target_id'] == targetId)
      .toList();

  @override
  Future<List<Snapshot>> linksOut(
    String sourceId, {
    StorageContext? ctx,
  }) async => _tables[EntityType.link]!.values
      .where((s) => !s.deleted && s.content['source_id'] == sourceId)
      .toList();

  @override
  Future<void> clear({StorageContext? ctx}) async {
    for (final table in _tables.values) {
      table.clear();
    }
  }
}
