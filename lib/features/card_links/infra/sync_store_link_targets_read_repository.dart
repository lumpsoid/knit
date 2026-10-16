import 'package:knit/app/app_graph.dart';
import 'package:knit/features/card_links/domain/card_links_failure.dart';
import 'package:knit/features/card_links/domain/card_links_models.dart';
import 'package:knit/features/card_links/domain/link_targets_read_repository.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [LinkTargetsReadRepository] over the graph's [SyncStore]: the collections
/// via [SyncStore.readAll], a collection's cards via [SyncStore.feed] — one
/// level per call, as the picker drills.
class SyncStoreLinkTargetsReadRepository implements LinkTargetsReadRepository {
  SyncStoreLinkTargetsReadRepository({required AppGraph graph})
    : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<List<LinkTarget>, CardLinksFailure>> loadCollections() =>
      _read(() async {
        return [
          for (final col in await _graph.store.readAll(EntityType.collection))
            if (!col.deleted)
              LinkTarget(
                kind: ConnectedEntityKind.collection,
                id: col.id,
                label: endpointLabel(col),
              ),
        ];
      });

  @override
  Future<Result<List<LinkTarget>, CardLinksFailure>> loadCards(
    String collectionId,
  ) => _read(() async {
    return [
      for (final card in await _graph.store.feed(collectionId))
        if (!card.deleted)
          LinkTarget(
            kind: ConnectedEntityKind.card,
            id: card.id,
            label: endpointLabel(card),
          ),
    ];
  });

  Future<Result<List<LinkTarget>, CardLinksFailure>> _read(
    Future<List<LinkTarget>> Function() op,
  ) async {
    try {
      return Ok(await op());
    } catch (e, st) {
      return Failure(CardLinksReadFailure(e, st));
    }
  }
}
