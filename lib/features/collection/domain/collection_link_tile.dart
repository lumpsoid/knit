/// The rich tile a collection-link card is drawn as in the feed (§4.2): a card
/// whose one job is to point at another collection shows that collection —
/// cover, title, card count, newest card — instead of a plain bubble. A
/// read-time view; nothing about it is stored or synced.
library;

import 'package:flutter/foundation.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/connections/domain/connections_models.dart';

/// One live link out of a card: what kind of node it points at, and which.
typedef CardLinkOut = ({ConnectedEntityKind targetKind, String targetId});

/// What a collection-link tile shows. Primitives only (widgets.md §1).
@immutable
class CollectionLinkTile {
  const CollectionLinkTile({
    required this.collectionId,
    required this.title,
    required this.cardCount,
    this.coverAttachmentId,
    this.lastCardKind,
    this.lastCardText,
    this.lastCardSettled = false,
    this.caption,
  });

  /// The tile for a card whose text is [cardText], pointing at a collection
  /// with these header fields and home-row counters (§8.6.3). [lastCardKind]
  /// is null when that collection has no cards yet.
  factory CollectionLinkTile.of({
    required String? cardText,
    required String collectionId,
    required String title,
    required int cardCount,
    String? coverAttachmentId,
    String? lastCardKind,
    String? lastCardText,
    bool lastCardSettled = false,
  }) => CollectionLinkTile(
    collectionId: collectionId,
    title: title,
    cardCount: cardCount,
    coverAttachmentId: coverAttachmentId,
    lastCardKind: lastCardKind,
    lastCardText: lastCardText,
    lastCardSettled: lastCardSettled,
    caption: _captionOf(cardText, title),
  );

  /// The longest card text that still reads as the tile's label, not a note.
  static const int maxLabelLength = 80;

  /// The collection a card links to *as its whole purpose*, or null when the
  /// card is anything more (§4.2). That card has no attachment and exactly one
  /// live link out, to a collection; its text is blank or one short line (a
  /// label, up to [maxLabelLength] characters). A link card qualifies only
  /// without text, since its text is the URL it opens. Whether the target is
  /// still live is the caller's to check: a broken one gets no tile.
  static String? targetOf({
    required CardKind kind,
    required String? text,
    required List<String> attachmentIds,
    required List<CardLinkOut> linksOut,
  }) {
    if (attachmentIds.isNotEmpty || linksOut.length != 1) return null;
    final link = linksOut.single;
    if (link.targetKind != ConnectedEntityKind.collection) return null;
    final label = text?.trim() ?? '';
    final isLabel = switch (kind) {
      CardKind.text => label.length <= maxLabelLength && !label.contains('\n'),
      CardKind.link => label.isEmpty,
      _ => false,
    };
    return isLabel ? link.targetId : null;
  }

  final String collectionId;

  /// The target's title (blank ⇒ shown as untitled).
  final String title;
  final int cardCount;
  final String? coverAttachmentId;

  /// The target's newest card (§8.6.3): its `kind` tag and text, and whether
  /// it is settled (the preview is then muted). Kind null ⇒ no cards yet.
  final String? lastCardKind;
  final String? lastCardText;
  final bool lastCardSettled;

  /// The card's own text, shown above the tile when it says more than the
  /// target's title; null when blank or the same (ignoring case).
  final String? caption;

  static String? _captionOf(String? cardText, String title) {
    final text = cardText?.trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == title.trim().toLowerCase()) {
      return null;
    }
    return text;
  }

  @override
  bool operator ==(Object other) =>
      other is CollectionLinkTile &&
      other.collectionId == collectionId &&
      other.title == title &&
      other.cardCount == cardCount &&
      other.coverAttachmentId == coverAttachmentId &&
      other.lastCardKind == lastCardKind &&
      other.lastCardText == lastCardText &&
      other.lastCardSettled == lastCardSettled &&
      other.caption == caption;

  @override
  int get hashCode => Object.hash(
    collectionId,
    title,
    cardCount,
    coverAttachmentId,
    lastCardKind,
    lastCardText,
    lastCardSettled,
    caption,
  );
}
