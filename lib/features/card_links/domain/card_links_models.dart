import 'package:flutter/foundation.dart';
import 'package:knit/features/connections/domain/connections_models.dart';

/// One selectable link target (§4.4) — a collection or a card. [kind] chooses
/// the wire `target_type`; [label] is its display title/preview. Primitives
/// only (widgets.md §1), never a `Snapshot`.
@immutable
class LinkTarget {
  const LinkTarget({required this.kind, required this.id, required this.label});

  final ConnectedEntityKind kind;
  final String id;
  final String label;
}

/// The card a link is being made from, and which targets it may link to: never
/// itself, and never its own collection (a card already belongs to it, so the
/// link would say nothing). It may still link to a sibling card.
@immutable
class LinkSource {
  const LinkSource({required this.cardId, required this.collectionId});

  final String cardId;

  /// The source card's collection.
  final String collectionId;

  bool canLinkToCollection(String id) => id != collectionId;

  bool canLinkToCard(String id) => id != cardId;
}
