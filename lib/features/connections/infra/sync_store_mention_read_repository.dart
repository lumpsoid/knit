import 'package:knit/app/app_graph.dart';
import 'package:knit/core/ownership/collection_ownership.dart';
import 'package:knit/features/connections/domain/connections_failure.dart';
import 'package:knit/features/connections/domain/mention_read_repository.dart';
import 'package:knit/features/connections/domain/unlinked_mentions.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [MentionReadRepository] over the graph's [SyncStore]: the whole corpus, as
/// Search reads it — every live card with text in a live collection, flagged
/// with whether its collection is this identity's own ([CollectionOwnership]) —
/// plus the sources of the live card links to the focused collection.
class SyncStoreMentionReadRepository implements MentionReadRepository {
  SyncStoreMentionReadRepository({required AppGraph graph}) : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<MentionCorpus, ConnectionsFailure>> loadMentionCorpus(
    String collectionId,
  ) async {
    try {
      final store = _graph.store;
      final me = await store.authorPubkey();
      final collections = {
        for (final c in await store.readAll(EntityType.collection))
          if (!c.deleted) c.id: c,
      };
      final cards = <MentionCandidate>[];
      for (final card in await store.readAll(EntityType.card)) {
        if (card.deleted) continue;
        final col = collections[card.content[CardSchema.colCollectionId]];
        final text = card.content['text'] as String?;
        if (col == null || text == null || text.trim().isEmpty) continue;
        cards.add(
          MentionCandidate(
            cardId: card.id,
            collectionId: col.id,
            collectionTitle: col.content['title'] as String? ?? '',
            text: text,
            updatedAtMs: card.hlc.ms,
            canLink: CollectionOwnership.of(col.createdBy, me).canEdit,
          ),
        );
      }
      return Ok(
        MentionCorpus(
          cards: cards,
          linkedCardIds: {
            for (final link in await store.backlinks(collectionId))
              if (link.content['source_type'] == EntityType.card.name)
                link.content['source_id'] as String,
          },
        ),
      );
    } catch (e, st) {
      return Failure(ConnectionsLoadFailure(e, st));
    }
  }
}
