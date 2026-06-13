/// View-models for the Card Edit page's link manager (§4.3, full scope).
/// Primitives only — never a `Snapshot` (widgets.md §1) — so the picker UI never
/// reaches into the merge core. The link *list* itself reuses the `connections`
/// view-models (`ConnectionItem`/`ConnectedEntityKind`); these models only cover
/// the add-flow target tree the connections view has no equivalent for.
library;

import 'package:knit/features/connections/domain/connections_models.dart';

/// One selectable target in the link picker — a collection or a card. [kind]
/// chooses the wire `target_type`; [label] is its display title/preview.
class CardLinkOption {
  const CardLinkOption({
    required this.kind,
    required this.id,
    required this.label,
  });

  final ConnectedEntityKind kind;
  final String id;
  final String label;
}

/// A collection plus its cards, as offered in the two-level picker: the user
/// browses [collection]s, then drills into one to pick a [cards] entry
/// (card→card linking). The whole tree is loaded up front so the picker is pure
/// UI over state (no async drilling).
class CardLinkCollectionTargets {
  const CardLinkCollectionTargets({
    required this.collection,
    required this.cards,
  });

  /// The collection itself — a valid link target on its own (card→collection).
  final CardLinkOption collection;

  /// The collection's cards, minus the card being edited (no self-link).
  final List<CardLinkOption> cards;
}
