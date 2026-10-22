import 'package:knit/features/card_links/domain/card_links_failure.dart';
import 'package:knit/features/card_links/domain/card_links_models.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow write port for card links (§4.4, business_logic.md §5). Each call is
/// one signed local write (§8.5). Links are neutral (no label here) and point
/// at a generic entity: [ConnectedEntityKind.collection] or a card.
abstract interface class CardLinksWriteRepository {
  /// Create a link from the [sourceKind] entity [sourceId] (a card, or for an
  /// Undo of a collection's link, a collection) to the [targetKind] entity
  /// [targetId].
  /// One link per pair (§6.4): when one already joins them, nothing is written.
  /// Returns the id of the link that joins them.
  Future<Result<String, CardLinksFailure>> addLink({
    required ConnectedEntityKind sourceKind,
    required String sourceId,
    required ConnectedEntityKind targetKind,
    required String targetId,
  });

  /// Link each card of [sourceIds] to the [targetKind] entity [targetId], all
  /// in one transaction. Pairs already linked, and repeats, are skipped
  /// (§6.4); [LinksAdded.count] says how many links were written.
  Future<Result<LinksAdded, CardLinksFailure>> addLinks({
    required List<String> sourceIds,
    required ConnectedEntityKind targetKind,
    required String targetId,
  });

  /// Create a collection titled [title] and link each card of [sourceIds] to
  /// it, all in one transaction (§4.4 "New collection"). [LinksAdded.targetId]
  /// is the new collection's id.
  Future<Result<LinksAdded, CardLinksFailure>> addLinksToNewCollection({
    required List<String> sourceIds,
    required String title,
  });

  /// Delete the link [linkId] and every duplicate of its pair (§6.4) — both
  /// endpoints are left untouched. Also how a broken link (§8.6.1) is cleared.
  Future<Result<String, CardLinksFailure>> removeLink(String linkId);
}
