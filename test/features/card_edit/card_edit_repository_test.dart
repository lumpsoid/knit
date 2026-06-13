import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/core/ids/uuid_id_generator.dart';
import 'package:knit/features/card_edit/infra/sync_store_card_edit_write_repository.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/infra/sync_store_collection_read_repository.dart';
import 'package:knit/features/collection/infra/sync_store_collection_write_repository.dart';
import 'package:knit/features/timeline/infra/sync_store_timeline_write_repository.dart';
import 'package:knit/sync/sync.dart';

/// Drives the §4.3 card-edit write through the [SyncStoreCardEditWriteRepository]
/// over a real in-memory [SyncStore], asserting the edited body lands in the
/// projection feed read back through the Collection read repo.
void main() {
  late AppGraph graph;
  late SyncStore store;
  late SyncStoreTimelineWriteRepository timelineWrite;
  late SyncStoreCollectionReadRepository read;
  late SyncStoreCollectionWriteRepository collectionWrite;
  late SyncStoreCardEditWriteRepository cardEditWrite;

  setUp(() async {
    graph = AppGraph();
    store = SyncStore.inMemory();
    await store.open();
    graph.bindStore(store);
    const ids = UuidIdGenerator();
    timelineWrite = SyncStoreTimelineWriteRepository(graph: graph, ids: ids);
    read = SyncStoreCollectionReadRepository(graph: graph);
    collectionWrite = SyncStoreCollectionWriteRepository(graph: graph, ids: ids);
    cardEditWrite = SyncStoreCardEditWriteRepository(graph: graph);
  });

  test('editCard updates the card body in the feed', () async {
    final colId =
        (await timelineWrite.createCollection('Espresso')).getOrThrow();
    final cardId = (await collectionWrite.addCard(
      collectionId: colId,
      kind: CardKind.text,
      position: 'a0',
      text: 'first',
    ))
        .getOrThrow();

    final result =
        await cardEditWrite.editCard(cardId: cardId, text: 'first (edited)');
    expect(result.getOrThrow(), cardId);

    final data = (await read.loadCollection(colId)).getOrThrow();
    expect(data.cards.single.text, 'first (edited)');
  });
}
