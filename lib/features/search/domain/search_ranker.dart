import 'dart:math' as math;

import 'package:knit/features/search/domain/search_models.dart';

/// Folds text for matching: lower-cases it, strips common Latin accents, and
/// treats `ё` as `е`. Every input UTF-16 unit maps to exactly one output unit,
/// so an index into the folded text is the same index into the original — the
/// snippet highlights rely on that.
abstract final class SearchNormalizer {
  /// Accented letter → its base letter. Values must stay one code unit long.
  static const Map<String, String> foldTable = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'ā': 'a',
    'ç': 'c',
    'č': 'c',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ē': 'e',
    'ę': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ī': 'i',
    'ñ': 'n',
    'ń': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ø': 'o',
    'ō': 'o',
    'ś': 's',
    'š': 's',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ū': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'ź': 'z',
    'ż': 'z',
    'ž': 'z',
    'ё': 'е',
  };

  static String normalize(String text) {
    final out = StringBuffer();
    for (final unit in text.codeUnits) {
      var ch = String.fromCharCode(unit);
      final lower = ch.toLowerCase();
      // A few letters lower-case to two units (e.g. 'İ'); keep those as-is so
      // the one-unit-per-unit mapping holds.
      if (lower.length == 1) ch = lower;
      out.write(foldTable[ch] ?? ch);
    }
    return out.toString();
  }
}

/// A parsed query: the folded whole [phrase] (whitespace collapsed) and its
/// distinct [terms].
class SearchQuery {
  const SearchQuery._(this.phrase, this.terms);

  factory SearchQuery.parse(String raw) {
    final phrase = SearchNormalizer.normalize(
      raw.trim(),
    ).split(_whitespace).where((t) => t.isNotEmpty).join(' ');
    final terms = phrase.isEmpty ? const <String>[] : phrase.split(' ');
    return SearchQuery._(phrase, terms.toSet().toList(growable: false));
  }

  static final RegExp _whitespace = RegExp(r'\s+');

  final String phrase;
  final List<String> terms;

  bool get isEmpty => terms.isEmpty;
}

/// How well one text matched the query. Ordering, strongest first:
/// exact phrase > all words > some words (more words first); then the field
/// tier; then a match at the start of a word over one inside a word.
class _FieldMatch {
  const _FieldMatch({
    required this.text,
    required this.quality,
    required this.matchedTerms,
    required this.wordStart,
    required this.ranges,
  });

  final SearchText text;

  /// 0 = exact phrase, 1 = all words, 2 = some words.
  final int quality;
  final int matchedTerms;
  final bool wordStart;

  /// Matched stretches in the full text, sorted and merged.
  final List<MatchRange> ranges;

  /// Negative when this match ranks above [other].
  int compareTo(_FieldMatch other) {
    if (quality != other.quality) return quality - other.quality;
    if (matchedTerms != other.matchedTerms) {
      return other.matchedTerms - matchedTerms;
    }
    if (text.field.tier != other.text.field.tier) {
      return text.field.tier - other.text.field.tier;
    }
    if (wordStart != other.wordStart) return wordStart ? -1 : 1;
    return 0;
  }
}

/// The pure ranking rules for Search. Matches each document's texts against the
/// query, keeps each document's best-matching text, and orders the documents:
/// match quality → field tier → word-start → most recently updated. Documents
/// that match nothing are dropped.
class SearchRanker {
  const SearchRanker();

  /// Characters of context kept before the first match in a snippet.
  static const int snippetLead = 30;

  /// Longest snippet body (before the ellipses are added).
  static const int snippetLength = 120;

  static final RegExp _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);
  static final RegExp _anyWhitespace = RegExp(r'\s');

  List<SearchHit> rank(String rawQuery, List<SearchDocument> documents) {
    final query = SearchQuery.parse(rawQuery);
    if (query.isEmpty) return const [];

    final scored = <({SearchDocument doc, _FieldMatch match})>[];
    for (final doc in documents) {
      _FieldMatch? best;
      for (final text in doc.texts) {
        final match = _matchText(query, text);
        if (match == null) continue;
        if (best == null || match.compareTo(best) < 0) best = match;
      }
      if (best != null) scored.add((doc: doc, match: best));
    }

    scored.sort((a, b) {
      final byMatch = a.match.compareTo(b.match);
      if (byMatch != 0) return byMatch;
      final byRecency = b.doc.updatedAtMs.compareTo(a.doc.updatedAtMs);
      if (byRecency != 0) return byRecency;
      return a.doc.id.compareTo(b.doc.id);
    });

    return [for (final s in scored) _toHit(s.doc, s.match)];
  }

  _FieldMatch? _matchText(SearchQuery query, SearchText text) {
    final folded = SearchNormalizer.normalize(text.text);
    final ranges = <MatchRange>[];
    var matchedTerms = 0;
    var allTermsAtWordStart = true;
    for (final term in query.terms) {
      final hits = _occurrences(folded, term);
      if (hits.isEmpty) continue;
      matchedTerms++;
      if (!hits.any((i) => _isWordStart(folded, i))) {
        allTermsAtWordStart = false;
      }
      ranges.addAll(hits.map((i) => MatchRange(i, i + term.length)));
    }
    if (matchedTerms == 0) return null;

    final phraseHits = query.terms.length > 1
        ? _occurrences(folded, query.phrase)
        : const <int>[];
    final int quality;
    final bool wordStart;
    if (query.terms.length == 1) {
      quality = 0;
      wordStart = allTermsAtWordStart;
    } else if (phraseHits.isNotEmpty) {
      quality = 0;
      wordStart = phraseHits.any((i) => _isWordStart(folded, i));
      ranges.addAll(
        phraseHits.map((i) => MatchRange(i, i + query.phrase.length)),
      );
    } else {
      quality = matchedTerms == query.terms.length ? 1 : 2;
      wordStart = allTermsAtWordStart;
    }

    return _FieldMatch(
      text: text,
      quality: quality,
      matchedTerms: matchedTerms,
      wordStart: wordStart,
      ranges: _merge(ranges),
    );
  }

  static List<int> _occurrences(String haystack, String needle) {
    final found = <int>[];
    var from = 0;
    while (true) {
      final i = haystack.indexOf(needle, from);
      if (i < 0) return found;
      found.add(i);
      from = i + 1;
    }
  }

  static bool _isWordStart(String text, int index) =>
      index == 0 || !_wordChar.hasMatch(text[index - 1]);

  static List<MatchRange> _merge(List<MatchRange> ranges) {
    if (ranges.isEmpty) return const [];
    final sorted = [...ranges]..sort((a, b) => a.start.compareTo(b.start));
    final merged = <MatchRange>[sorted.first];
    for (final r in sorted.skip(1)) {
      final last = merged.last;
      if (r.start <= last.end) {
        if (r.end > last.end) {
          merged[merged.length - 1] = MatchRange(last.start, r.end);
        }
      } else {
        merged.add(r);
      }
    }
    return merged;
  }

  /// Cut a one-line window of the matched text around its first match, with
  /// ellipses where it was trimmed, and shift the ranges into it.
  SearchHit _toHit(SearchDocument doc, _FieldMatch match) {
    // Same-length whitespace flattening keeps the range indices valid.
    final text = match.text.text.replaceAll(_anyWhitespace, ' ');
    final anchor = match.ranges.first.start;
    var start = math.max(0, anchor - snippetLead);
    while (start < anchor && text[start] == ' ') {
      start++;
    }
    final end = math.min(text.length, start + snippetLength);
    final prefix = start > 0 ? '…' : '';
    final body = text.substring(start, end).trimRight();
    final suffix = end < text.length ? '…' : '';
    final bodyEnd = prefix.length + body.length;

    final ranges = [
      for (final r in match.ranges)
        if (r.start < end && r.end > start)
          MatchRange(
            prefix.length + math.max<int>(r.start, start) - start,
            math.min<int>(prefix.length + r.end - start, bodyEnd),
          ),
    ].where((r) => r.end > r.start).toList(growable: false);

    return SearchHit(
      kind: doc.kind,
      id: doc.id,
      collectionId: doc.collectionId,
      collectionTitle: doc.collectionTitle,
      field: match.text.field,
      snippet: '$prefix$body$suffix',
      ranges: ranges,
      cardKind: doc.cardKind,
    );
  }
}
