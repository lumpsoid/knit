/// View-models for presenting a collection (§4.9). Primitives only — never a
/// `Snapshot` or other sync-core type (widgets.md §1).
library;

import 'package:flutter/foundation.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/domain/link_tile.dart';
import 'package:knit/features/connections/domain/connections_models.dart';

/// What a "See also" chip points at: the far end of a link touching a card.
enum PresentLinkKind { card, collection }

/// One live link of a presented card (§4.4), seen from the card: the [kind] and
/// [id] of the other end, and its [label] (a collection's title or a card's
/// text). Broken links are left out.
@immutable
class PresentLink {
  const PresentLink({
    required this.kind,
    required this.id,
    required this.label,
    required this.collectionId,
    this.outgoing = true,
    this.collectionTitle,
    this.imageAttachmentId,
  });

  final PresentLinkKind kind;
  final String id;
  final String label;

  /// The collection presented to follow this link: the target itself, or the
  /// target card's collection.
  final String collectionId;

  /// Whether the presented card links out to the other end (a backlink when
  /// false). Only a link out makes a Connection card (§4.2).
  final bool outgoing;

  /// A card target's collection title; null for a collection target.
  final String? collectionTitle;

  /// The target's picture: a collection's cover, an image card's first image.
  final String? imageAttachmentId;
}

/// One card of the presented collection, in feed order.
@immutable
class PresentCard {
  const PresentCard({
    required this.id,
    required this.kind,
    this.text,
    this.attachmentId,
    this.moreAttachmentIds = const [],
    this.fileName,
    this.settled = false,
    this.emphasized = false,
    this.links = const [],
  });

  final String id;
  final CardKind kind;

  /// A note's body, a link card's URL, or a media card's caption.
  final String? text;
  final String? attachmentId;

  /// An image card's further images after [attachmentId] (§4.2).
  final List<String> moreAttachmentIds;

  /// An image card's images, in order; empty for every other kind.
  List<String> get imageIds =>
      kind == CardKind.image ? [?attachmentId, ...moreAttachmentIds] : const [];

  /// An audio or file card's original file name.
  final String? fileName;
  final bool settled;
  final bool emphasized;
  final List<PresentLink> links;

  /// The link this card exists to point at — a Connection card (§4.2), by the
  /// feed's [LinkTile.targetOf] rule — or null for any other card.
  PresentLink? get connection {
    final out = [
      for (final l in links)
        if (l.outgoing) l,
    ];
    final target = LinkTile.targetOf(
      kind: kind,
      text: text,
      attachmentIds: [?attachmentId, ...moreAttachmentIds],
      linksOut: [
        for (final l in out) (targetKind: _entityKind(l.kind), targetId: l.id),
      ],
    );
    if (target == null) return null;
    return out.firstWhere((l) => l.id == target.targetId);
  }

  static ConnectedEntityKind _entityKind(PresentLinkKind kind) =>
      switch (kind) {
        PresentLinkKind.card => ConnectedEntityKind.card,
        PresentLinkKind.collection => ConnectedEntityKind.collection,
      };
}

/// Everything a presentation is planned from: the collection header and its
/// cards in feed order (settled ones included — the planner drops them).
@immutable
class PresentSource {
  const PresentSource({
    required this.collectionId,
    required this.title,
    this.description,
    this.coverAttachmentId,
    this.cards = const [],
  });

  final String collectionId;
  final String title;
  final String? description;
  final String? coverAttachmentId;
  final List<PresentCard> cards;
}

/// One full-screen page of a presentation.
sealed class Slide {
  const Slide();
}

/// Slide 0: the collection's cover, title and description.
class TitleSlide extends Slide {
  const TitleSlide({
    required this.title,
    this.description,
    this.coverAttachmentId,
  });

  final String title;
  final String? description;
  final String? coverAttachmentId;
}

/// A slide of [cards] in feed order: its [images] (the image cards, each with
/// all its images) are pinned on top (a carousel when there are several) and
/// its [notes] — the text, link, audio and file cards — sit below.
class CardSlide extends Slide {
  CardSlide(this.cards) : assert(cards.isNotEmpty);

  final List<PresentCard> cards;

  late final List<PresentCard> images = [
    for (final c in cards)
      if (c.kind == CardKind.image) c,
  ];

  late final List<PresentCard> notes = [
    for (final c in cards)
      if (c.kind != CardKind.image) c,
  ];

  /// The card a slide is remembered by (§4.9 resume): its first card.
  String get anchorCardId => cards.first.id;
}

/// A Connection card (§4.2) on a slide of its own: the [target]'s title and
/// picture, the card's label as a caption, and an Open that follows the link.
class LinkSlide extends Slide {
  const LinkSlide({required this.card, required this.target});

  final PresentCard card;
  final PresentLink target;

  /// The card's text, when it says more than the target's name; else null.
  String? get caption {
    final text = card.text?.trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == target.label.toLowerCase()) {
      return null;
    }
    return text;
  }

  /// The card's other links (its backlinks), as "See also" chips.
  List<PresentLink> get seeAlso => [
    for (final l in card.links)
      if (l.id != target.id) l,
  ];
}

/// A planned presentation: the title slide, then the card slides.
class SlideDeck {
  /// [feedCardIds] is the whole feed in order, presented or not, so a card
  /// left out can still be placed (see [slideOfCard]).
  SlideDeck(this.slides, {List<String> feedCardIds = const []})
    : _feedCardIds = feedCardIds,
      assert(slides.isNotEmpty);

  final List<Slide> slides;
  final List<String> _feedCardIds;

  int get length => slides.length;

  /// The slide [cardId] is on; null when it isn't presented (settled, or
  /// another collection's card).
  int? indexOfCard(String cardId) => _indexByCard[cardId];

  /// The slide a link to [cardId] opens at (§4.9): the card's own slide; for
  /// a card left out (settled), the slide of the nearest presented card
  /// before it in the feed; else the title slide.
  int slideOfCard(String cardId) {
    final own = indexOfCard(cardId);
    if (own != null) return own;
    final at = _feedCardIds.indexOf(cardId);
    for (var i = at - 1; i >= 0; i--) {
      final index = indexOfCard(_feedCardIds[i]);
      if (index != null) return index;
    }
    return 0;
  }

  /// The slide remembered by [anchorCardId] (§4.9 resume), when it is still a
  /// card slide past the title.
  int? resumeIndex(String? anchorCardId) {
    if (anchorCardId == null) return null;
    final index = indexOfCard(anchorCardId);
    return index == null || index == 0 ? null : index;
  }

  /// The card a slide is remembered by; null for the title slide.
  String? anchorOf(int index) => switch (slides[index]) {
    CardSlide(:final anchorCardId) => anchorCardId,
    LinkSlide(:final card) => card.id,
    TitleSlide() => null,
  };

  late final Map<String, int> _indexByCard = {
    for (var i = 0; i < slides.length; i++)
      ...switch (slides[i]) {
        CardSlide(:final cards) => {for (final c in cards) c.id: i},
        LinkSlide(:final card) => {card.id: i},
        TitleSlide() => const <String, int>{},
      },
  };
}
