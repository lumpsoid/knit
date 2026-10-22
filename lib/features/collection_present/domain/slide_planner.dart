import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection_present/domain/present_models.dart';

/// Groups a collection's cards into slides (§4.9). Pure.
///
/// - Slide 0 is the title slide (cover, title, description).
/// - Settled cards are left out (§3.3).
/// - A run of consecutive images opens a slide; the notes after it join it
///   until the next image.
/// - An emphasized card opens a slide too, as its heading — unless it directly
///   follows that slide's images, where it heads them instead.
/// - Images right after a lone heading join it rather than open a new slide.
/// - Notes before any image or heading form a text slide of their own.
/// - A Connection card (§4.2) is a link slide of its own: the cards around it
///   stay on the slides before and after it.
class SlidePlanner {
  const SlidePlanner();

  SlideDeck plan(PresentSource source) {
    final slides = <Slide>[
      TitleSlide(
        title: source.title,
        description: source.description,
        coverAttachmentId: source.coverAttachmentId,
      ),
    ];
    var current = <PresentCard>[];

    void close() {
      if (current.isNotEmpty) slides.add(CardSlide(current));
      current = [];
    }

    for (final card in source.cards) {
      if (card.settled) continue;
      final target = card.connection;
      if (target != null) {
        close();
        slides.add(LinkSlide(card: card, target: target));
        continue;
      }
      if (_opensSlide(current, card)) close();
      current.add(card);
    }
    close();
    return SlideDeck(slides, feedCardIds: [for (final c in source.cards) c.id]);
  }

  /// Whether [card] starts a new slide after the [current] one's cards.
  static bool _opensSlide(List<PresentCard> current, PresentCard card) {
    if (current.isEmpty) return false;
    final last = current.last;
    if (card.kind == CardKind.image) {
      // Images continue an image run, and fill a lone heading's slide.
      if (last.kind == CardKind.image) return false;
      return !_onlyHeading(current);
    }
    if (card.emphasized) {
      // A heading right after the slide's images heads them.
      return !current.every((c) => c.kind == CardKind.image);
    }
    return false;
  }

  /// Whether [cards] is just one emphasized heading (no images yet).
  static bool _onlyHeading(List<PresentCard> cards) =>
      cards.length == 1 && cards.first.emphasized;
}
