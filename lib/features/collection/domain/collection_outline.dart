import 'package:flutter/foundation.dart';
import 'package:knit/features/collection/domain/collection_models.dart';

/// One heading of a collection's Outline (§4.2): an emphasized card, which
/// reads as a section heading here as it does in Present (§3.3, §4.9).
/// Primitives only (widgets.md §1).
@immutable
class OutlineEntry {
  const OutlineEntry({required this.cardId, required this.kind, this.label});

  final String cardId;
  final CardKind kind;

  /// The row's one-line text: the first line of the card's text, or a file or
  /// audio card's file name when it has none. Null when the card has neither,
  /// so the row names its [kind] instead.
  final String? label;

  @override
  bool operator ==(Object other) =>
      other is OutlineEntry &&
      other.cardId == cardId &&
      other.kind == kind &&
      other.label == label;

  @override
  int get hashCode => Object.hash(cardId, kind, label);
}

/// The Outline of a collection (§4.2): its emphasized cards, in feed order, as
/// headings to jump to. A settled card is never emphasized (§3.3), so it never
/// heads a section.
abstract final class CollectionOutline {
  /// The outline of [feed], the collection's whole feed in feed order.
  static List<OutlineEntry> of(Iterable<FeedCard> feed) => [
    for (final card in feed)
      if (card.emphasized)
        OutlineEntry(cardId: card.id, kind: card.kind, label: labelOf(card)),
  ];

  /// The kinds whose file name stands in for missing text.
  static const Set<CardKind> namedKinds = {CardKind.file, CardKind.audio};

  /// [card]'s one-line label: the first non-blank line of its text, else its
  /// file name (file and audio cards), else null.
  static String? labelOf(FeedCard card) {
    for (final line in (card.text ?? '').split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    final name = card.fileName?.trim() ?? '';
    return namedKinds.contains(card.kind) && name.isNotEmpty ? name : null;
  }
}
