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
        return const Failure(CollectionLoadFailure('collection not found'));
      }

      final cards = <FeedCard>[];
      for (final card in await store.feed(id)) {
        final kind = CardKind.fromTag(card.content['kind'] as String?);
        final attachmentId = card.content['attachment_id'] as String?;
        // A file card needs its attachment's name + size to label the chip;
        // resolve the (tiny) metadata record eagerly so the feed renders it
        // without a per-card bytes load (unlike image thumbnails).
        String? fileName;
        int? fileSize;
        if (kind == CardKind.file && attachmentId != null) {
          final att = await store.get(EntityType.attachment, attachmentId);
          if (att != null && !att.deleted) {
            fileName = att.content[AttachmentSchema.colName] as String?;
            fileSize = att.content[AttachmentSchema.colSize] as int?;
          }
        }
        cards.add(
          FeedCard(
            id: card.id,
            kind: kind,
            position: card.position!,
            text: card.content['text'] as String?,
            attachmentId: attachmentId,
            fileName: fileName,
            fileSize: fileSize,
          ),
        );
      }

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
