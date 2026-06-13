import 'package:knit/app/app_graph.dart';
import 'package:knit/features/sync_status/domain/sync_status_failure.dart';
import 'package:knit/features/sync_status/domain/sync_status_read_repository.dart';
import 'package:result_dart/result_dart.dart';

/// [SyncStatusReadRepository] over the graph's [SyncStore.pendingCount] (§6.6) —
/// local ops with `change_log.acked = 0`.
class SyncStoreSyncStatusReadRepository implements SyncStatusReadRepository {
  SyncStoreSyncStatusReadRepository({required AppGraph graph}) : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<int, SyncStatusFailure>> pendingCount() async {
    try {
      return Ok(await _graph.store.pendingCount());
    } catch (e) {
      return Failure(SyncStatusReadFailure(e.toString()));
    }
  }
}
