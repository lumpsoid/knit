import 'package:knit/app/app_graph.dart';
import 'package:knit/features/connections/domain/connections_failure.dart';
import 'package:knit/features/connections/domain/connections_write_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [ConnectionsWriteRepository] over the graph's [SyncStore] §6.8 write path.
/// Clearing a broken link is one signed local delete of the `link` record,
/// committed in a single transaction (§8.5); the endpoints are never touched.
class SyncStoreConnectionsWriteRepository
    implements ConnectionsWriteRepository {
  SyncStoreConnectionsWriteRepository({required AppGraph graph})
      : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<String, ConnectionsFailure>> clearLink(String linkId) async {
    try {
      await _graph.store.delete(EntityType.link, linkId);
      return Ok(linkId);
    } catch (e, st) {
      return Failure(ConnectionsWriteFailure(e, st));
    }
  }
}
