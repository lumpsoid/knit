import 'package:knit/app/app_graph.dart';
import 'package:knit/core/ids/id_generator.dart';
import 'package:knit/features/timeline/domain/timeline_failure.dart';
import 'package:knit/features/timeline/domain/timeline_write_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [TimelineWriteRepository] over the graph's [SyncStore]: mints an id via the
/// injected [IdGenerator] (§6.1) and writes the signed `collection` record
/// (§7.4.1) through the §6.8 local write path.
class SyncStoreTimelineWriteRepository implements TimelineWriteRepository {
  SyncStoreTimelineWriteRepository({
    required AppGraph graph,
    required IdGenerator ids,
  })  : _graph = graph,
        _ids = ids;

  final AppGraph _graph;
  final IdGenerator _ids;

  @override
  Future<Result<String, TimelineFailure>> createCollection(
    String title,
  ) async {
    try {
      final id = _ids.newId();
      await _graph.store.create(
        EntityType.collection,
        id,
        {'title': title, 'cover_attachment_id': null},
      );
      return Ok(id);
    } catch (e, st) {
      return Failure(TimelineWriteFailure(e, st));
    }
  }

  @override
  Future<Result<String, TimelineFailure>> deleteCollection(
    String collectionId,
  ) async {
    try {
      await _graph.store.delete(EntityType.collection, collectionId);
      return Ok(collectionId);
    } catch (e, st) {
      return Failure(TimelineWriteFailure(e, st));
    }
  }
}
