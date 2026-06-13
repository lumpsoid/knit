import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/core/ids/uuid_id_generator.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/infra/sync_store_collection_write_repository.dart';
import 'package:knit/features/sync_status/infra/sync_store_sync_status_read_repository.dart';
import 'package:knit/features/timeline/infra/sync_store_timeline_write_repository.dart';
import 'package:knit/sync/sync.dart';

/// Drives the §4.8/§6.6 sync marker's read port over a real in-memory
/// [SyncStore]: with no relay, every local op is unacked, so the pending count
/// is exactly the number of local writes — and only grows.
void main() {
  late AppGraph graph;
  late SyncStore store;
  late SyncStoreTimelineWriteRepository timelineWrite;
  late SyncStoreCollectionWriteRepository collectionWrite;
  late SyncStoreSyncStatusReadRepository read;

  setUp(() async {
    graph = AppGraph();
    store = SyncStore.inMemory();
    await store.open();
    graph.bindStore(store);
    const ids = UuidIdGenerator();
    timelineWrite = SyncStoreTimelineWriteRepository(graph: graph, ids: ids);
    collectionWrite = SyncStoreCollectionWriteRepository(graph: graph, ids: ids);
    read = SyncStoreSyncStatusReadRepository(graph: graph);
  });

  Future<int> pending() async => (await read.pendingCount()).getOrThrow();

  test('a fresh store has nothing pending', () async {
    expect(await pending(), 0);
  });

  test('every local op stays pending until a relay acks it (§6.6)', () async {
    final collection =
        (await timelineWrite.createCollection('Espresso')).getOrThrow();
    expect(await pending(), 1);

    await collectionWrite.addCard(
      collectionId: collection,
      kind: CardKind.text,
      position: 'a0',
      text: 'first card',
    );
    expect(await pending(), 2);
  });
}
