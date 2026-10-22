import 'package:knit/sync/snapshot.dart';
import 'package:knit/sync/storage/derivations/link_pairs.dart';
import 'package:knit/sync/storage/projection/domain/domain.dart';
import 'package:knit/sync/storage/share/share_set.dart';

/// Where one collection's share points outside itself
/// (docs/collection_share.md "Linked collections"): its live links, one per
/// pair (§6.4), sourced at the collection or a live card, whose target lies
/// outside the [ShareScope]. Pure, so the export sheet's warning and the
/// bundled set agree.
class ShareReach {
  const ShareReach({
    required this.outsideCount,
    required this.notOwnedCount,
    required this.linkedCollectionIds,
  });

  /// The reach of [scope] over every projected row in [rows]. A target's
  /// collection is the target itself, or a card target's collection, so a
  /// card arrives inside its context. Only a live collection created by [me]
  /// is offered for bundling, one level deep; one created by someone else
  /// (imported) counts as [notOwnedCount]. A target already missing or
  /// deleted here counts as outside, but is neither.
  factory ShareReach.of(
    ShareScope scope,
    Iterable<Snapshot> rows, {
    required String? me,
  }) {
    final collections = <String, Snapshot>{};
    final cards = <String, Snapshot>{};
    final links = <Snapshot>[];
    for (final s in rows) {
      switch (s.type) {
        case EntityType.collection:
          collections[s.id] = s;
        case EntityType.card:
          cards[s.id] = s;
        case EntityType.link:
          links.add(s);
        case EntityType.profile || EntityType.attachment:
          break;
      }
    }
    final sources = {scope.collectionId, ...scope.liveCardIds};
    final inside = {scope.collectionId, ...scope.cardIds};

    var outside = 0;
    var notOwned = 0;
    final linked = <String>{};
    for (final link in distinctLinks(
      links.where((l) => sources.contains(l.content[LinkSchema.colSourceId])),
    )) {
      final targetId = link.content[LinkSchema.colTargetId] as String?;
      if (targetId == null || inside.contains(targetId)) continue;
      outside++;
      final collectionId =
          link.content[LinkSchema.colTargetType] == EntityType.card.name
          ? switch (cards[targetId]) {
              final card? when !card.deleted =>
                card.content[CardSchema.colCollectionId] as String?,
              _ => null,
            }
          : targetId;
      final collection = collections[collectionId];
      if (collection == null || collection.deleted) continue;
      if (collection.createdBy == me) {
        linked.add(collection.id);
      } else {
        notOwned++;
      }
    }
    return ShareReach(
      outsideCount: outside,
      notOwnedCount: notOwned,
      linkedCollectionIds: linked.toList(growable: false),
    );
  }

  /// Nothing points outside.
  static const ShareReach none = ShareReach(
    outsideCount: 0,
    notOwnedCount: 0,
    linkedCollectionIds: [],
  );

  /// Live connections (one per pair) whose target lies outside the scope.
  final int outsideCount;

  /// Of those, the ones whose target collection is not this identity's own:
  /// never bundled, they stay broken links for the recipient.
  final int notOwnedCount;

  /// The own collections the outside links reach (card targets by their
  /// collection), deduped, in link order — what "Include linked collections"
  /// bundles.
  final List<String> linkedCollectionIds;
}
