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

  /// The card whose live links out the picker marks ✓ (and toggles off); null
  /// ⇒ no checks.
  String? get linkedFrom => null;

  /// Whether the collection [id] itself may be picked.
  bool canLinkToCollection(String id);

  /// Whether the card [id] may be picked.
  bool canLinkToCard(String id);

  /// Whether the [kind] entity [id] may be picked.
  bool canLinkTo(ConnectedEntityKind kind, String id) => switch (kind) {
    ConnectedEntityKind.collection => canLinkToCollection(id),
    ConnectedEntityKind.card => canLinkToCard(id),
    ConnectedEntityKind.unknown => false,
  };
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

  @override
  String? get linkedFrom => cardId;
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

/// The "+" sheet's Connection block (§4.2): pick the collection or the card a
/// new Connection card in [collectionId] will point at. Never [collectionId]
/// itself (the [LinkSource] rule), but any card, its own siblings included:
/// the new card doesn't exist yet, so it can't be picked. Imported collections
/// are offered: the link is the linker's own op.
@immutable
class NewConnection extends LinkPick {
  const NewConnection({required this.collectionId});

  /// The collection the new card goes into.
  final String collectionId;

  @override
  bool canLinkToCollection(String id) => id != collectionId;

  @override
  bool canLinkToCard(String id) => true;
}

/// The targets a card already links to (§4.4), each with the id of the link
/// that joins them — one per pair (§6.4). Marks the picker's ✓ and decides
/// what a tap does: a linked target unlinks, any other links.
@immutable
class LinkedTargets {
  const LinkedTargets([this._linkIds = const {}]);

  /// The link id per linked target, keyed by its kind and id.
  final Map<(ConnectedEntityKind, String), String> _linkIds;

  /// The id of the link to [target], or null when not linked.
  String? linkIdTo(LinkTarget target) => _linkIds[(target.kind, target.id)];

  /// Whether the card already links to [target].
  bool has(LinkTarget target) => linkIdTo(target) != null;

  /// What tapping [target] in the picker means: unlink a linked one, link any
  /// other.
  LinkPickerChoice toggle(LinkTarget target) => switch (linkIdTo(target)) {
    final linkId? => LinkTargetUnpicked(target, linkId),
    null => LinkTargetPicked(target),
  };
}

/// What the link picker returns (§4.4): a target to link, or a linked one
/// tapped again to remove its link.
@immutable
sealed class LinkPickerChoice {
  const LinkPickerChoice(this.target);

  final LinkTarget target;
}

/// Link to [target].
final class LinkTargetPicked extends LinkPickerChoice {
  const LinkTargetPicked(super.target);
}

/// Remove the link [linkId] to the already linked [target].
final class LinkTargetUnpicked extends LinkPickerChoice {
  const LinkTargetUnpicked(super.target, this.linkId);

  final String linkId;
}
