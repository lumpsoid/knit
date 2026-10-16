import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/search/domain/search_failure.dart';
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

SearchDocument _doc(String id, SearchHitKind kind, String text) =>
    SearchDocument(
      kind: kind,
      id: id,
      collectionId: kind == SearchHitKind.card ? 'col' : id,
      collectionTitle: 'Col',
      texts: [
        SearchText(
          kind == SearchHitKind.card
              ? SearchField.cardText
              : SearchField.collectionTitle,
          text,
        ),
      ],
      updatedAtMs: 0,
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

  test('the filter narrows the visible hits and notifies', () async {
    final done = controller.submit('tea');
    read.pending.single.complete(Ok(_docs));
    await done;

    var notified = 0;
    controller.state.addListener(() => notified++);
    controller.setFilter(SearchFilter.cards);
    expect(notified, 1);
    expect(controller.state.visibleHits.map((h) => h.id), ['card-1']);

    controller.setFilter(SearchFilter.collections);
    expect(controller.state.visibleHits.map((h) => h.id), ['col-1']);
  });

  test('opening a card hit targets its collection and focuses the card', () {
    controller.open(
      const SearchHit(
        kind: SearchHitKind.card,
        id: 'card-1',
        collectionId: 'col',
        collectionTitle: 'Col',
        field: SearchField.cardText,
        snippet: 'tea',
        ranges: [],
      ),
    );
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
}
