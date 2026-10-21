import 'package:flutter/foundation.dart';
import 'package:knit/features/connections/domain/connections_models.dart';

/// One selectable link target (§4.4) — a collection or a card. [kind] chooses
/// the wire `target_type`; [label] is its display title/preview. Primitives
/// only (widgets.md §1), never a `Snapshot`.
@immutable
class LinkTarget {
  const LinkTarget({
    required this.kind,
    required this.id,
    required this.label,
    this.own = true,
  });

  final ConnectedEntityKind kind;
  final String id;
  final String label;

  /// For a collection: whether it is this identity's own, not an imported,
  /// read-only one (docs/collection_share.md).
  final bool own;
}

/// What a picker session picks, and which of the listed entities it may pick.
sealed class LinkPick {
  const LinkPick();

  /// Whether [collection] is listed at all.
  bool lists(LinkTarget collection) => true;

  /// Whether a listed collection can be opened to pick a card in it.
  bool get drills => true;

  /// Whether the collection [id] itself may be picked.
  bool canLinkToCollection(String id);

  /// Whether the card [id] may be picked.
  bool canLinkToCard(String id);
}

/// The card a link is being made from, and which targets it may link to: never
/// itself, and never its own collection (a card already belongs to it, so the
/// link would say nothing). It may still link to a sibling card. Imported
/// collections are offered: the link is the linker's own op.
@immutable
class LinkSource extends LinkPick {
  const LinkSource({required this.cardId, required this.collectionId});

  final String cardId;

  /// The source card's collection.
  final String collectionId;

  @override
  bool canLinkToCollection(String id) => id != collectionId;

  @override
  bool canLinkToCard(String id) => id != cardId;
}

/// "Link from my card…" on a card of an imported collection: pick one of
/// this identity's own cards to link *from* to [targetCardId]. Only own
/// collections are listed, and only their cards can be picked — a link's
/// source is always a card.
@immutable
class LinkFromMine extends LinkPick {
  const LinkFromMine({required this.targetCardId});

  final String targetCardId;

  @override
  bool lists(LinkTarget collection) => collection.own;

  @override
  bool canLinkToCollection(String id) => false;

  @override
  bool canLinkToCard(String id) => id != targetCardId;
}

/// The "+" sheet's Connection block (§4.2): pick the collection a new
/// Connection card in [collectionId] will point at. Collections only — no
/// drilling into cards — and never [collectionId] itself (the [LinkSource]
/// rule). Imported collections are offered: the link is the linker's own op.
@immutable
class NewConnection extends LinkPick {
  const NewConnection({required this.collectionId});

  /// The collection the new card goes into.
  final String collectionId;

  @override
  bool lists(LinkTarget collection) => collection.id != collectionId;

  @override
  bool get drills => false;

  @override
  bool canLinkToCollection(String id) => id != collectionId;

  @override
  bool canLinkToCard(String id) => false;
}
