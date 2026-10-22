import 'package:flutter/foundation.dart';
import 'package:knit/features/collection_present/domain/present_models.dart';

/// Where following a link from a presentation goes (§4.9). Pure.
///
/// - A link to the presented collection, or to a card in it, turns this deck
///   to that slide ([JumpToSlide]).
/// - A link to a collection already presented further down the stack, or to a
///   card in one, goes back to that presentation ([ReturnToPresentation]) —
///   the stack never holds one collection twice.
/// - Anything else presents the target on top ([PresentOnTop]), at the linked
///   card's slide when it is a card.
@immutable
sealed class PresentFollow {
  const PresentFollow();

  /// Follow [link] from [deck], the top of [presented] — the presented
  /// collections, bottom first (never empty; its last is [deck]'s).
  static PresentFollow of(
    PresentLink link, {
    required List<String> presented,
    required SlideDeck deck,
  }) {
    final collectionId = link.collectionId;
    final focusCardId = link.kind == PresentLinkKind.card ? link.id : null;
    if (collectionId == presented.last) {
      return JumpToSlide(
        focusCardId == null ? 0 : deck.slideOfCard(focusCardId),
      );
    }
    if (presented.contains(collectionId)) {
      return ReturnToPresentation(collectionId, focusCardId: focusCardId);
    }
    return PresentOnTop(collectionId, focusCardId: focusCardId);
  }
}

/// Turn the deck on screen to slide [index].
final class JumpToSlide extends PresentFollow {
  const JumpToSlide(this.index);
  final int index;

  @override
  bool operator ==(Object other) =>
      other is JumpToSlide && other.index == index;

  @override
  int get hashCode => index.hashCode;
}

/// Present [collectionId] over this presentation, opening at [focusCardId]'s
/// slide when set.
final class PresentOnTop extends PresentFollow {
  const PresentOnTop(this.collectionId, {this.focusCardId});
  final String collectionId;
  final String? focusCardId;

  @override
  bool operator ==(Object other) =>
      other is PresentOnTop &&
      other.collectionId == collectionId &&
      other.focusCardId == focusCardId;

  @override
  int get hashCode => Object.hash(collectionId, focusCardId);
}

/// Close the presentations above [collectionId]'s and turn it to
/// [focusCardId]'s slide when set (else it stays on its slide).
final class ReturnToPresentation extends PresentFollow {
  const ReturnToPresentation(this.collectionId, {this.focusCardId});
  final String collectionId;
  final String? focusCardId;

  @override
  bool operator ==(Object other) =>
      other is ReturnToPresentation &&
      other.collectionId == collectionId &&
      other.focusCardId == focusCardId;

  @override
  int get hashCode => Object.hash(collectionId, focusCardId);
}
