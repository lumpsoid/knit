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
    ))
        .getOrThrow();
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
    ))
        .getOrThrow();

    // First level: every live collection (including the source's own).
    final collections = (await read.loadLinkCollections()).getOrThrow();
    expect(
      collections.map((o) => o.id).toSet(),
      {colId, otherId},
    );
    expect(collections.every((o) => o.kind == ConnectedEntityKind.collection),
        isTrue);

    // Drilled level: that collection's cards (the page drops the source card).
    final cards = (await read.loadCollectionCards(otherId)).getOrThrow();
    expect(cards.map((o) => o.id), [otherCardId]);
    expect(cards.single.kind, ConnectedEntityKind.card);
    expect(cards.single.label, 'pour-over');
  });

  test('link a card to a collection; deleting the target breaks the link',
      () async {
    final colId = await createCollection('Espresso');
    final otherId = await createCollection('Recipes');
    final cardId = (await write.addCard(
      collectionId: colId,
      kind: CardKind.text,
      position: 'a0',
      text: 'see recipes',
    ))
        .getOrThrow();

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
  });

  test('link a card to another card writes a card→card link', () async {
    final colId = await createCollection('Espresso');
    final src = (await write.addCard(
      collectionId: colId,
      kind: CardKind.text,
      position: 'a0',
      text: 'source',
    ))
        .getOrThrow();
    final dst = (await write.addCard(
      collectionId: colId,
      kind: CardKind.text,
      position: 'a1',
      text: 'target',
    ))
        .getOrThrow();

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

  test('connectionCount counts links at both ends, without double-counting',
      () async {
    final colId = await createCollection('Espresso');
    final src = (await write.addCard(
      collectionId: colId,
      kind: CardKind.text,
      position: 'a0',
      text: 'source',
    ))
        .getOrThrow();
    final dst = (await write.addCard(
      collectionId: colId,
      kind: CardKind.text,
      position: 'a1',
      text: 'target',
    ))
        .getOrThrow();

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
    expect({for (final c in cards) c.id: c.connectionCount}, {
      src: 1,
      dst: 1,
    });
  });

  test('deleting a card removes it from the feed', () async {
    final colId = await createCollection('Espresso');
    final cardId = (await write.addCard(
      collectionId: colId,
      kind: CardKind.text,
      position: 'a0',
      text: 'temp note',
    ))
        .getOrThrow();

    expect((await load(colId)).cards, hasLength(1));
    await write.deleteCard(cardId);
    expect((await load(colId)).cards, isEmpty);
  });
}
