import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/search/domain/search_failure.dart';
import 'package:knit/features/search/domain/search_filter.dart';
import 'package:knit/features/search/domain/search_models.dart';
import 'package:knit/features/search/domain/search_read_repository.dart';
import 'package:knit/features/search/presentation/search_controller.dart';
import 'package:knit/features/search/presentation/search_state.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';

/// A read port whose answers the test hands out one load at a time.
class _FakeRead implements SearchReadRepository {
  final List<Completer<Result<List<SearchDocument>, SearchFailure>>> pending =
      [];

  @override
  Future<Result<List<SearchDocument>, SearchFailure>> loadDocuments() {
    final c = Completer<Result<List<SearchDocument>, SearchFailure>>();
    pending.add(c);
    return c.future;
  }
}

SearchDocument _doc(
  String id,
  SearchHitKind kind,
  String text, {
  String collection = 'col',
  bool settled = false,
  bool archived = false,
  int updatedAtMs = 0,
  Set<String> linksOut = const {},
}) => SearchDocument(
  kind: kind,
  id: id,
  collectionId: kind == SearchHitKind.card ? collection : id,
  collectionTitle: 'Col',
  texts: [
    SearchText(
      kind == SearchHitKind.card
          ? SearchField.cardText
          : SearchField.collectionTitle,
      text,
    ),
  ],
  updatedAtMs: updatedAtMs,
  cardKind: kind == SearchHitKind.card ? 'text' : null,
  settled: settled,
  archived: archived,
  linksOut: linksOut,
);

SearchHit _hit(String id, String collectionId) => SearchHit(
  kind: SearchHitKind.card,
  id: id,
  collectionId: collectionId,
  collectionTitle: 'Col',
  field: SearchField.cardText,
  snippet: 'tea',
  ranges: const [],
);

final _docs = [
  _doc('card-1', SearchHitKind.card, 'tea notes'),
  _doc('col-1', SearchHitKind.collection, 'Tea'),
  _doc('card-2', SearchHitKind.card, 'coffee'),
];

void main() {
  late _FakeRead read;
  late InMemoryCollectionRouteArgsStore routeArgs;
  late SearchController controller;

  setUp(() {
    read = _FakeRead();
    routeArgs = InMemoryCollectionRouteArgsStore();
    controller = SearchController(
      readRepository: read,
      collectionRouteArgs: routeArgs,
      logger: Logger('test.search'),
    );
  });

  tearDown(() => controller.dispose());

  test('starts idle', () {
    expect(controller.state.status, SearchStatus.idle);
    expect(controller.state.hits, isEmpty);
  });

  test('submit loads, then shows the ranked hits', () async {
    final done = controller.submit('tea');
    expect(controller.state.status, SearchStatus.loading);
    expect(controller.state.query, 'tea');

    read.pending.single.complete(Ok(_docs));
    await done;

    expect(controller.state.status, SearchStatus.ready);
    expect(controller.state.hits.map((h) => h.id), ['col-1', 'card-1']);
  });

  test('a blank query resets to idle without loading', () async {
    await controller.submit('  ');
    expect(controller.state.status, SearchStatus.idle);
    expect(read.pending, isEmpty);
  });

  test('a load failure shows the error; retry re-runs the query', () async {
    final first = controller.submit('tea');
    read.pending.single.complete(Failure(SearchLoadFailure('boom')));
    await first;
    expect(controller.state.status, SearchStatus.failed);

    final retry = controller.retry();
    read.pending.last.complete(Ok(_docs));
    await retry;
    expect(controller.state.status, SearchStatus.ready);
    expect(controller.state.hits, hasLength(2));
  });

  test('a slower, older search never overwrites a newer one', () async {
    final older = controller.submit('coffee');
    final newer = controller.submit('tea');
    read.pending[1].complete(Ok(_docs));
    await newer;
    read.pending[0].complete(Ok(_docs));
    await older;

    expect(controller.state.query, 'tea');
    expect(controller.state.hits.map((h) => h.id), ['col-1', 'card-1']);
  });

  test(
    'a filter change re-ranks the held documents without a reload',
    () async {
      final done = controller.submit('tea');
      read.pending.single.complete(Ok(_docs));
      await done;

      var notified = 0;
      controller.state.addListener(() => notified++);
      controller.setResultType(SearchResultType.cards);
      expect(notified, greaterThan(0));
      expect(controller.state.hits.map((h) => h.id), ['card-1']);

      controller.setResultType(SearchResultType.collections);
      expect(controller.state.hits.map((h) => h.id), ['col-1']);

      controller.setResultType(SearchResultType.all);
      controller.toggleKind(SearchCardKind.text);
      // A kind chip hides collection hits.
      expect(controller.state.hits.map((h) => h.id), ['card-1']);
      controller.toggleKind(SearchCardKind.image);
      controller.toggleKind(SearchCardKind.text);
      expect(controller.state.hits, isEmpty);

      expect(read.pending, hasLength(1));
      expect(controller.state.query, 'tea');
    },
  );

  test('settled and archived filters narrow the hits', () async {
    final done = controller.submit('tea');
    read.pending.single.complete(
      Ok([
        _doc('card-live', SearchHitKind.card, 'tea live'),
        _doc('card-settled', SearchHitKind.card, 'tea settled', settled: true),
        _doc('card-old', SearchHitKind.card, 'tea old', archived: true),
      ]),
    );
    await done;
    expect(controller.state.hits, hasLength(3));

    controller.cycleSettled();
    expect(controller.state.filter.settled, SettledFilter.live);
    expect(
      controller.state.hits.map((h) => h.id),
      unorderedEquals(['card-live', 'card-old']),
    );
    controller.cycleSettled();
    expect(controller.state.hits.map((h) => h.id), ['card-settled']);
    controller.cycleSettled();
    expect(controller.state.filter.settled, SettledFilter.any);

    controller.setIncludeArchived(false);
    expect(
      controller.state.hits.map((h) => h.id),
      unorderedEquals(['card-live', 'card-settled']),
    );
  });

  test('a filter change before any search runs nothing', () {
    controller.toggleKind(SearchCardKind.link);
    expect(read.pending, isEmpty);
    expect(controller.state.status, SearchStatus.idle);
    expect(controller.state.filter.kinds, {SearchCardKind.link});
  });

  test('a filter change after a failure re-runs the query', () async {
    final first = controller.submit('tea');
    read.pending.single.complete(Failure(SearchLoadFailure('boom')));
    await first;

    controller.toggleKind(SearchCardKind.text);
    expect(read.pending, hasLength(2));
    expect(controller.state.status, SearchStatus.loading);
    read.pending.last.complete(Ok(_docs));
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.hits.map((h) => h.id), ['card-1']);
  });

  group('scoped to a collection', () {
    const scope = SearchScope(collectionId: 'col', title: 'Col');
    final scopedDocs = [
      ..._docs,
      _doc('col', SearchHitKind.collection, 'tea col'),
      _doc('card-other', SearchHitKind.card, 'tea elsewhere', collection: 'x'),
    ];
    late SearchController scoped;

    setUp(() {
      scoped = SearchController(
        readRepository: read,
        collectionRouteArgs: routeArgs,
        scope: scope,
        logger: Logger('test.search'),
      );
    });

    tearDown(() => scoped.dispose());

    Future<void> search(String query) async {
      final done = scoped.submit(query);
      read.pending.last.complete(Ok(scopedDocs));
      await done;
    }

    test('ranks only its cards, with no collection hits', () async {
      expect(scoped.state.scope, same(scope));
      await search('tea');
      expect(scoped.state.hits.map((h) => h.id), ['card-1']);
    });

    test('clearing the scope widens to everything without a reload', () async {
      await search('tea');
      scoped.clearScope();
      expect(scoped.state.scope, isNull);
      expect(
        scoped.state.hits.map((h) => h.id),
        containsAll(['col-1', 'col', 'card-1', 'card-other']),
      );
      expect(read.pending, hasLength(1));
    });

    test('a hit in the origin returns to it, revealing the card', () {
      final destination = scoped.open(_hit('card-1', 'col'));
      expect(destination, isA<ReturnToOrigin>());
      expect((destination as ReturnToOrigin).focusCardId, 'card-1');
      expect(routeArgs.collectionId, isEmpty);
    });

    test('after widening, a hit elsewhere opens its collection', () async {
      await search('tea');
      scoped.clearScope();
      expect(scoped.open(_hit('card-other', 'x')), isA<OpenCollection>());
      expect(routeArgs.collectionId, 'x');
      expect(routeArgs.focusCardId, 'card-other');

      // The origin stays the origin once widened.
      expect(scoped.open(_hit('card-1', 'col')), isA<ReturnToOrigin>());
    });
  });

  test('opening a card hit targets its collection and focuses the card', () {
    expect(controller.open(_hit('card-1', 'col')), isA<OpenCollection>());
    expect(routeArgs.collectionId, 'col');
    expect(routeArgs.focusCardId, 'card-1');
  });

  test('opening a collection hit clears any previous focus', () {
    routeArgs.open('other', focusCardId: 'stale');
    controller.open(
      const SearchHit(
        kind: SearchHitKind.collection,
        id: 'col-1',
        collectionId: 'col-1',
        collectionTitle: 'Tea',
        field: SearchField.collectionTitle,
        snippet: 'Tea',
        ranges: [],
      ),
    );
    expect(routeArgs.collectionId, 'col-1');
    expect(routeArgs.focusCardId, isNull);
  });

  group('linked to (§4.1)', () {
    const veg = SearchLinkTarget(
      kind: SearchHitKind.collection,
      id: 'veg',
      label: 'Vegetarian',
    );
    const quick = SearchLinkTarget(
      kind: SearchHitKind.collection,
      id: 'quick',
      label: 'Quick',
    );
    final tagged = [
      _doc(
        'soup',
        SearchHitKind.card,
        'tea soup',
        updatedAtMs: 1,
        linksOut: {'veg', 'quick'},
      ),
      _doc(
        'salad',
        SearchHitKind.card,
        'salad',
        updatedAtMs: 3,
        linksOut: {'veg'},
      ),
      _doc(
        'steak',
        SearchHitKind.card,
        'tea steak',
        updatedAtMs: 2,
        linksOut: {'quick'},
      ),
      _doc(
        'menus',
        SearchHitKind.collection,
        'Menus',
        updatedAtMs: 4,
        linksOut: {'veg'},
      ),
    ];
    List<String> hitIds(SearchController c) =>
        c.state.hits.map((h) => h.id).toList();

    test(
      'an empty query browses what links to the target, newest first',
      () async {
        controller.toggleLinkedTo(veg);
        expect(controller.state.status, SearchStatus.loading);
        read.pending.single.complete(Ok(tagged));
        await Future<void>.delayed(Duration.zero);

        expect(controller.state.status, SearchStatus.ready);
        expect(controller.state.query, isEmpty);
        expect(hitIds(controller), ['menus', 'salad', 'soup']);
      },
    );

    test('adding and removing targets re-runs without re-reading', () async {
      controller.toggleLinkedTo(veg);
      read.pending.single.complete(Ok(tagged));
      await Future<void>.delayed(Duration.zero);

      controller.toggleLinkedTo(quick);
      expect(hitIds(controller), ['soup']);
      controller.toggleLinkedTo(veg);
      expect(hitIds(controller), ['steak', 'soup']);
      expect(read.pending, hasLength(1));

      // The last target gone, an empty query has nothing to show.
      controller.toggleLinkedTo(quick);
      expect(controller.state.status, SearchStatus.idle);
      expect(controller.state.hits, isEmpty);

      // ...and a target back browses the held documents again.
      controller.toggleLinkedTo(quick);
      expect(hitIds(controller), ['steak', 'soup']);
      expect(read.pending, hasLength(1));
    });

    test('with a query, the targets narrow the ranked hits', () async {
      final done = controller.submit('tea');
      read.pending.single.complete(Ok(tagged));
      await done;
      expect(hitIds(controller), unorderedEquals(['soup', 'steak']));

      controller.toggleLinkedTo(veg);
      expect(hitIds(controller), ['soup']);
      expect(controller.state.query, 'tea');
      expect(read.pending, hasLength(1));
    });

    test('clearing the query keeps browsing the targets', () async {
      controller.toggleLinkedTo(veg);
      read.pending.single.complete(Ok(tagged));
      await Future<void>.delayed(Duration.zero);

      final cleared = controller.submit('');
      read.pending.last.complete(Ok(tagged));
      await cleared;
      expect(hitIds(controller), ['menus', 'salad', 'soup']);
    });

    test(
      'opened pre-filtered ("Find linked cards"), start browses at once',
      () async {
        final linked = SearchController(
          readRepository: read,
          collectionRouteArgs: routeArgs,
          filter: SearchFilter(linkedTo: {veg}),
          logger: Logger('test.search'),
        );
        addTearDown(linked.dispose);
        final started = linked.start();
        read.pending.single.complete(Ok(tagged));
        await started;
        expect(hitIds(linked), ['menus', 'salad', 'soup']);
      },
    );

    test('start without a target waits for a query', () async {
      await controller.start();
      expect(read.pending, isEmpty);
      expect(controller.state.status, SearchStatus.idle);
    });
  });
}
