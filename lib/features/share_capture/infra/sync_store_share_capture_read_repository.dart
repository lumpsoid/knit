import 'package:knit/app/app_graph.dart';
import 'package:knit/core/ownership/collection_ownership.dart';
import 'package:knit/features/share_capture/domain/share_capture_failure.dart';
import 'package:knit/features/share_capture/domain/share_capture_models.dart';
import 'package:knit/features/share_capture/domain/share_capture_read_repository.dart';
import 'package:result_dart/result_dart.dart';

/// [ShareCaptureReadRepository] over the graph's [SyncStore]: the targets from
/// the home timeline (§8.6.3) minus the imported, read-only collections (no
/// card can be written there), the tail from a one-row feed page (§8.7).
class SyncStoreShareCaptureReadRepository
    implements ShareCaptureReadRepository {
  SyncStoreShareCaptureReadRepository({required AppGraph graph})
    : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<List<ShareTarget>, ShareCaptureFailure>> loadTargets() async {
    try {
      final store = _graph.store;
      final summaries = await store.homeTimeline();
      final me = await store.authorPubkey();
      return Ok([
        for (final s in summaries)
          if (CollectionOwnership.of(s.createdBy, me).canEdit)
            ShareTarget(collectionId: s.collectionId, title: s.title),
      ]);
    } catch (e, st) {
      return Failure(ShareCaptureLoadFailure(e, st));
    }
  }

  @override
  Future<Result<String?, ShareCaptureFailure>> lastCardPosition(
    String collectionId,
  ) async {
    try {
      final newest = await _graph.store.feedPage(collectionId, limit: 1);
      return Ok(newest.isEmpty ? null : newest.first.position);
    } catch (e, st) {
      return Failure(ShareCaptureLoadFailure(e, st));
    }
  }
}
