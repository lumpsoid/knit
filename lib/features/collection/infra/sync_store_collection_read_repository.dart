import 'package:knit/app/app_graph.dart';
import 'package:knit/features/collection/domain/collection_failure.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/domain/collection_read_repository.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [CollectionReadRepository] over the graph's [SyncStore]: the header via
/// [SyncStore.get], the ordered feed via [SyncStore.feed] (§8.7), and the
/// link-finder targets via [SyncStore.readAll] (collections) + [SyncStore.feed]
/// (a collection's cards), loaded lazily per level by the page.
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

      return Ok(
        CollectionData(
          collectionId: id,
          title: header.content['title'] as String? ?? '',
          coverAttachmentId: header.content['cover_attachment_id'] as String?,
          cards: cards,
        ),
      );
    } catch (e, st) {
      return Failure(CollectionLoadFailure(e, st));
    }
  }

  @override
  Future<Result<List<LinkOption>, CollectionFailure>>
      loadLinkCollections() async {
    try {
      final store = _graph.store;
      final options = [
        for (final col in await store.readAll(EntityType.collection))
          if (!col.deleted)
            LinkOption(
              kind: ConnectedEntityKind.collection,
              id: col.id,
              label: endpointLabel(col),
            ),
      ];
      return Ok(options);
    } catch (e, st) {
      return Failure(CollectionLoadFailure(e, st));
    }
  }

  @override
  Future<Result<List<LinkOption>, CollectionFailure>> loadCollectionCards(
    String collectionId,
  ) async {
    try {
      final store = _graph.store;
      final options = [
        for (final card in await store.feed(collectionId))
          if (!card.deleted)
            LinkOption(
              kind: ConnectedEntityKind.card,
              id: card.id,
              label: endpointLabel(card),
            ),
      ];
      return Ok(options);
    } catch (e, st) {
      return Failure(CollectionLoadFailure(e, st));
    }
  }
}
