import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/search/domain/search_filter.dart';
import 'package:knit/features/search/domain/search_models.dart';

SearchDocument _card(
  String id, {
  String? kind = 'text',
  String collection = 'col',
  bool settled = false,
  bool archived = false,
}) => SearchDocument(
  kind: SearchHitKind.card,
  id: id,
  collectionId: collection,
  collectionTitle: 'Col',
  texts: const [],
  updatedAtMs: 0,
  cardKind: kind,
  settled: settled,
  archived: archived,
);

SearchDocument _collection(String id, {bool archived = false}) =>
    SearchDocument(
      kind: SearchHitKind.collection,
      id: id,
      collectionId: id,
      collectionTitle: 'Col',
      texts: const [],
      updatedAtMs: 0,
      archived: archived,
    );

SearchHit _hit(String id, String collectionId, SearchHitKind kind) => SearchHit(
  kind: kind,
  id: id,
  collectionId: collectionId,
  collectionTitle: 'Col',
  field: SearchField.cardText,
  snippet: '',
  ranges: const [],
);

void main() {
  group('SearchCardKind.fromTag', () {
    test('resolves each tag', () {
      for (final kind in SearchCardKind.values) {
        expect(SearchCardKind.fromTag(kind.tag), kind);
      }
    });

    test('reads an unknown or missing tag as text', () {
      expect(SearchCardKind.fromTag('mystery'), SearchCardKind.text);
      expect(SearchCardKind.fromTag(null), SearchCardKind.text);
    });
  });

  test('SettledFilter cycles any → live → settled → any', () {
    expect(SettledFilter.any.next, SettledFilter.live);
    expect(SettledFilter.live.next, SettledFilter.settled);
    expect(SettledFilter.settled.next, SettledFilter.any);
  });

  group('SearchFilter', () {
    test('the default admits everything, archived included', () {
      const filter = SearchFilter();
      expect(filter.admits(_card('c', settled: true, archived: true)), isTrue);
      expect(filter.admits(_collection('col', archived: true)), isTrue);
    });

    test('kind chips keep only those kinds and hide collections', () {
      final filter = const SearchFilter()
          .toggleKind(SearchCardKind.image)
          .toggleKind(SearchCardKind.link);
      expect(filter.admits(_card('a', kind: 'image')), isTrue);
      expect(filter.admits(_card('b', kind: 'link')), isTrue);
      expect(filter.admits(_card('c', kind: 'text')), isFalse);
      expect(filter.admits(_card('d', kind: 'audio')), isFalse);
      expect(filter.admits(_collection('col')), isFalse);
    });

    test('toggling a kind twice turns it off again', () {
      final filter = const SearchFilter()
          .toggleKind(SearchCardKind.file)
          .toggleKind(SearchCardKind.file);
      expect(filter.kinds, isEmpty);
      expect(filter.admits(_collection('col')), isTrue);
    });

    test('the settled choice narrows cards only', () {
      const live = SearchFilter(settled: SettledFilter.live);
      const settled = SearchFilter(settled: SettledFilter.settled);
      expect(live.admits(_card('a')), isTrue);
      expect(live.admits(_card('b', settled: true)), isFalse);
      expect(settled.admits(_card('a')), isFalse);
      expect(settled.admits(_card('b', settled: true)), isTrue);
      expect(settled.admits(_collection('col')), isTrue);
      expect(live.admits(_collection('col')), isTrue);
    });

    test('excluding archived drops archived collections and their cards', () {
      const filter = SearchFilter(includeArchived: false);
      expect(filter.admits(_collection('old', archived: true)), isFalse);
      expect(filter.admits(_card('c', archived: true)), isFalse);
      expect(filter.admits(_collection('live')), isTrue);
      expect(filter.admits(_card('d')), isTrue);
    });

    test('the result type keeps collections or cards', () {
      const cards = SearchFilter(type: SearchResultType.cards);
      const collections = SearchFilter(type: SearchResultType.collections);
      expect(cards.admits(_card('c')), isTrue);
      expect(cards.admits(_collection('col')), isFalse);
      expect(collections.admits(_card('c')), isFalse);
      expect(collections.admits(_collection('col')), isTrue);
    });

    test('narrow applies the scope too, keeping order', () {
      final docs = [
        _card('a'),
        _collection('col'),
        _card('b', collection: 'other'),
        _card('c', settled: true),
      ];
      const scope = SearchScope(collectionId: 'col', title: 'Col');
      expect(const SearchFilter().narrow(docs, scope: scope).map((d) => d.id), [
        'a',
        'c',
      ]);
      expect(
        const SearchFilter(
          settled: SettledFilter.live,
        ).narrow(docs, scope: scope).map((d) => d.id),
        ['a'],
      );
      expect(const SearchFilter().narrow(docs).map((d) => d.id), [
        'a',
        'col',
        'b',
        'c',
      ]);
    });
  });

  group('SearchDestination', () {
    const origin = SearchScope(collectionId: 'col', title: 'Col');

    test('a card hit in the origin returns there, revealing it', () {
      final d = SearchDestination.of(
        _hit('c', 'col', SearchHitKind.card),
        origin: origin,
      );
      expect(d, isA<ReturnToOrigin>());
      expect((d as ReturnToOrigin).focusCardId, 'c');
    });

    test("the origin's own collection hit returns with nothing to reveal", () {
      final d = SearchDestination.of(
        _hit('col', 'col', SearchHitKind.collection),
        origin: origin,
      );
      expect((d as ReturnToOrigin).focusCardId, isNull);
    });

    test('other hits, or any hit without an origin, open a collection', () {
      expect(
        SearchDestination.of(
          _hit('c', 'other', SearchHitKind.card),
          origin: origin,
        ),
        isA<OpenCollection>(),
      );
      expect(
        SearchDestination.of(_hit('c', 'col', SearchHitKind.card)),
        isA<OpenCollection>(),
      );
    });
  });
}
