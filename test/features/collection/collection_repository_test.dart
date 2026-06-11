import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/core/ids/uuid_id_generator.dart';
import 'package:knit/core/ordering/fractional_index.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/infra/sync_store_collection_read_repository.dart';
import 'package:knit/features/collection/infra/sync_store_collection_write_repository.dart';
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
    expect(data.linkTargets, isEmpty);
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

  test('edit a card updates its body, reorder changes feed order', () async {
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

    await write.editCardText(c1, 'first (edited)');
    var data = await load(colId);
    expect(data.cards.first.text, 'first (edited)');

    // Move c1 to the end (position after 'a1').
    await write.reorderCard(c1, FractionalIndex.keyAfter('a1'));
    data = await load(colId);
    expect(data.cards.map((c) => c.text), ['second', 'first (edited)']);
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

    // The finder offers the other collection.
    final data = await load(colId);
    expect(data.linkTargets.map((t) => t.collectionId), [otherId]);

    await write.linkCardToCollection(cardId: cardId, collectionId: otherId);

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
