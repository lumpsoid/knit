import 'package:knit/app/app_graph.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection_media/domain/collection_media_failure.dart';
import 'package:knit/features/collection_media/domain/collection_media_models.dart';
import 'package:knit/features/collection_media/domain/collection_media_read_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [CollectionMediaReadRepository] over the graph's [SyncStore]: walks the
/// collection's feed (§8.7) and keeps the cards [MediaItem.fromCard] classifies
/// as media. Audio/file cards resolve their (tiny) attachment metadata record for
/// the name + size label, as the Collection feed read does.
class SyncStoreCollectionMediaReadRepository
    implements CollectionMediaReadRepository {
  SyncStoreCollectionMediaReadRepository({required AppGraph graph})
    : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<CollectionMedia, CollectionMediaFailure>> loadMedia(
    String collectionId,
  ) async {
    try {
      final store = _graph.store;
      final items = <MediaItem>[];
      for (final card in await store.feed(collectionId)) {
        if (card.deleted) continue;
        final kind = CardKind.fromTag(card.content['kind'] as String?);
        final attachmentId = card.content['attachment_id'] as String?;
        String? fileName;
        int? fileSize;
        if ((kind == CardKind.file || kind == CardKind.audio) &&
            attachmentId != null) {
          final att = await store.get(EntityType.attachment, attachmentId);
          if (att != null && !att.deleted) {
            fileName = att.content[AttachmentSchema.colName] as String?;
            fileSize = att.content[AttachmentSchema.colSize] as int?;
          }
        }
        final item = MediaItem.fromCard(
          cardId: card.id,
          cardKind: kind,
          capturedAt: DateTime.fromMillisecondsSinceEpoch(card.createdAt),
          text: card.content['text'] as String?,
          attachmentId: attachmentId,
          moreAttachmentIds: CardSchema.decodeMoreAttachmentIds(
            card.content[CardSchema.colMoreAttachmentIds],
          ),
          fileName: fileName,
          fileSize: fileSize,
        );
        if (item != null) items.add(item);
      }
      return Ok(CollectionMedia(items));
    } catch (e, st) {
      return Failure(CollectionMediaLoadFailure(e, st));
    }
  }
}
