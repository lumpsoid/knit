import 'package:knit/features/search/domain/search_ranker.dart';

/// An existing collection a new title is checked against.
class CollectionTitle {
  const CollectionTitle({required this.collectionId, required this.title});

  final String collectionId;
  final String title;
}

/// Spots an existing collection that a title being typed for a new one looks
/// like, so creating fast doesn't scatter duplicates. Matches with search's
/// folding (case, accents): an identical title wins; otherwise every typed
/// word must start a word of the title. Below [minLength] folded characters
/// nothing matches — too short to mean anything.
abstract final class SimilarCollectionFinder {
  static const int minLength = 3;

  /// The best match in [existing] (kept in its order, so recency-first input
  /// favours the most recent of equal matches), or null.
  static CollectionTitle? find(String typed, List<CollectionTitle> existing) {
    final query = SearchQuery.parse(typed);
    if (query.phrase.length < minLength) return null;
    CollectionTitle? close;
    for (final candidate in existing) {
      final title = SearchQuery.parse(candidate.title);
      if (title.phrase == query.phrase) return candidate;
      if (close == null && _wordsStartTitle(query, title)) close = candidate;
    }
    return close;
  }

  static bool _wordsStartTitle(SearchQuery query, SearchQuery title) =>
      query.terms.every((t) => title.terms.any((w) => w.startsWith(t)));
}
