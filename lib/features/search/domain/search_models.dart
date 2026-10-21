/// The Search feature's models (§3.2/§4.1): the searchable documents the read
/// port hands over, and the ranked hits the [SearchRanker] produces from them.
/// Primitives only — no sync-core type crosses into the presentation layer.
library;

/// What a document (and so a hit) stands for — the row the user taps.
enum SearchHitKind { collection, card }

/// Where in a document a piece of text lives. The declaration order *is* the
/// field tier of the ranking (§ ranking: title > card text > the rest): a lower
/// [tier] ranks higher. Description, link label, and file name share a tier.
enum SearchField {
  collectionTitle(0),
  cardText(1),
  description(2),
  linkLabel(2),
  fileName(2);

  const SearchField(this.tier);

  /// 0 is the strongest field; equal tiers rank equally.
  final int tier;
}

/// One text a document can be found by, tagged with the [field] it came from.
class SearchText {
  const SearchText(this.field, this.text);

  final SearchField field;
  final String text;
}

/// One searchable entity — a live collection or a live card — flattened to its
/// searchable texts. [collectionId]/[collectionTitle] name the collection the
/// hit opens (for a collection document, itself).
class SearchDocument {
  const SearchDocument({
    required this.kind,
    required this.id,
    required this.collectionId,
    required this.collectionTitle,
    required this.texts,
    required this.updatedAtMs,
    this.cardKind,
    this.settled = false,
    this.archived = false,
  });

  final SearchHitKind kind;
  final String id;
  final String collectionId;
  final String collectionTitle;
  final List<SearchText> texts;

  /// Last-write wall-clock (ms) — the final ranking tie-break (newest first).
  final int updatedAtMs;

  /// The card's `kind` tag (text · image · audio · file · link), for its icon.
  /// Null for a collection.
  final String? cardKind;

  /// Whether the card is settled (§3.3). Always false for a collection.
  final bool settled;

  /// Whether the collection the hit opens is archived (§3.4). Archived
  /// collections stay searchable; the row just says so.
  final bool archived;
}

/// A highlighted stretch of a [SearchHit.snippet], `[start, end)` in UTF-16
/// code units.
class MatchRange {
  const MatchRange(this.start, this.end);

  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is MatchRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'MatchRange($start, $end)';
}

/// One ranked search result: the document it points at, the field that matched
/// best, and a [snippet] of that field's text with the matched [ranges].
class SearchHit {
  const SearchHit({
    required this.kind,
    required this.id,
    required this.collectionId,
    required this.collectionTitle,
    required this.field,
    required this.snippet,
    required this.ranges,
    this.cardKind,
    this.archived = false,
  });

  final SearchHitKind kind;
  final String id;
  final String collectionId;
  final String collectionTitle;
  final SearchField field;
  final String snippet;
  final List<MatchRange> ranges;
  final String? cardKind;
  final bool archived;

  /// The card to reveal when this hit opens its collection; null for a
  /// collection hit (it opens the feed at its normal position).
  String? get focusCardId => kind == SearchHitKind.card ? id : null;
}
