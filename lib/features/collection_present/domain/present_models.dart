/// View-models for presenting a collection (§4.9). Primitives only — never a
/// `Snapshot` or other sync-core type (widgets.md §1).
library;

import 'package:flutter/foundation.dart';
import 'package:knit/features/collection/domain/collection_models.dart';

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
  });

  final PresentLinkKind kind;
  final String id;
  final String label;
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

/// A planned presentation: the title slide, then the card slides.
class SlideDeck {
  SlideDeck(this.slides) : assert(slides.isNotEmpty);

  final List<Slide> slides;

  int get length => slides.length;

  /// The slide [cardId] is on; null when it isn't presented (settled, or
  /// another collection's card).
  int? indexOfCard(String cardId) => _indexByCard[cardId];

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
    TitleSlide() => null,
  };

  late final Map<String, int> _indexByCard = {
    for (var i = 0; i < slides.length; i++)
      if (slides[i] case CardSlide(:final cards))
        for (final c in cards) c.id: i,
  };
}
