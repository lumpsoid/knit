import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/features/collection_widget/infra/sync_store_collection_widget_read_repository.dart';
import 'package:knit/sync/sync.dart';

/// The widget's reads over a real in-memory [SyncStore].
void main() {
  late SyncStore store;
  late SyncStoreCollectionWidgetReadRepository read;

  setUp(() async {
    store = SyncStore.inMemory();
    await store.open();
    read = SyncStoreCollectionWidgetReadRepository(
      graph: AppGraph()..bindStore(store),
    );
  });

  Future<void> collection(String id, String title) => store.create(
    EntityType.collection,
    id,
    {'title': title, 'cover_attachment_id': null},
  );

  test('targets are the live collections', () async {
    await collection('a', 'Coffee');
    await collection('b', 'Books');
    await store.delete(EntityType.collection, 'b');
    final targets = (await read.loadTargets()).getOrThrow();
    expect(targets.map((t) => t.title), ['Coffee']);
  });

  test('liveTitles skips deleted and unknown collections', () async {
    await collection('a', 'Coffee');
    await collection('b', 'Books');
    await store.delete(EntityType.collection, 'b');
    final titles = (await read.liveTitles({'a', 'b', 'nope'})).getOrThrow();
    expect(titles, {'a': 'Coffee'});
    expect((await read.liveTitles({})).getOrThrow(), isEmpty);
  });
}
