import 'package:knit/app/app_graph.dart';
import 'package:knit/features/collection/domain/link_tile.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/features/timeline/domain/timeline_connection_preview.dart';
import 'package:knit/features/timeline/domain/timeline_failure.dart';
import 'package:knit/features/timeline/domain/timeline_read_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [TimelineReadRepository] over the graph's [SyncStore.homeTimeline] derivation
/// (§8.6.3), with each Connection card preview's target (§4.1) resolved in two
/// batched reads: the newest cards' links out, then the card targets.
class SyncStoreTimelineRepository implements TimelineReadRepository {
  SyncStoreTimelineRepository({required AppGraph graph}) : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<List<CollectionSummary>, TimelineFailure>>
  loadTimeline() async {
    try {
      final store = _graph.store;
      final summaries = await store.homeTimeline();
      final candidates = TimelineConnectionPreview.candidates(summaries);
      if (candidates.isEmpty) return Ok(summaries);
      final linksOut = <String, List<CardLinkOut>>{};
      for (final link in await store.linksOutOf(candidates)) {
        (linksOut[link.content[LinkSchema.colSourceId] as String] ??= []).add((
          targetKind: ConnectedEntityKind.fromTag(
            link.content[LinkSchema.colTargetType] as String?,
          ),
          targetId: link.content[LinkSchema.colTargetId] as String,
        ));
      }
      final live = {for (final s in summaries) s.collectionId};
      final cards = <String, PreviewedCard>{
        for (final card in await store.getMany(EntityType.card, {
          for (final links in linksOut.values)
            for (final l in links)
              if (l.targetKind == ConnectedEntityKind.card) l.targetId,
        }))
          if (!card.deleted && live.contains(card.content['collection_id']))
            card.id: (
              kind: card.content['kind'] as String? ?? 'text',
              text: card.content['text'] as String?,
            ),
      };
      return Ok(
        TimelineConnectionPreview.attach(
          summaries,
          linksOut: linksOut,
          cards: cards,
        ),
      );
    } catch (e, st) {
      return Failure(TimelineLoadFailure(e, st));
    }
  }
}
