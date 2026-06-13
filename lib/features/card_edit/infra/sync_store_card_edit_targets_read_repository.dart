import 'package:knit/app/app_graph.dart';
import 'package:knit/features/card_edit/domain/card_edit_failure.dart';
import 'package:knit/features/card_edit/domain/card_edit_models.dart';
import 'package:knit/features/card_edit/domain/card_edit_targets_read_repository.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [CardEditTargetsReadRepository] over the graph's [SyncStore]: every live
/// collection (via `readAll`) plus its cards (via `feed`), built into the
/// two-level picker tree. The card being edited is dropped from the card lists
/// so a card can't link to itself.
class SyncStoreCardEditTargetsReadRepository
    implements CardEditTargetsReadRepository {
  SyncStoreCardEditTargetsReadRepository({required AppGraph graph})
      : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<List<CardLinkCollectionTargets>, CardEditFailure>> loadTargets({
    required String excludeCardId,
  }) async {
    try {
      final store = _graph.store;
      final tree = <CardLinkCollectionTargets>[];
      final collections = await store.readAll(EntityType.collection);
      for (final col in collections) {
        if (col.deleted) continue;
        final cards = <CardLinkOption>[];
        for (final card in await store.feed(col.id)) {
          if (card.deleted || card.id == excludeCardId) continue;
          cards.add(
            CardLinkOption(
              kind: ConnectedEntityKind.card,
              id: card.id,
              label: endpointLabel(card),
            ),
          );
        }
        tree.add(
          CardLinkCollectionTargets(
            collection: CardLinkOption(
              kind: ConnectedEntityKind.collection,
              id: col.id,
              label: endpointLabel(col),
            ),
            cards: cards,
          ),
        );
      }
      return Ok(tree);
    } catch (e) {
      return Failure(CardEditReadFailure(e.toString()));
    }
  }
}
