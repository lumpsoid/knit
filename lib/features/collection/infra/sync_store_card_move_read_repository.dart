import 'package:knit/app/app_graph.dart';
import 'package:knit/features/collection/domain/card_move_read_repository.dart';
import 'package:knit/features/collection/domain/collection_failure.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:result_dart/result_dart.dart';

/// [CardMoveReadRepository] over the graph's [SyncStore]: the targets from the
/// home timeline (§8.6.3), the tail from a one-row feed page (§8.7).
class SyncStoreCardMoveReadRepository implements CardMoveReadRepository {
  SyncStoreCardMoveReadRepository({required AppGraph graph}) : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<List<MoveTarget>, CollectionFailure>> loadMoveTargets() async {
    try {
      final summaries = await _graph.store.homeTimeline();
      return Ok([
        for (final s in summaries)
          MoveTarget(collectionId: s.collectionId, title: s.title),
      ]);
    } catch (e, st) {
      return Failure(CollectionLoadFailure(e, st));
    }
  }

  @override
  Future<Result<String?, CollectionFailure>> lastCardPosition(
    String collectionId,
  ) async {
    try {
      final newest = await _graph.store.feedPage(collectionId, limit: 1);
      return Ok(newest.isEmpty ? null : newest.first.position);
    } catch (e, st) {
      return Failure(CollectionLoadFailure(e, st));
    }
  }
}
