/// The small "→ Trips" chips under a card that links out but is not a
/// Connection card (§4.2): one per link out, to a collection, a card, or a
/// broken target. A read-time view; nothing about it is stored or synced.
library;

import 'package:flutter/foundation.dart';
import 'package:knit/features/collection/domain/link_tile.dart';
import 'package:knit/features/connections/domain/connections_models.dart';

/// A live linked collection, as its chip needs it.
typedef LinkedCollection = ({String title, bool archived});

/// A live linked card in a live collection, as its chip needs it: its `kind`
/// tag, its preview ([CardLinkTile.previewOf]), its collection, and whether
/// that collection is archived.
typedef LinkedCard = ({
  String kind,
  String? preview,
  String collectionId,
  bool archived,
});

/// One link out of a card, as a chip under its bubble (§4.2). Primitives only
/// (widgets.md §1).
@immutable
sealed class LinkChip {
  const LinkChip();

  /// The chips for a card's [linksOut] (one per pair, oldest first): live
  /// targets first, then broken ones, each group in link order. None when
  /// [hasTile]: the Connection card's tile already stands for its one link.
  /// A target found in [collections] or [cards] (the live ones, by id) is a
  /// chip to it; any other target is deleted (or its collection is) and gets
  /// a [BrokenLinkChip].
  static List<LinkChip> allOf({
    required List<CardLinkOut> linksOut,
    required bool hasTile,
    required Map<String, LinkedCollection> collections,
    required Map<String, LinkedCard> cards,
  }) {
    if (hasTile) return const [];
    final live = <LinkChip>[];
    final broken = <LinkChip>[];
    for (final link in linksOut.toSet()) {
      final chip = switch (link.targetKind) {
        ConnectedEntityKind.collection => switch (collections[link.targetId]) {
          final c? => CollectionLinkChip(
            collectionId: link.targetId,
            title: c.title,
            archived: c.archived,
          ),
          null => null,
        },
        ConnectedEntityKind.card => switch (cards[link.targetId]) {
          final c? => CardLinkChip(
            cardId: link.targetId,
            cardKind: c.kind,
            collectionId: c.collectionId,
            preview: c.preview,
            archived: c.archived,
          ),
          null => null,
        },
        ConnectedEntityKind.unknown => null,
      };
      chip == null ? broken.add(const BrokenLinkChip()) : live.add(chip);
    }
    return [...live, ...broken];
  }

  /// Where a tap on the chip goes from the feed of [hereCollectionId].
  LinkTileOpen openFrom(String hereCollectionId);
}

/// "→ Trips": a link to a live collection.
final class CollectionLinkChip extends LinkChip {
  const CollectionLinkChip({
    required this.collectionId,
    required this.title,
    this.archived = false,
  });

  final String collectionId;

  /// The target's title (blank ⇒ shown as untitled).
  final String title;

  /// Whether the target is archived (§3.4): the chip is then muted.
  final bool archived;

  @override
  LinkTileOpen openFrom(String hereCollectionId) =>
      OpenLinkedCollection(collectionId);

  @override
  bool operator ==(Object other) =>
      other is CollectionLinkChip &&
      other.collectionId == collectionId &&
      other.title == title &&
      other.archived == archived;

  @override
  int get hashCode => Object.hash(collectionId, title, archived);
}

/// "→ Lisbon": a link to a live card, named by its first line.
final class CardLinkChip extends LinkChip {
  const CardLinkChip({
    required this.cardId,
    required this.cardKind,
    required this.collectionId,
    this.preview,
    this.archived = false,
  });

  final String cardId;

  /// The target's `kind` tag, for its kind label when [preview] is null.
  final String cardKind;
  final String collectionId;

  /// The target's text, else its file name; null ⇒ its kind label.
  final String? preview;

  /// Whether the target's collection is archived (§3.4): the chip is muted.
  final bool archived;

  /// Like [CardLinkTile.openFrom]: revealed in place when it is in this feed,
  /// else its collection opens focused on it.
  @override
  LinkTileOpen openFrom(String hereCollectionId) =>
      collectionId == hereCollectionId
      ? RevealCardHere(cardId)
      : OpenLinkedCollection(collectionId, focusCardId: cardId);

  @override
  bool operator ==(Object other) =>
      other is CardLinkChip &&
      other.cardId == cardId &&
      other.cardKind == cardKind &&
      other.collectionId == collectionId &&
      other.preview == preview &&
      other.archived == archived;

  @override
  int get hashCode =>
      Object.hash(cardId, cardKind, collectionId, preview, archived);
}

/// "→ unavailable": a link whose target is deleted (§8.6.1). A tap opens the
/// card's Connections, where the link can be cleared.
final class BrokenLinkChip extends LinkChip {
  const BrokenLinkChip();

  @override
  LinkTileOpen openFrom(String hereCollectionId) => const ShowCardConnections();

  @override
  bool operator ==(Object other) => other is BrokenLinkChip;

  @override
  int get hashCode => (BrokenLinkChip).hashCode;
}

/// The chips one card row shows (§4.2): at most [maxShown], then a "+N" chip
/// for the [more] that don't fit, which opens the card's Connections.
@immutable
class LinkChipRow {
  const LinkChipRow({required this.shown, this.more = 0});

  /// The row for a card's [chips], in their order.
  factory LinkChipRow.of(List<LinkChip> chips) => chips.length <= maxShown
      ? LinkChipRow(shown: chips)
      : LinkChipRow(
          shown: chips.sublist(0, maxShown),
          more: chips.length - maxShown,
        );

  /// The most chips a row shows before "+N".
  static const int maxShown = 2;

  final List<LinkChip> shown;

  /// How many chips the "+N" chip stands for; zero ⇒ no such chip.
  final int more;

  bool get isEmpty => shown.isEmpty;

  /// Where the "+N" chip goes.
  static const LinkTileOpen moreOpen = ShowCardConnections();
}
