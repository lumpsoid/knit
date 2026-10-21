import 'package:knit/sync/merge.dart';
import 'package:knit/sync/snapshot.dart';
import 'package:knit/sync/storage/change_log/domain/domain.dart';
import 'package:knit/sync/storage/projection/domain/domain.dart';

/// The entities one collection's share covers (docs/collection_share.md "The
/// share set"), read off the projection. Pure, so the share and the purge
/// scope the same way.
class ShareScope {
  const ShareScope._({
    required this.collectionId,
    required this.cardIds,
    required this.liveCardIds,
    required this.linkIds,
    required this.attachmentIds,
  });

  /// The scope of [collectionId] over every projected row in [rows]
  /// (tombstones included):
  /// - every card whose current `collection_id` is the collection, live or not
  /// - every link sourced at the collection or one of those cards
  /// - every attachment referenced by the collection's cover or by a card
  ///   (tombstoned cards included, so a purge leaves none behind)
  factory ShareScope.of(String collectionId, Iterable<Snapshot> rows) {
    final cards = rows
        .where(
          (s) =>
              s.type == EntityType.card &&
              s.content[CardSchema.colCollectionId] == collectionId,
        )
        .toList(growable: false);
    final cardIds = {for (final c in cards) c.id};
    final sources = {collectionId, ...cardIds};
    final collection = rows
        .where((s) => s.type == EntityType.collection && s.id == collectionId)
        .firstOrNull;
    final cover =
        collection?.content[CollectionSchema.colCoverAttachmentId] as String?;
    return ShareScope._(
      collectionId: collectionId,
      cardIds: cardIds,
      liveCardIds: {
        for (final c in cards)
          if (!c.deleted) c.id,
      },
      linkIds: {
        for (final s in rows)
          if (s.type == EntityType.link &&
              sources.contains(s.content[LinkSchema.colSourceId]))
            s.id,
      },
      attachmentIds: {
        ?cover,
        for (final c in cards) ...CardSchema.attachmentIdsOf(c.content),
      },
    );
  }

  final String collectionId;
  final Set<String> cardIds;
  final Set<String> liveCardIds;
  final Set<String> linkIds;
  final Set<String> attachmentIds;

  /// Every entity id in the scope (profiles are not part of it).
  Set<String> get entityIds => {
    collectionId,
    ...cardIds,
    ...linkIds,
    ...attachmentIds,
  };
}

/// Picks the ops a share ships: per entity, the content winner and, for a
/// card, the placement winner when that is a different op (§7.6) — the same
/// comparators the merge-core uses, so applying the picks yields the sender's
/// projection. Never re-signs: the picks are the original ops, verbatim.
class ShareSetSelector {
  const ShareSetSelector();

  /// The winning ops among [ops], in their given order.
  List<PersistedOp> winners(Iterable<PersistedOp> ops) {
    final byEntity = <String, List<(PersistedOp, Snapshot)>>{};
    for (final op in ops) {
      (byEntity[op.entityId] ??= []).add((op, op.toSnapshot()));
    }
    final picked = <String>{};
    for (final candidates in byEntity.values) {
      final content = candidates.reduce(
        (a, b) => compareContent(b.$2, a.$2) > 0 ? b : a,
      );
      picked.add(content.$1.opId);
      if (content.$2.isCard) {
        // Start from the content winner: an edit carries its placement
        // forward, so on a tie that one op covers both clocks.
        var placement = content;
        for (final c in candidates) {
          if (comparePlacement(c.$2, placement.$2) > 0) placement = c;
        }
        picked.add(placement.$1.opId);
      }
    }
    return [
      for (final op in ops)
        if (picked.remove(op.opId)) op,
    ];
  }
}

/// One collection's share, ready to package: the winning signed [ops]
/// (collection, cards, links, attachments and the authors' profiles) plus what
/// the export sheet and manifest show.
class ShareSet {
  const ShareSet({
    required this.collection,
    required this.liveCardCount,
    required this.ops,
    required this.media,
  });

  /// The collection's projected row.
  final Snapshot collection;

  /// Live cards in the collection.
  final int liveCardCount;

  /// The signed ops, verbatim, in `seq` order.
  final List<PersistedOp> ops;

  /// The live attachments' bytes to ship: `content_hash` → size in bytes
  /// (null when the attachment record carries none).
  final Map<String, int?> media;
}
