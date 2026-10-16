import 'package:knit/app/app_graph.dart';
import 'package:knit/features/collection_widget/domain/collection_widget_failure.dart';
import 'package:knit/features/collection_widget/domain/collection_widget_models.dart';
import 'package:knit/features/collection_widget/domain/collection_widget_read_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [CollectionWidgetReadRepository] over the graph's [SyncStore]: the picker's
/// targets from the home timeline (§8.6.3), the bound titles from one batched
/// read of the collection rows (tombstones skipped).
class SyncStoreCollectionWidgetReadRepository
    implements CollectionWidgetReadRepository {
  SyncStoreCollectionWidgetReadRepository({required AppGraph graph})
    : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<List<CollectionWidgetTarget>, CollectionWidgetFailure>>
  loadTargets() async {
    try {
      final summaries = await _graph.store.homeTimeline();
      return Ok([
        for (final s in summaries)
          CollectionWidgetTarget(collectionId: s.collectionId, title: s.title),
      ]);
    } catch (e, st) {
      return Failure(CollectionWidgetLoadFailure(e, st));
    }
  }

  @override
  Future<Result<Map<String, String>, CollectionWidgetFailure>> liveTitles(
    Set<String> collectionIds,
  ) async {
    if (collectionIds.isEmpty) return const Ok({});
    try {
      final rows = await _graph.store.getMany(
        EntityType.collection,
        collectionIds,
      );
      return Ok({
        for (final row in rows)
          if (!row.deleted) row.id: (row.content['title'] as String?) ?? '',
      });
    } catch (e, st) {
      return Failure(CollectionWidgetLoadFailure(e, st));
    }
  }
}
