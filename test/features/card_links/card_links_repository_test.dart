import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/core/ids/uuid_id_generator.dart';
import 'package:knit/features/card_links/infra/sync_store_card_links_write_repository.dart';
import 'package:knit/features/card_links/infra/sync_store_link_targets_read_repository.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/infra/sync_store_collection_write_repository.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/features/timeline/infra/sync_store_timeline_write_repository.dart';
import 'package:knit/sync/sync.dart';

/// Drives the shared card-links ports over a real in-memory [SyncStore]: the
/// picker's two lazily read levels, and the add/remove link round trip.
void main() {
  late SyncStore store;
  late SyncStoreTimelineWriteRepository timelineWrite;
  late SyncStoreCollectionWriteRepository collectionWrite;
  late SyncStoreLinkTargetsReadRepository targets;
  late SyncStoreCardLinksWriteRepository links;

  setUp(() async {
    final graph = AppGraph();
    store = SyncStore.inMemory();
    await store.open();
    graph.bindStore(store);
    const ids = UuidIdGenerator();
    timelineWrite = SyncStoreTimelineWriteRepository(graph: graph, ids: ids);
    collectionWrite = SyncStoreCollectionWriteRepository(
      graph: graph,
      ids: ids,
    );
    targets = SyncStoreLinkTargetsReadRepository(graph: graph);
    links = SyncStoreCardLinksWriteRepository(graph: graph, ids: ids);
  });

  Future<String> newCollection(String title) async =>
      (await timelineWrite.createCollection(title)).getOrThrow();

  Future<String> newCard(String colId, String text, String position) async =>
      (await collectionWrite.addCard(
        collectionId: colId,
        kind: CardKind.text,
        position: position,
        text: text,
      )).getOrThrow();

  test('the collections level lists every live collection', () async {
    final a = await newCollection('Espresso');
    final b = await newCollection('Recipes');
    final gone = await newCollection('Gone');
    await store.delete(EntityType.collection, gone);

    final level = (await targets.loadCollections()).getOrThrow();
    expect(level.map((t) => t.id).toSet(), {a, b});
    expect(
      level.every((t) => t.kind == ConnectedEntityKind.collection),
      isTrue,
    );
  });

  test('the drilled level lists a collection\'s live cards in order', () async {
    final col = await newCollection('Recipes');
    final first = await newCard(col, 'pour-over', 'a0');
    final second = await newCard(col, 'aeropress', 'a1');
    final deleted = await newCard(col, 'gone', 'a2');
    await collectionWrite.deleteCard(deleted);

    final level = (await targets.loadCards(col)).getOrThrow();
    expect(level.map((t) => t.id), [first, second]);
    expect(level.first.kind, ConnectedEntityKind.card);
    expect(level.first.label, 'pour-over');
  });

  test('addLink writes a card link; removeLink deletes only it', () async {
    final col = await newCollection('Espresso');
    final other = await newCollection('Recipes');
    final card = await newCard(col, 'see recipes', 'a0');

    final linkId = (await links.addLink(
      sourceKind: ConnectedEntityKind.card,
      sourceId: card,
      targetKind: ConnectedEntityKind.collection,
      targetId: other,
    )).getOrThrow();
    expect((await store.linksOut(card)).single.id, linkId);

    await links.removeLink(linkId);
    expect(await store.linksOut(card), isEmpty);
    expect((await store.get(EntityType.card, card))?.deleted, isFalse);
  });
}
