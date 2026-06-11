import 'package:knit/app/app_graph.dart';
import 'package:knit/features/collection/domain/collection_failure.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/domain/collection_read_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [CollectionReadRepository] over the graph's [SyncStore]: the header via
/// [SyncStore.get], the ordered feed via [SyncStore.feed] (§8.7), and the
/// link-finder candidates via [SyncStore.homeTimeline] (the device's other
/// live collections).
class SyncStoreCollectionReadRepository implements CollectionReadRepository {
  SyncStoreCollectionReadRepository({required AppGraph graph}) : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<CollectionData, CollectionFailure>> loadCollection(
    String id,
  ) async {
    try {
      final store = _graph.store;
      final header = await store.get(EntityType.collection, id);
      if (header == null || header.deleted) {
        return const Failure(
          CollectionLoadFailure('collection not found'),
        );
      }

      final cards = [
        for (final card in await store.feed(id))
          FeedCard(
            id: card.id,
            kind: CardKind.fromTag(card.content['kind'] as String?),
            position: card.position!,
            text: card.content['text'] as String?,
            attachmentId: card.content['attachment_id'] as String?,
          ),
      ];

      final linkTargets = [
        for (final c in await store.homeTimeline())
          if (c.collectionId != id)
            LinkCandidate(collectionId: c.collectionId, title: c.title),
      ];

      return Ok(
        CollectionData(
          collectionId: id,
          title: header.content['title'] as String? ?? '',
          coverAttachmentId: header.content['cover_attachment_id'] as String?,
          cards: cards,
          linkTargets: linkTargets,
        ),
      );
    } catch (e) {
      return Failure(CollectionLoadFailure(e.toString()));
    }
  }
}
