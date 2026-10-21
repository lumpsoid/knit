import 'package:knit/app/app_graph.dart';
import 'package:knit/features/timeline/domain/timeline_failure.dart';
import 'package:knit/features/timeline/domain/timeline_hub_read_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [TimelineHubReadRepository] over the graph's [SyncStore.collectionHubs]
/// derivation (§8.6.4): one batched backlink read for the whole home list.
class SyncStoreTimelineHubRepository implements TimelineHubReadRepository {
  SyncStoreTimelineHubRepository({required AppGraph graph}) : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<Map<String, List<CollectionHub>>, TimelineFailure>> loadHubs(
    Iterable<CollectionSummary> collections,
  ) async {
    try {
      return Ok(
        await _graph.store.collectionHubs([
          for (final c in collections) c.collectionId,
        ]),
      );
    } catch (e, st) {
      return Failure(TimelineLoadFailure(e, st));
    }
  }
}
