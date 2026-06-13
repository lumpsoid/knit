import 'package:knit/app/app_graph.dart';
import 'package:knit/features/timeline/domain/timeline_failure.dart';
import 'package:knit/features/timeline/domain/timeline_read_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [TimelineReadRepository] over the graph's [SyncStore.homeTimeline] derivation
/// (§8.6.3).
class SyncStoreTimelineRepository implements TimelineReadRepository {
  SyncStoreTimelineRepository({required AppGraph graph}) : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<List<CollectionSummary>, TimelineFailure>>
      loadTimeline() async {
    try {
      return Ok(await _graph.store.homeTimeline());
    } catch (e, st) {
      return Failure(TimelineLoadFailure(e, st));
    }
  }
}
