import 'package:knit/app/app_graph.dart';
import 'package:knit/features/card_edit/domain/card_edit_failure.dart';
import 'package:knit/features/card_edit/domain/card_edit_links_read_repository.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [CardEditLinksReadRepository] over the graph's [SyncStore]: the card's
/// links-out via [SyncStore.linksOut] (§4.4), each far endpoint's liveness via
/// the canonical §8.6.1 derivation [SyncStore.linkStatus] (the
/// [BrokenLinkResolver]). Builds the same [ConnectionItem] shape the Connections
/// view renders, restricted to [ConnectionDirection.outgoing].
class SyncStoreCardEditLinksReadRepository
    implements CardEditLinksReadRepository {
  SyncStoreCardEditLinksReadRepository({required AppGraph graph})
    : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<List<ConnectionItem>, CardEditFailure>> linksOf(
    String cardId,
  ) async {
    try {
      final store = _graph.store;
      final items = <ConnectionItem>[];
      for (final link in await store.linksOut(cardId)) {
        final status = await store.linkStatus(link);
        final otherKind = ConnectedEntityKind.fromTag(
          link.content['target_type'] as String?,
        );
        final otherId = link.content['target_id'] as String;
        final broken = status.targetBroken;
        final other = broken
            ? null
            : await store.get(_entityType(otherKind), otherId);
        items.add(
          ConnectionItem(
            linkId: link.id,
            direction: ConnectionDirection.outgoing,
            otherKind: otherKind,
            otherId: otherId,
            broken: broken,
            label: other == null ? null : endpointLabel(other),
          ),
        );
      }
      return Ok(items);
    } catch (e, st) {
      return Failure(CardEditReadFailure(e, st));
    }
  }

  EntityType _entityType(ConnectedEntityKind kind) => switch (kind) {
    ConnectedEntityKind.collection => EntityType.collection,
    ConnectedEntityKind.card => EntityType.card,
    // Unknown endpoints are already marked broken, so this table is unread.
    ConnectedEntityKind.unknown => EntityType.collection,
  };
}
