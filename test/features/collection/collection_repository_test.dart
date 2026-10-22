import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/core/ids/uuid_id_generator.dart';
import 'package:knit/core/ordering/fractional_index.dart';
import 'package:knit/features/card_links/infra/sync_store_card_links_write_repository.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/domain/link_chip.dart';
import 'package:knit/features/collection/domain/link_tile.dart';
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
  late SyncStoreCardLinksWriteRepository linkWrite;

  setUp(() async {
    graph = AppGraph();
    store = SyncStore.inMemory();
    await store.open();
    graph.bindStore(store);
    const ids = UuidIdGenerator();
    timelineWrite = SyncStoreTimelineWriteRepository(graph: graph, ids: ids);
    read = SyncStoreCollectionReadRepository(graph: graph);
    write = SyncStoreCollectionWriteRepository(graph: graph, ids: ids);
    linkWrite = SyncStoreCardLinksWriteRepository(graph: graph, ids: ids);
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

      await linkWrite.addLink(
        sourceKind: ConnectedEntityKind.card,
        sourceId: cardId,
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

  group('link tile (§4.2)', () {
    Future<String> addText(String colId, String position, String text) async =>
        (await write.addCard(
          collectionId: colId,
          kind: CardKind.text,
          position: position,
          text: text,
        )).getOrThrow();

    Future<void> linkTo(String cardId, String colId) async =>
        (await linkWrite.addLink(
          sourceKind: ConnectedEntityKind.card,
          sourceId: cardId,
          targetKind: ConnectedEntityKind.collection,
          targetId: colId,
        )).getOrThrow();

    test('a label card linking to a collection gets its tile', () async {
      final index = await createCollection('Index');
      final trips = await createCollection('Trips');
      await addText(trips, 'a0', 'Rome');
      await addText(trips, 'a1', 'Lisbon');
      final label = await addText(index, 'a0', 'trips');
      final note = await addText(
        index,
        'a1',
        'A long note about everything\nthat also links to Trips.',
      );
      await linkTo(label, trips);
      await linkTo(note, trips);

      final cards = (await load(index)).cards;
      final tile =
          cards.firstWhere((c) => c.id == label).linkTile
              as CollectionLinkTile?;
      expect(tile?.collectionId, trips);
      expect(tile?.title, 'Trips');
      expect(tile?.cardCount, 2);
      expect(tile?.lastCardText, 'Lisbon');
      expect(tile?.caption, isNull, reason: 'the label repeats the title');
      expect(
        cards.firstWhere((c) => c.id == note).linkTile,
        isNull,
        reason: 'a note is more than a link',
      );
    });

    test('a Connection card is one write and renders as the tile', () async {
      final index = await createCollection('Index');
      final trips = await createCollection('Trips');
      final cardId = (await write.addConnectionCard(
        collectionId: index,
        position: 'a0',
        targetKind: ConnectedEntityKind.collection,
        targetId: trips,
      )).getOrThrow();

      final card = (await load(index)).cards.single;
      expect(card.id, cardId);
      expect(card.kind, CardKind.link);
      expect(card.text, isNull);
      final tile = card.linkTile as CollectionLinkTile?;
      expect(tile?.collectionId, trips);
      expect(tile?.caption, isNull);
      expect(card.linkChips, isEmpty, reason: 'the tile stands for its link');
      expect(card.backlinkCount, 0);
    });

    test('a Connection card to a card renders the card tile', () async {
      final index = await createCollection('Index');
      final trips = await createCollection('Trips');
      final lisbon = await addText(trips, 'a0', 'Lisbon\nin May');
      final photo = (await write.addCard(
        collectionId: trips,
        kind: CardKind.image,
        position: 'a1',
        attachmentId: 'att-photo',
      )).getOrThrow();
      await store.setCardsSettled([lisbon], settled: true);
      final toText = (await write.addConnectionCard(
        collectionId: index,
        position: 'a0',
        targetKind: ConnectedEntityKind.card,
        targetId: lisbon,
      )).getOrThrow();
      final toPhoto = (await write.addConnectionCard(
        collectionId: index,
        position: 'a1',
        targetKind: ConnectedEntityKind.card,
        targetId: photo,
      )).getOrThrow();

      final cards = (await load(index)).cards;
      expect(
        cards.firstWhere((c) => c.id == toText).linkTile,
        CardLinkTile(
          cardId: lisbon,
          cardKind: 'text',
          collectionId: trips,
          collectionTitle: 'Trips',
          preview: 'Lisbon\nin May',
          settled: true,
        ),
      );
      expect(
        cards.firstWhere((c) => c.id == toPhoto).linkTile,
        CardLinkTile(
          cardId: photo,
          cardKind: 'image',
          collectionId: trips,
          collectionTitle: 'Trips',
          thumbnailAttachmentId: 'att-photo',
        ),
      );
    });

    test('a deleted target card keeps the plain bubble', () async {
      final index = await createCollection('Index');
      final trips = await createCollection('Trips');
      final lisbon = await addText(trips, 'a0', 'Lisbon');
      await write.addConnectionCard(
        collectionId: index,
        position: 'a0',
        targetKind: ConnectedEntityKind.card,
        targetId: lisbon,
      );
      await store.delete(EntityType.card, lisbon);

      final card = (await load(index)).cards.single;
      expect(card.linkTile, isNull);
      expect(card.linkChips, [const BrokenLinkChip()]);
    });

    test('a deleted target keeps the plain bubble (broken link)', () async {
      final index = await createCollection('Index');
      final trips = await createCollection('Trips');
      final label = await addText(index, 'a0', 'Trips');
      await linkTo(label, trips);
      await store.delete(EntityType.collection, trips);

      final card = (await load(index)).cards.single;
      expect(card.linkTile, isNull);
      expect(card.linkChips, [const BrokenLinkChip()]);
      expect(card.backlinkCount, 0);
    });

    test('an archived target collection marks the tile', () async {
      final index = await createCollection('Index');
      final trips = await createCollection('Trips');
      final lisbon = await addText(trips, 'a0', 'Lisbon');
      final toTrips = await addText(index, 'a0', 'Trips');
      await linkTo(toTrips, trips);
      final toLisbon = (await write.addConnectionCard(
        collectionId: index,
        position: 'a1',
        targetKind: ConnectedEntityKind.card,
        targetId: lisbon,
      )).getOrThrow();
      await store.setCollectionArchived(trips, archived: true);

      final cards = (await load(index)).cards;
      expect(
        cards.firstWhere((c) => c.id == toTrips).linkTile?.archived,
        isTrue,
      );
      expect(
        cards.firstWhere((c) => c.id == toLisbon).linkTile?.archived,
        isTrue,
      );
    });

    test('a card linking to a collection and a card gets none', () async {
      final index = await createCollection('Index');
      final trips = await createCollection('Trips');
      final label = await addText(index, 'a0', 'Trips');
      final other = await addText(index, 'a1', 'other');
      await linkTo(label, trips);
      await linkWrite.addLink(
        sourceKind: ConnectedEntityKind.card,
        sourceId: label,
        targetKind: ConnectedEntityKind.card,
        targetId: other,
      );
      final cards = (await load(index)).cards;
      expect(cards.every((c) => c.linkTile == null), isTrue);
    });
  });

  group('link chips and backlinks (§4.2)', () {
    Future<String> addText(String colId, String position, String text) async =>
        (await write.addCard(
          collectionId: colId,
          kind: CardKind.text,
          position: position,
          text: text,
        )).getOrThrow();

    Future<void> link(
      String cardId,
      ConnectedEntityKind kind,
      String targetId,
    ) async => (await linkWrite.addLink(
      sourceKind: ConnectedEntityKind.card,
      sourceId: cardId,
      targetKind: kind,
      targetId: targetId,
    )).getOrThrow();

    test('a note gets a chip per link out, live targets first', () async {
      final index = await createCollection('Index');
      final trips = await createCollection('Trips');
      final gone = await createCollection('Gone');
      final lisbon = await addText(trips, 'a0', 'Lisbon\nin May');
      final file = (await write.addCard(
        collectionId: trips,
        kind: CardKind.file,
        position: 'a1',
        attachmentId: 'att-file',
      )).getOrThrow();
      final note = await addText(index, 'a0', 'A long note, linking out.');
      await link(note, ConnectedEntityKind.collection, gone);
      await link(note, ConnectedEntityKind.collection, trips);
      await link(note, ConnectedEntityKind.card, lisbon);
      await link(note, ConnectedEntityKind.card, file);
      await store.delete(EntityType.collection, gone);
      await store.setCollectionArchived(trips, archived: true);

      final card = (await load(index)).cards.single;
      expect(card.linkTile, isNull);
      expect(card.linkChips, [
        CollectionLinkChip(collectionId: trips, title: 'Trips', archived: true),
        CardLinkChip(
          cardId: lisbon,
          cardKind: 'text',
          collectionId: trips,
          preview: 'Lisbon\nin May',
          archived: true,
        ),
        CardLinkChip(
          cardId: file,
          cardKind: 'file',
          collectionId: trips,
          archived: true,
        ),
        const BrokenLinkChip(),
      ]);
    });

    test('a card-to-card link reads once: a chip out, a badge in', () async {
      final colId = await createCollection('Espresso');
      // Two lines: a note, not a label, so it keeps its bubble and chips.
      final src = await addText(colId, 'a0', 'source\nsee below');
      final dst = await addText(colId, 'a1', 'target');

      var cards = (await load(colId)).cards;
      expect(cards.map((c) => c.backlinkCount), [0, 0]);
      expect(cards.every((c) => c.linkChips.isEmpty), isTrue);

      await link(src, ConnectedEntityKind.card, dst);
      cards = (await load(colId)).cards;
      final byId = {for (final c in cards) c.id: c};
      expect(byId[src]!.linkChips, [
        CardLinkChip(
          cardId: dst,
          cardKind: 'text',
          collectionId: colId,
          preview: 'target',
        ),
      ]);
      expect(byId[src]!.backlinkCount, 0);
      expect(byId[dst]!.linkChips, isEmpty);
      expect(byId[dst]!.backlinkCount, 1);
    });
  });

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

    await linkWrite.addLink(
      sourceKind: ConnectedEntityKind.card,
      sourceId: src,
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

      await linkWrite.addLink(
        sourceKind: ConnectedEntityKind.card,
        sourceId: cardId,
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

    test('batched backlink counts and chips match per-card links', () async {
      final all = await loadWindow(const FeedWindow.all());
      final a = all.cards[5].id;
      final b = all.cards[6].id;
      await linkWrite.addLink(
        sourceKind: ConnectedEntityKind.card,
        sourceId: a,
        targetKind: ConnectedEntityKind.card,
        targetId: b,
      );
      await linkWrite.addLink(
        sourceKind: ConnectedEntityKind.card,
        sourceId: b,
        targetKind: ConnectedEntityKind.collection,
        targetId: colId,
      );
      final data = await loadWindow(const FeedWindow.latest(2));
      expect(data.cards.map((c) => c.backlinkCount), [0, 1]);
      // Short labels with one link each: their tiles stand for the links.
      expect(data.cards.map((c) => c.linkTile != null), [true, true]);
      expect(data.cards.every((c) => c.linkChips.isEmpty), isTrue);
      expect(data.connectionCount, 1);
    });
  });
}
