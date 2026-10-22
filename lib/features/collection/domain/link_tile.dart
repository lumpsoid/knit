/// The rich tile a Connection card is drawn as in the feed (§4.2): a card
/// whose one job is to point at another collection, or at one card, shows
/// that target — a collection's cover, title, card count and newest card, or
/// a card's thumbnail, preview and collection — instead of a plain bubble. A
/// read-time view; nothing about it is stored or synced.
library;

import 'package:flutter/foundation.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/domain/collection_outline.dart';
import 'package:knit/features/connections/domain/connections_models.dart';

/// One live link out of a card: what kind of node it points at, and which.
typedef CardLinkOut = ({ConnectedEntityKind targetKind, String targetId});

/// What a Connection card's tile shows: a [CollectionLinkTile] or a
/// [CardLinkTile]. Primitives only (widgets.md §1).
@immutable
sealed class LinkTile {
  const LinkTile({this.caption});

  /// The longest card text that still reads as the tile's label, not a note.
  static const int maxLabelLength = 80;

  /// The node a card links to *as its whole purpose* — a collection or a card
  /// — or null when the card is anything more (§4.2). That card has no
  /// attachment and exactly one live link out, to a collection or a card
  /// (duplicates of one pair are one link, §6.4); its text is blank or one short line (a label, up to [maxLabelLength]
  /// characters). A link card qualifies only without text, since its text is
  /// the URL it opens. Whether the target is still live is the caller's to
  /// check: a broken one gets no tile.
  static CardLinkOut? targetOf({
    required CardKind kind,
    required String? text,
    required List<String> attachmentIds,
    required List<CardLinkOut> linksOut,
  }) {
    final distinct = linksOut.toSet();
    if (attachmentIds.isNotEmpty || distinct.length != 1) return null;
    final link = distinct.single;
    if (link.targetKind == ConnectedEntityKind.unknown) return null;
    final label = text?.trim() ?? '';
    final isLabel = switch (kind) {
      CardKind.text => label.length <= maxLabelLength && !label.contains('\n'),
      CardKind.link => label.isEmpty,
      _ => false,
    };
    return isLabel ? link : null;
  }

  /// The card's own text, shown above the tile when it says more than the
  /// target's name; null when blank or the same (ignoring case).
  final String? caption;

  /// The image the tile shows (a collection's cover, a card's first image),
  /// or null.
  String? get imageAttachmentId;

  /// Where a tap on the tile goes from the feed of [hereCollectionId].
  LinkTileOpen openFrom(String hereCollectionId);

  static String? _captionOf(String? cardText, String? targetName) {
    final text = cardText?.trim() ?? '';
    if (text.isEmpty ||
        text.toLowerCase() == (targetName ?? '').trim().toLowerCase()) {
      return null;
    }
    return text;
  }
}

/// A tile for a link to a collection (§4.2).
final class CollectionLinkTile extends LinkTile {
  const CollectionLinkTile({
    required this.collectionId,
    required this.title,
    required this.cardCount,
    this.coverAttachmentId,
    this.lastCardKind,
    this.lastCardText,
    this.lastCardSettled = false,
    super.caption,
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
    caption: LinkTile._captionOf(cardText, title),
  );

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

  @override
  String? get imageAttachmentId => coverAttachmentId;

  @override
  LinkTileOpen openFrom(String hereCollectionId) =>
      OpenLinkedCollection(collectionId);

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

/// A tile for a link to one card (§4.2): the target card's first image, a
/// preview of its text (or file name), and the collection it lives in.
final class CardLinkTile extends LinkTile {
  const CardLinkTile({
    required this.cardId,
    required this.cardKind,
    required this.collectionId,
    required this.collectionTitle,
    this.preview,
    this.thumbnailAttachmentId,
    this.settled = false,
    super.caption,
  });

  /// The tile for a card whose text is [cardText], pointing at the card
  /// [cardId] of `kind` tag [cardKind] with [text] (and, for a file or audio
  /// card, [fileName]) in the collection [collectionId] titled
  /// [collectionTitle].
  factory CardLinkTile.of({
    required String? cardText,
    required String cardId,
    required String cardKind,
    required String collectionId,
    required String collectionTitle,
    String? text,
    String? fileName,
    String? thumbnailAttachmentId,
    bool settled = false,
  }) {
    final preview = _previewOf(CardKind.fromTag(cardKind), text, fileName);
    return CardLinkTile(
      cardId: cardId,
      cardKind: cardKind,
      collectionId: collectionId,
      collectionTitle: collectionTitle,
      preview: preview,
      thumbnailAttachmentId: thumbnailAttachmentId,
      settled: settled,
      caption: LinkTile._captionOf(cardText, preview),
    );
  }

  final String cardId;

  /// The target's `kind` tag, for its kind label when [preview] is null.
  final String cardKind;
  final String collectionId;

  /// The target's collection title (blank ⇒ shown as untitled).
  final String collectionTitle;

  /// The target's trimmed text, else its file name (file and audio cards, as
  /// the Outline labels them); null ⇒ the tile shows its kind label.
  final String? preview;

  /// The target's first image (image cards), or null.
  final String? thumbnailAttachmentId;

  /// Whether the target is settled (§3.3): the tile's preview is then muted.
  final bool settled;

  @override
  String? get imageAttachmentId => thumbnailAttachmentId;

  /// A card in this very feed is revealed in place; one elsewhere opens its
  /// collection focused on it (§4.2).
  @override
  LinkTileOpen openFrom(String hereCollectionId) =>
      collectionId == hereCollectionId
      ? RevealCardHere(cardId)
      : OpenLinkedCollection(collectionId, focusCardId: cardId);

  static String? _previewOf(CardKind kind, String? text, String? fileName) {
    final body = text?.trim() ?? '';
    if (body.isNotEmpty) return body;
    final name = fileName?.trim() ?? '';
    return CollectionOutline.namedKinds.contains(kind) && name.isNotEmpty
        ? name
        : null;
  }

  @override
  bool operator ==(Object other) =>
      other is CardLinkTile &&
      other.cardId == cardId &&
      other.cardKind == cardKind &&
      other.collectionId == collectionId &&
      other.collectionTitle == collectionTitle &&
      other.preview == preview &&
      other.thumbnailAttachmentId == thumbnailAttachmentId &&
      other.settled == settled &&
      other.caption == caption;

  @override
  int get hashCode => Object.hash(
    cardId,
    cardKind,
    collectionId,
    collectionTitle,
    preview,
    thumbnailAttachmentId,
    settled,
    caption,
  );
}

/// Where a tapped [LinkTile] goes (§4.2).
@immutable
sealed class LinkTileOpen {
  const LinkTileOpen();
}

/// Reveal and highlight [cardId] in the feed already open.
final class RevealCardHere extends LinkTileOpen {
  const RevealCardHere(this.cardId);
  final String cardId;

  @override
  bool operator ==(Object other) =>
      other is RevealCardHere && other.cardId == cardId;

  @override
  int get hashCode => cardId.hashCode;
}

/// Open [collectionId] over this feed, revealing [focusCardId] when set.
final class OpenLinkedCollection extends LinkTileOpen {
  const OpenLinkedCollection(this.collectionId, {this.focusCardId});
  final String collectionId;
  final String? focusCardId;

  @override
  bool operator ==(Object other) =>
      other is OpenLinkedCollection &&
      other.collectionId == collectionId &&
      other.focusCardId == focusCardId;

  @override
  int get hashCode => Object.hash(collectionId, focusCardId);
}
