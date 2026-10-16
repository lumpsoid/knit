import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/core/ids/uuid_id_generator.dart';
import 'package:knit/core/ordering/fractional_index.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/infra/sync_store_collection_read_repository.dart';
import 'package:knit/features/collection/infra/sync_store_collection_write_repository.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/features/timeline/infra/sync_store_timeline_write_repository.dart';
import 'package:knit/sync/sync.dart';

/// Drives the §9.1 slice flow (create → cards → edit → reorder → link → delete)
/// through the Collection/Timeline repos over a real in-memory [SyncStore], so
/// the feature wiring is exercised against the signed write path end to end.
void main() {
  late AppGraph graph;
  late SyncStore store;
  late SyncStoreTimelineWriteRepository timelineWrite;
  late SyncStoreCollectionReadRepository read;
  late SyncStoreCollectionWriteRepository write;

  setUp(() async {
    graph = AppGraph();
    store = SyncStore.inMemory();
    await store.open();
    graph.bindStore(store);
    const ids = UuidIdGenerator();
    timelineWrite = SyncStoreTimelineWriteRepository(graph: graph, ids: ids);
    read = SyncStoreCollectionReadRepository(graph: graph);
    write = SyncStoreCollectionWriteRepository(graph: graph, ids: ids);
  });

  Future<String> createCollection(String title) async =>
      (await timelineWrite.createCollection(title)).getOrThrow();

  Future<CollectionData> load(String id) async =>
      (await read.loadCollection(id)).getOrThrow();

  test('create collection then load shows an empty feed', () async {
    final colId = await createCollection('Espresso');
    final data = await load(colId);
    expect(data.title, 'Espresso');
    expect(data.cards, isEmpty);
  });

  test('append cards keeps feed order by position', () async {
    final colId = await createCollection('Espresso');
    await write.addCard(
      collectionId: colId,
      kind: CardKind.text,
      position: FractionalIndex.first(),
      text: 'grind finer',
    );
    await write.addCard(
      collectionId: colId,
      kind: CardKind.text,
      position: FractionalIndex.keyAfter(FractionalIndex.first()),
      text: 'tamp level',
    );

    final data = await load(colId);
    expect(data.cards.map((c) => c.text), ['grind finer', 'tamp level']);
  });

  test('reorder changes feed order', () async {
    final colId = await createCollection('Espresso');
    final c1 = (await write.addCard(
      collectionId: colId,
      kind: CardKind.text,
      position: 'a0',
      text: 'first',
    )).getOrThrow();
    await write.addCard(
      collectionId: colId,
      kind: CardKind.text,
      position: 'a1',
      text: 'second',
    );

    // Move c1 to the end (position after 'a1').
    await write.reorderCard(c1, FractionalIndex.keyAfter('a1'));
    final data = await load(colId);
    expect(data.cards.map((c) => c.text), ['second', 'first']);
  });

  test('finder offers live collections, then a collection\'s cards', () async {
    final colId = await createCollection('Espresso');
    final otherId = await createCollection('Recipes');
    await write.addCard(
      collectionId: colId,
      kind: CardKind.text,
      position: 'a0',
      text: 'see recipes',
    );
    final otherCardId = (await write.addCard(
      collectionId: otherId,
      kind: CardKind.text,
      position: 'a0',
      text: 'pour-over',
    )).getOrThrow();

    // First level: every live collection (including the source's own).
    final collections = (await read.loadLinkCollections()).getOrThrow();
    expect(collections.map((o) => o.id).toSet(), {colId, otherId});
    expect(
      collections.every((o) => o.kind == ConnectedEntityKind.collection),
      isTrue,
    );

    // Drilled level: that collection's cards (the page drops the source card).
    final cards = (await read.loadCollectionCards(otherId)).getOrThrow();
    expect(cards.map((o) => o.id), [otherCardId]);
    expect(cards.single.kind, ConnectedEntityKind.card);
    expect(cards.single.label, 'pour-over');
  });

  test(
    'link a card to a collection; deleting the target breaks the link',
    () async {
      final colId = await createCollection('Espresso');
      final otherId = await createCollection('Recipes');
      final cardId = (await write.addCard(
        collectionId: colId,
        kind: CardKind.text,
        position: 'a0',
        text: 'see recipes',
      )).getOrThrow();

      await write.linkCardToTarget(
        cardId: cardId,
        targetKind: ConnectedEntityKind.collection,
        targetId: otherId,
      );

      final links = await store.linksOut(cardId);
      expect(links, hasLength(1));
      expect((await store.linkStatus(links.single)).isBroken, isFalse);

      // Delete the target endpoint → the link renders broken (§8.6.1), not gone.
      await store.delete(EntityType.collection, otherId);
      final after = await store.linksOut(cardId);
      expect(after, hasLength(1), reason: 'the link is never auto-removed');
      final status = await store.linkStatus(after.single);
      expect(status.isBroken, isTrue);
      expect(status.targetBroken, isTrue);
    },
  );

  test('link a card to another card writes a card→card link', () async {
    final colId = await createCollection('Espresso');
    final src = (await write.addCard(
      collectionId: colId,
      kind: CardKind.text,
      position: 'a0',
      text: 'source',
    )).getOrThrow();
    final dst = (await write.addCard(
      collectionId: colId,
      kind: CardKind.text,
      position: 'a1',
      text: 'target',
    )).getOrThrow();

    await write.linkCardToTarget(
      cardId: src,
      targetKind: ConnectedEntityKind.card,
      targetId: dst,
    );

    final links = await store.linksOut(src);
    expect(links, hasLength(1));
    expect((await store.linkStatus(links.single)).isBroken, isFalse);
    // The target card now has a backlink from the source card.
    expect(await store.backlinks(dst), hasLength(1));
  });

  test(
    'connectionCount counts links at both ends, without double-counting',
    () async {
      final colId = await createCollection('Espresso');
      final src = (await write.addCard(
        collectionId: colId,
        kind: CardKind.text,
        position: 'a0',
        text: 'source',
      )).getOrThrow();
      final dst = (await write.addCard(
        collectionId: colId,
        kind: CardKind.text,
        position: 'a1',
        text: 'target',
      )).getOrThrow();

      // No links yet → no badge for either card.
      var cards = (await load(colId)).cards;
      expect(cards.map((c) => c.connectionCount), [0, 0]);

      // Link source → target. Both ends show the link once: the source via its
      // link-out, the target via its backlink. Neither is double-counted.
      await write.linkCardToTarget(
        cardId: src,
        targetKind: ConnectedEntityKind.card,
        targetId: dst,
      );
      cards = (await load(colId)).cards;
      expect(
        {for (final c in cards) c.id: c.connectionCount},
        {src: 1, dst: 1},
      );
    },
  );

  test(
    'collection connectionCount counts links to the collection itself',
    () async {
      final colId = await createCollection('Espresso');
      final otherId = await createCollection('Recipes');
      final cardId = (await write.addCard(
        collectionId: colId,
        kind: CardKind.text,
        position: 'a0',
        text: 'see recipes',
      )).getOrThrow();

      // Before linking: neither collection is linked.
      expect((await load(colId)).connectionCount, 0);
      expect((await load(otherId)).connectionCount, 0);

      await write.linkCardToTarget(
        cardId: cardId,
        targetKind: ConnectedEntityKind.collection,
        targetId: otherId,
      );

      // The target collection now has one backlink; the source collection is
      // unaffected (the link sits on the card, not the collection itself).
      expect((await load(otherId)).connectionCount, 1);
      expect((await load(colId)).connectionCount, 0);
    },
  );

  test('deleting a card removes it from the feed', () async {
    final colId = await createCollection('Espresso');
    final cardId = (await write.addCard(
      collectionId: colId,
      kind: CardKind.text,
      position: 'a0',
      text: 'temp note',
    )).getOrThrow();

    expect((await load(colId)).cards, hasLength(1));
    await write.deleteCard(cardId);
    expect((await load(colId)).cards, isEmpty);
  });

  test(
    'isAttachmentReferenced tracks live cards pointing at an attachment',
    () async {
      final colId = await createCollection('Espresso');
      final cardId = (await write.addCard(
        collectionId: colId,
        kind: CardKind.image,
        position: 'a0',
        attachmentId: 'att-1',
      )).getOrThrow();

      expect((await read.isAttachmentReferenced('att-1')).getOrThrow(), isTrue);
      expect(
        (await read.isAttachmentReferenced('missing')).getOrThrow(),
        isFalse,
      );

      await write.deleteCard(cardId);
      expect(
        (await read.isAttachmentReferenced('att-1')).getOrThrow(),
        isFalse,
      );
    },
  );

  group('paged feed (§8.7)', () {
    late String colId;
    late List<String> texts;

    setUp(() async {
      colId = await createCollection('Big');
      texts = [for (var i = 0; i < 7; i++) 'c$i'];
      var position = FractionalIndex.first();
      for (final t in texts) {
        await write.addCard(
          collectionId: colId,
          kind: CardKind.text,
          position: position,
          text: t,
        );
        position = FractionalIndex.keyAfter(position);
      }
    });

    Future<CollectionData> loadWindow(FeedWindow window) async =>
        (await read.loadCollection(colId, window: window)).getOrThrow();

    test('latest loads the newest page in feed order + a boundary', () async {
      final data = await loadWindow(const FeedWindow.latest(3));
      expect(data.cards.map((c) => c.text), ['c4', 'c5', 'c6']);
      expect(data.olderBoundary, isNotNull);
    });

    test('a page covering the whole feed has no boundary', () async {
      final data = await loadWindow(const FeedWindow.latest(7));
      expect(data.cards, hasLength(7));
      expect(data.olderBoundary, isNull);
    });

    test('loadOlderCards walks back to the head of the feed', () async {
      final first = await loadWindow(const FeedWindow.latest(3));
      final page1 = (await read.loadOlderCards(
        colId,
        before: FeedCursor.of(first.cards.first),
        limit: 3,
      )).getOrThrow();
      expect(page1.cards.map((c) => c.text), ['c1', 'c2', 'c3']);
      final all = await loadWindow(const FeedWindow.all());
      expect(page1.olderBoundary, FeedCursor.of(all.cards[0]));

      final page2 = (await read.loadOlderCards(
        colId,
        before: FeedCursor.of(page1.cards.first),
        limit: 3,
      )).getOrThrow();
      expect(page2.cards.map((c) => c.text), ['c0']);
      expect(page2.olderBoundary, isNull);
    });

    test('from(cursor) resyncs the window from its oldest card up', () async {
      final first = await loadWindow(const FeedWindow.latest(3));
      final data = await loadWindow(
        FeedWindow.from(FeedCursor.of(first.cards[1])),
      );
      expect(data.cards.map((c) => c.text), ['c5', 'c6']);
      expect(data.olderBoundary, FeedCursor.of(first.cards[0]));
    });

    test('through(card) reaches back to include an old card', () async {
      final all = await loadWindow(const FeedWindow.all());
      final data = await loadWindow(FeedWindow.through(all.cards[1].id, 3));
      expect(data.cards.map((c) => c.text), texts.sublist(1));
      expect(data.olderBoundary, FeedCursor.of(all.cards[0]));
    });

    test('through(unknown card) falls back to the latest page', () async {
      final data = await loadWindow(const FeedWindow.through('nope', 3));
      expect(data.cards.map((c) => c.text), ['c4', 'c5', 'c6']);
    });

    test(
      'batched link counts match per-card links in both directions',
      () async {
        final all = await loadWindow(const FeedWindow.all());
        final a = all.cards[5].id;
        final b = all.cards[6].id;
        await write.linkCardToTarget(
          cardId: a,
          targetKind: ConnectedEntityKind.card,
          targetId: b,
        );
        await write.linkCardToTarget(
          cardId: b,
          targetKind: ConnectedEntityKind.collection,
          targetId: colId,
        );
        final data = await loadWindow(const FeedWindow.latest(2));
        expect(data.cards.map((c) => c.connectionCount), [1, 2]);
        expect(data.connectionCount, 1);
      },
    );
  });
}
