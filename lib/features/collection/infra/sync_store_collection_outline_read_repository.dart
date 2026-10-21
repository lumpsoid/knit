import 'package:knit/app/app_graph.dart';
import 'package:knit/features/collection/domain/collection_failure.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/domain/collection_outline_read_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [CollectionOutlineReadRepository] over the graph's [SyncStore]: the whole
/// feed in one [SyncStore.feedPage] read (§8.7), plus one batched read of the
/// file and audio cards' attachment records for their names. No link counts.
class SyncStoreCollectionOutlineReadRepository
    implements CollectionOutlineReadRepository {
  SyncStoreCollectionOutlineReadRepository({required AppGraph graph})
    : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<List<FeedCard>, CollectionFailure>> loadOutlineCards(
    String collectionId,
  ) async {
    try {
      final store = _graph.store;
      final rows = (await store.feedPage(collectionId)).reversed.toList();
      final metaIds = <String>{
        for (final card in rows)
          if (_isNamed(card)) ?card.content['attachment_id'] as String?,
      };
      final names = {
        for (final att in await store.getMany(EntityType.attachment, metaIds))
          if (!att.deleted)
            att.id: att.content[AttachmentSchema.colName] as String?,
      };
      return Ok([
        for (final card in rows)
          FeedCard(
            id: card.id,
            kind: CardKind.fromTag(card.content['kind'] as String?),
            position: card.position!,
            text: card.content['text'] as String?,
            attachmentId: card.content['attachment_id'] as String?,
            fileName: _isNamed(card)
                ? names[card.content['attachment_id']]
                : null,
            settledAt: card.content[CardSchema.colSettledAt] as int?,
            emphasizedAt: card.content[CardSchema.colEmphasizedAt] as int?,
          ),
      ]);
    } catch (e, st) {
      return Failure(CollectionLoadFailure(e, st));
    }
  }

  /// Whether [card] is labelled by its attachment's file name.
  static bool _isNamed(Snapshot card) =>
      switch (CardKind.fromTag(card.content['kind'] as String?)) {
        CardKind.file || CardKind.audio => true,
        _ => false,
      };
}
