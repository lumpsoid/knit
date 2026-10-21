import 'package:knit/features/search/domain/search_models.dart';

/// A card kind the Kind chips filter on (§3.1). [tag] is the card's `kind`.
enum SearchCardKind {
  text('text'),
  image('image'),
  link('link'),
  file('file'),
  audio('audio');

  const SearchCardKind(this.tag);

  final String tag;

  /// The kind a card's `kind` tag names; an unknown or missing tag reads as
  /// text (the plain bubble the feed draws for it).
  static SearchCardKind fromTag(String? tag) {
    for (final kind in values) {
      if (kind.tag == tag) return kind;
    }
    return text;
  }
}

/// The Settled choice (§3.3): every card, only live ones, or only settled ones.
enum SettledFilter {
  any,
  live,
  settled;

  /// The next choice the cycling chip moves to.
  SettledFilter get next => values[(index + 1) % values.length];
}

/// The result-type chips: everything, only collections, or only cards.
enum SearchResultType { all, collections, cards }

/// The collection a search is narrowed to (§4.2: search opened from a
/// collection's ⋮ menu): only its cards are searched, never collection hits.
class SearchScope {
  const SearchScope({required this.collectionId, required this.title});

  final String collectionId;

  /// Shown on the "In: <title>" chip.
  final String title;

  bool admits(SearchDocument doc) =>
      doc.kind == SearchHitKind.card && doc.collectionId == collectionId;
}

/// One search session's filters (§3.2/§4.1), applied to the documents before
/// they are ranked. Not persisted. The defaults admit everything: all result
/// types, no kind chip (all kinds), any settled state, archived included
/// (§3.4: search still offers archived collections).
///
/// A collection document obeys only [type] and [includeArchived], and is
/// hidden while any kind chip is on (a collection has no card kind).
class SearchFilter {
  const SearchFilter({
    this.type = SearchResultType.all,
    this.kinds = const {},
    this.settled = SettledFilter.any,
    this.includeArchived = true,
  });

  final SearchResultType type;

  /// The card kinds to keep; empty keeps every kind.
  final Set<SearchCardKind> kinds;
  final SettledFilter settled;
  final bool includeArchived;

  SearchFilter copyWith({
    SearchResultType? type,
    Set<SearchCardKind>? kinds,
    SettledFilter? settled,
    bool? includeArchived,
  }) => SearchFilter(
    type: type ?? this.type,
    kinds: kinds ?? this.kinds,
    settled: settled ?? this.settled,
    includeArchived: includeArchived ?? this.includeArchived,
  );

  /// This filter with [kind] turned on, or off when it already is.
  SearchFilter toggleKind(SearchCardKind kind) => copyWith(
    kinds: kinds.contains(kind) ? ({...kinds}..remove(kind)) : {...kinds, kind},
  );

  bool admits(SearchDocument doc) {
    if (!includeArchived && doc.archived) return false;
    switch (doc.kind) {
      case SearchHitKind.collection:
        return type != SearchResultType.cards && kinds.isEmpty;
      case SearchHitKind.card:
        if (type == SearchResultType.collections) return false;
        if (kinds.isNotEmpty &&
            !kinds.contains(SearchCardKind.fromTag(doc.cardKind))) {
          return false;
        }
        return switch (settled) {
          SettledFilter.any => true,
          SettledFilter.live => !doc.settled,
          SettledFilter.settled => doc.settled,
        };
    }
  }

  /// The [documents] this filter — and [scope], when the search is narrowed
  /// to one collection — keeps, in their order.
  List<SearchDocument> narrow(
    List<SearchDocument> documents, {
    SearchScope? scope,
  }) => [
    for (final d in documents)
      if ((scope == null || scope.admits(d)) && admits(d)) d,
  ];
}

/// Where a tapped hit leads (§4.2). A search opened from a collection
/// ([origin]) returns to that page for a hit inside it — revealing the card,
/// if any — instead of stacking a second page of the same collection; every
/// other hit opens its collection anew.
sealed class SearchDestination {
  const SearchDestination();

  static SearchDestination of(SearchHit hit, {SearchScope? origin}) =>
      origin != null && hit.collectionId == origin.collectionId
      ? ReturnToOrigin(hit.focusCardId)
      : const OpenCollection();
}

/// Pop back to the collection the search was opened from, revealing
/// [focusCardId] (null for the collection's own hit: nothing to reveal).
class ReturnToOrigin extends SearchDestination {
  const ReturnToOrigin(this.focusCardId);

  final String? focusCardId;
}

/// Push the hit's collection; the Collection carrier has been written.
class OpenCollection extends SearchDestination {
  const OpenCollection();
}
