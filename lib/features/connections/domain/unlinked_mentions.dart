import 'package:knit/features/card_links/domain/card_links_models.dart';
import 'package:knit/features/search/domain/search_ranker.dart';

/// One live card the "Mentioned in" section (§4.4, §8.6.5) may list: its text,
/// the collection that holds it, and whether this identity may write a link
/// from it (an own collection — an imported one is read-only).
class MentionCandidate {
  const MentionCandidate({
    required this.cardId,
    required this.collectionId,
    required this.collectionTitle,
    required this.text,
    required this.updatedAtMs,
    required this.canLink,
  });

  final String cardId;
  final String collectionId;
  final String collectionTitle;
  final String text;

  /// Last content write (ms) — newest first.
  final int updatedAtMs;

  /// Whether the card's collection is this identity's own
  /// (`CollectionOwnership.canEdit`).
  final bool canLink;
}

/// What the read port hands over for one focused collection: every live card
/// of every live collection, and the cards already linking to the focus.
class MentionCorpus {
  const MentionCorpus({required this.cards, required this.linkedCardIds});

  final List<MentionCandidate> cards;
  final Set<String> linkedCardIds;
}

/// One "Mentioned in" row: a card whose text names the focused collection but
/// does not link to it yet. [preview] is a one-line window of the card's text
/// around the mention.
class UnlinkedMention {
  const UnlinkedMention({
    required this.cardId,
    required this.collectionId,
    required this.collectionTitle,
    required this.preview,
  });

  final String cardId;
  final String collectionId;
  final String collectionTitle;
  final String preview;
}

/// The capped "Mentioned in" list: up to [UnlinkedMentionFinder.limit] rows,
/// newest first, and how many more matched ([more], the "+N more").
class UnlinkedMentions {
  const UnlinkedMentions({required this.items, this.more = 0});

  static const UnlinkedMentions none = UnlinkedMentions(items: []);

  final List<UnlinkedMention> items;
  final int more;

  bool get isEmpty => items.isEmpty;

  /// The list without [cardId] — the row a Link just took into backlinks.
  UnlinkedMentions without(String cardId) => UnlinkedMentions(
    items: [
      for (final m in items)
        if (m.cardId != cardId) m,
    ],
    more: more,
  );
}

/// The §8.6.5 unlinked-mention rule. A card mentions a collection when its
/// folded text (search's folding: case, accents, `ё`) contains the collection's
/// folded title as a whole phrase: whitespace runs count as one space, and a
/// title edge that is a letter or digit must not touch another one. A title
/// shorter than [minLength] folded characters, or one that is a single
/// [commonWords] word, mentions nothing — it would match everywhere.
///
/// Listed are only cards a link may come from: not in the collection itself
/// ([LinkSource]), not already linking to it, and in an own collection.
abstract final class UnlinkedMentionFinder {
  static const int minLength = 3;

  /// Rows shown; the rest are counted as "+N more".
  static const int limit = 20;

  /// Characters of context kept before a mention in the preview.
  static const int previewLead = 30;

  /// Single-word titles too common to mean the collection (folded).
  static const Set<String> commonWords = {
    'the',
    'and',
    'for',
    'are',
    'but',
    'not',
    'you',
    'all',
    'any',
    'can',
    'has',
    'its',
    'our',
    'out',
    'was',
    'who',
    'how',
    'why',
    'what',
    'when',
    'this',
    'that',
    'with',
    'from',
    'have',
    'they',
    'them',
    'then',
    'than',
    'there',
    'will',
    'just',
    'like',
    'more',
    'some',
    'very',
    'your',
    'about',
    'into',
    'new',
    'note',
    'notes',
    'misc',
    'todo',
    'это',
    'как',
    'что',
    'для',
    'все',
    'так',
    'его',
    'она',
    'они',
    'был',
    'или',
    'еще',
    'уже',
    'там',
    'тут',
    'где',
    'кто',
    'при',
    'без',
    'над',
    'под',
    'мои',
    'мой',
    'заметки',
  };

  static final RegExp _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);
  static final RegExp _whitespace = RegExp(r'\s+');

  static UnlinkedMentions find({
    required String collectionId,
    required String title,
    required MentionCorpus corpus,
  }) {
    final query = SearchQuery.parse(title);
    final phrase = query.phrase;
    if (phrase.length < minLength) return UnlinkedMentions.none;
    if (query.terms.length == 1 && commonWords.contains(phrase)) {
      return UnlinkedMentions.none;
    }

    final found = <({MentionCandidate card, String flat, int at})>[];
    for (final card in corpus.cards) {
      if (!card.canLink) continue;
      if (corpus.linkedCardIds.contains(card.cardId)) continue;
      final source = LinkSource(
        cardId: card.cardId,
        collectionId: card.collectionId,
      );
      if (!source.canLinkToCollection(collectionId)) continue;
      // Same-length folding, so an index into the folded text indexes [flat].
      final flat = card.text.trim().replaceAll(_whitespace, ' ');
      final at = _mention(SearchNormalizer.normalize(flat), phrase);
      if (at != null) found.add((card: card, flat: flat, at: at));
    }

    found.sort((a, b) {
      final byRecency = b.card.updatedAtMs.compareTo(a.card.updatedAtMs);
      return byRecency != 0
          ? byRecency
          : a.card.cardId.compareTo(b.card.cardId);
    });
    return UnlinkedMentions(
      items: [
        for (final f in found.take(limit))
          UnlinkedMention(
            cardId: f.card.cardId,
            collectionId: f.card.collectionId,
            collectionTitle: f.card.collectionTitle,
            preview: _preview(f.flat, f.at),
          ),
      ],
      more: found.length > limit ? found.length - limit : 0,
    );
  }

  /// The first index where [phrase] occurs in [text] on word boundaries.
  static int? _mention(String text, String phrase) {
    final guardStart = _wordChar.hasMatch(phrase[0]);
    final guardEnd = _wordChar.hasMatch(phrase[phrase.length - 1]);
    var from = 0;
    while (true) {
      final i = text.indexOf(phrase, from);
      if (i < 0) return null;
      final end = i + phrase.length;
      final startOk = !guardStart || i == 0 || !_wordChar.hasMatch(text[i - 1]);
      final endOk =
          !guardEnd || end == text.length || !_wordChar.hasMatch(text[end]);
      if (startOk && endOk) return i;
      from = i + 1;
    }
  }

  /// The text from a little before the mention, with an ellipsis when cut.
  static String _preview(String text, int at) {
    if (at <= previewLead) return text;
    var start = at - previewLead;
    while (start < at && text[start] != ' ') {
      start++;
    }
    return '…${text.substring(start).trimLeft()}';
  }
}
