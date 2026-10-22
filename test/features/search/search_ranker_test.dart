import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/search/domain/search_models.dart';
import 'package:knit/features/search/domain/search_ranker.dart';

SearchDocument card(
  String id,
  String text, {
  int updatedAtMs = 0,
  String collectionTitle = 'Col',
  List<SearchText> extra = const [],
}) => SearchDocument(
  kind: SearchHitKind.card,
  id: id,
  collectionId: 'col-$id',
  collectionTitle: collectionTitle,
  texts: [SearchText(SearchField.cardText, text), ...extra],
  updatedAtMs: updatedAtMs,
  cardKind: 'text',
);

SearchDocument collection(
  String id,
  String title, {
  String? description,
  int updatedAtMs = 0,
}) => SearchDocument(
  kind: SearchHitKind.collection,
  id: id,
  collectionId: id,
  collectionTitle: title,
  texts: [
    SearchText(SearchField.collectionTitle, title),
    if (description != null) SearchText(SearchField.description, description),
  ],
  updatedAtMs: updatedAtMs,
);

void main() {
  const ranker = SearchRanker();
  List<String> ids(String q, List<SearchDocument> docs) =>
      ranker.rank(q, docs).map((h) => h.id).toList();

  group('SearchNormalizer', () {
    test('folds case, Latin accents and ё, keeping length', () {
      const input = 'Café ÉLAN Ёлка';
      final out = SearchNormalizer.normalize(input);
      expect(out, 'cafe elan елка');
      expect(out.length, input.length);
    });
  });

  group('matching', () {
    test('blank query matches nothing', () {
      expect(ranker.rank('   ', [card('a', 'anything')]), isEmpty);
    });

    test('is case-, accent- and ё-insensitive', () {
      final docs = [card('a', 'Crème BRÛLÉE'), card('b', 'ёжик в тумане')];
      expect(ids('creme brulee', docs), ['a']);
      expect(ids('ЕЖИК', docs), ['b']);
    });

    test('matches inside words, not just at their start', () {
      expect(ids('mato', [card('a', 'tomato soup')]), ['a']);
    });

    test('drops documents that match no term', () {
      expect(ids('kiwi', [card('a', 'tomato'), card('b', 'apple')]), isEmpty);
    });
  });

  group('ranking', () {
    test('exact phrase > all words > some words', () {
      final docs = [
        card('some', 'red only'),
        card('all', 'tomato, ripe and red'),
        card('phrase', 'a red tomato here'),
      ];
      expect(ids('red tomato', docs), ['phrase', 'all', 'some']);
    });

    test('more matched words rank higher among partial matches', () {
      final docs = [card('one', 'alpha'), card('two', 'alpha beta')];
      expect(ids('alpha beta gamma', docs), ['two', 'one']);
    });

    test('title > card text > description', () {
      final docs = [
        collection('desc', 'Other', description: 'garden notes'),
        card('text', 'garden plan'),
        collection('title', 'Garden'),
      ];
      expect(ids('garden', docs), ['title', 'text', 'desc']);
    });

    test('a match at a word start beats one inside a word', () {
      final docs = [card('inner', 'Tomato'), card('start', 'Matone')];
      expect(ids('mato', docs), ['start', 'inner']);
    });

    test('ties go to the most recently updated', () {
      final docs = [
        card('old', 'tea', updatedAtMs: 1),
        card('new', 'tea', updatedAtMs: 9),
      ];
      expect(ids('tea', docs), ['new', 'old']);
    });

    test("a document ranks by its best field", () {
      final docs = [
        card(
          'label',
          'nothing',
          extra: [const SearchText(SearchField.linkLabel, 'kiwi farm')],
        ),
        card('plain', 'kiwi'),
      ];
      final hits = ranker.rank('kiwi', docs);
      expect(hits.map((h) => h.id), ['plain', 'label']);
      expect(hits.last.field, SearchField.linkLabel);
      expect(hits.last.snippet, 'kiwi farm');
    });
  });

  group('snippet', () {
    test('highlights every matched term in the original text', () {
      final hit = ranker.rank('red tomato', [
        card('a', 'A Red ripe Tomato'),
      ]).single;
      expect(hit.snippet, 'A Red ripe Tomato');
      expect(hit.ranges, const [MatchRange(2, 5), MatchRange(11, 17)]);
    });

    test('highlights a whole phrase as one range', () {
      final hit = ranker.rank('red tomato', [card('a', 'a red tomato')]).single;
      expect(hit.ranges, const [MatchRange(2, 12)]);
    });

    test('windows long text around the first match with ellipses', () {
      final text = '${'x' * 100} needle ${'y' * 200}';
      final hit = ranker.rank('needle', [card('a', text)]).single;
      expect(hit.snippet.startsWith('…'), isTrue);
      expect(hit.snippet.endsWith('…'), isTrue);
      final r = hit.ranges.single;
      expect(hit.snippet.substring(r.start, r.end), 'needle');
    });

    test('flattens line breaks to spaces', () {
      final hit = ranker.rank('two', [card('a', 'one\ntwo')]).single;
      expect(hit.snippet, 'one two');
      expect(hit.ranges.single, const MatchRange(4, 7));
    });
  });

  test('a card hit focuses its card; a collection hit does not', () {
    final hits = ranker.rank('tea', [card('c', 'tea'), collection('k', 'tea')]);
    final byId = {for (final h in hits) h.id: h};
    expect(byId['c']!.focusCardId, 'c');
    expect(byId['k']!.focusCardId, isNull);
  });

  test('a hit carries its document\'s archived flag', () {
    final archived = SearchDocument(
      kind: SearchHitKind.collection,
      id: 'k',
      collectionId: 'k',
      collectionTitle: 'tea',
      texts: const [SearchText(SearchField.collectionTitle, 'tea')],
      updatedAtMs: 0,
      archived: true,
    );
    final hits = ranker.rank('tea', [archived, card('c', 'tea')]);
    final byId = {for (final h in hits) h.id: h};
    expect(byId['k']!.archived, isTrue);
    expect(byId['c']!.archived, isFalse);
  });

  group('browse (no query, §4.1)', () {
    test('lists every document newest first, ties by id', () {
      final hits = ranker.browse([
        card('old', 'a', updatedAtMs: 1),
        collection('new', 'Tag', updatedAtMs: 3),
        card('b', 'b', updatedAtMs: 2),
        card('a', 'a', updatedAtMs: 2),
      ]);
      expect(hits.map((h) => h.id), ['new', 'a', 'b', 'old']);
    });

    test('a hit shows the start of its strongest text, unhighlighted', () {
      final hits = ranker.browse([
        collection('col', 'Recipes', description: 'all of them'),
        card('long', 'x' * 200),
        SearchDocument(
          kind: SearchHitKind.card,
          id: 'photo',
          collectionId: 'col',
          collectionTitle: 'Col',
          texts: const [],
          updatedAtMs: 0,
          cardKind: 'image',
        ),
      ]);
      expect(hits[0].snippet, 'Recipes');
      expect(hits[0].field, SearchField.collectionTitle);
      expect(hits[0].ranges, isEmpty);
      expect(hits[1].snippet, '${'x' * SearchRanker.snippetLength}…');
      expect(hits[2].snippet, isEmpty);
      expect(hits[2].field, SearchField.cardText);
    });
  });
}
