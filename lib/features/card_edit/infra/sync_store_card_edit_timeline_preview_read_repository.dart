import 'package:knit/app/app_graph.dart';
import 'package:knit/features/card_edit/domain/card_edit_failure.dart';
import 'package:knit/features/card_edit/domain/card_edit_timeline_preview_read_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [CardEditTimelinePreviewReadRepository] over the graph's [SyncStore]: picks
/// the collection's previewed card with the same [latestCard] rule the §8.6.3
/// home-timeline derivation uses, so the two can never disagree.
class SyncStoreCardEditTimelinePreviewReadRepository
    implements CardEditTimelinePreviewReadRepository {
  SyncStoreCardEditTimelinePreviewReadRepository({required AppGraph graph})
    : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<bool, CardEditFailure>> isTimelinePreview({
    required String cardId,
    required String collectionId,
  }) async {
    try {
      final liveCards = await _graph.store.feed(collectionId);
      return Ok(latestCard(liveCards)?.id == cardId);
    } catch (e, st) {
      return Failure(CardEditReadFailure(e, st));
    }
  }
}
