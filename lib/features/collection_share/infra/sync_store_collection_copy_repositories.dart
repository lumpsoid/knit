import 'package:knit/app/app_graph.dart';
import 'package:knit/core/ids/id_generator.dart';
import 'package:knit/features/collection_share/domain/collection_copy_repositories.dart';
import 'package:knit/features/collection_share/domain/collection_share_failure.dart';
import 'package:knit/features/collection_share/domain/fork_planner.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [CollectionForkRepository] over the graph's [SyncStore]: reads the live
/// rows of the collection, plans the copy with the pure [ForkPlanner] and
/// writes it through [SyncStore.forkCollection].
class SyncStoreCollectionForkRepository implements CollectionForkRepository {
  SyncStoreCollectionForkRepository({
    required AppGraph graph,
    required IdGenerator ids,
  }) : _graph = graph,
       _planner = ForkPlanner(ids: ids);

  final AppGraph _graph;
  final ForkPlanner _planner;

  @override
  Future<Result<String, CollectionShareFailure>> fork(
    String collectionId,
  ) async {
    try {
      final store = _graph.store;
      final collection = await store.get(EntityType.collection, collectionId);
      if (collection == null || collection.deleted) {
        return Failure(CollectionForkFailure('no collection $collectionId'));
      }
      final cards = await store.feed(collectionId);
      final sources = {collectionId, for (final c in cards) c.id};
      final links = [
        for (final l in await store.readAll(EntityType.link))
          if (!l.deleted && sources.contains(l.content[LinkSchema.colSourceId]))
            l,
      ];
      final attachmentIds = {
        ?collection.content[CollectionSchema.colCoverAttachmentId] as String?,
        for (final c in cards)
          ?c.content[CardSchema.colAttachmentId] as String?,
      };
      final attachments = [
        for (final a in await store.getMany(
          EntityType.attachment,
          attachmentIds,
        ))
          if (!a.deleted) a,
      ];
      final plan = _planner.plan(
        ForkSource(
          collection: collection,
          cards: cards,
          links: links,
          attachments: attachments,
        ),
      );
      await store.forkCollection(plan);
      return Ok(plan.collectionId);
    } catch (e, st) {
      return Failure(CollectionForkFailure(e, st));
    }
  }
}

/// [CollectionPurgeRepository] over the graph's [SyncStore] and blob store:
/// [SyncStore.purgeCollection] in one transaction, then the blobs nothing
/// references any more (the `DeviceEraser` path).
class SyncStoreCollectionPurgeRepository implements CollectionPurgeRepository {
  SyncStoreCollectionPurgeRepository({required AppGraph graph})
    : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<void, CollectionShareFailure>> purge(
    String collectionId,
  ) async {
    try {
      final orphans = await _graph.store.purgeCollection(collectionId);
      for (final hash in orphans) {
        await _graph.blobStore.delete(hash);
      }
      return const Ok<void, CollectionShareFailure>(null);
    } catch (e, st) {
      return Failure(CollectionPurgeFailure(e, st));
    }
  }
}
