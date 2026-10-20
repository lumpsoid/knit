import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/features/search/domain/search_models.dart';
import 'package:knit/features/search/infra/sync_store_search_read_repository.dart';
import 'package:knit/sync/sync.dart';

/// [SyncStoreSearchReadRepository] over a real in-memory [SyncStore]: which
/// entities become documents, and which texts they are searchable by.
void main() {
  late SyncStore store;
  late SyncStoreSearchReadRepository repo;

  setUp(() async {
    store = SyncStore.inMemory();
    await store.open();
    final graph = AppGraph()..bindStore(store);
    repo = SyncStoreSearchReadRepository(graph: graph);
  });

  Future<Map<String, SearchDocument>> load() async => {
    for (final d in (await repo.loadDocuments()).getOrThrow()) d.id: d,
  };

  Map<SearchField, List<String>> textsOf(SearchDocument d) {
    final out = <SearchField, List<String>>{};
    for (final t in d.texts) {
      (out[t.field] ??= []).add(t.text);
    }
    return out;
  }

  Future<void> addCollection(String id, String title, {String? description}) =>
      store.create(EntityType.collection, id, {
        'title': title,
        'description': description,
      });

  Future<void> addCard(
    String id,
    String collectionId, {
    String kind = 'text',
    String? text,
    String? attachmentId,
  }) => store.create(EntityType.card, id, {
    'collection_id': collectionId,
    'kind': kind,
    'text': text,
    'attachment_id': attachmentId,
  }, position: 'a0');

  test('collections are searchable by title and description', () async {
    await addCollection('col', 'Garden', description: 'veg beds');
    final doc = (await load())['col']!;
    expect(doc.kind, SearchHitKind.collection);
    expect(doc.collectionId, 'col');
    expect(textsOf(doc), {
      SearchField.collectionTitle: ['Garden'],
      SearchField.description: ['veg beds'],
    });
  });

  test('cards carry their text, kind and collection', () async {
    await addCollection('col', 'Garden');
    await addCard('c1', 'col', kind: 'link', text: 'https://example.com');
    final doc = (await load())['c1']!;
    expect(doc.kind, SearchHitKind.card);
    expect(doc.collectionId, 'col');
    expect(doc.collectionTitle, 'Garden');
    expect(doc.cardKind, 'link');
    expect(textsOf(doc), {
      SearchField.cardText: ['https://example.com'],
    });
  });

  test("a card is searchable by its attachment's file name", () async {
    await addCollection('col', 'Garden');
    await store.create(EntityType.attachment, 'att', {
      'kind': 'file',
      'mime': 'application/pdf',
      'content_hash': 'h',
      'size': 1,
      'name': 'seed-catalogue.pdf',
    });
    await addCard('c1', 'col', kind: 'file', attachmentId: 'att');
    expect(textsOf((await load())['c1']!), {
      SearchField.fileName: ['seed-catalogue.pdf'],
    });
  });

  test('a link label is searchable on its source entity', () async {
    await addCollection('col', 'Garden');
    await addCard('c1', 'col', text: 'tomatoes');
    await store.create(EntityType.link, 'l1', {
      'source_type': 'card',
      'source_id': 'c1',
      'target_type': 'collection',
      'target_id': 'col',
      'label': 'see also',
    });
    expect(textsOf((await load())['c1']!)[SearchField.linkLabel], ['see also']);
  });

  test(
    'deleted entities and cards of deleted collections are left out',
    () async {
      await addCollection('live', 'Live');
      await addCollection('gone', 'Gone');
      await addCard('c-live', 'live', text: 'kept');
      await addCard('c-deleted', 'live', text: 'deleted');
      await addCard('c-orphan', 'gone', text: 'orphaned');
      await store.delete(EntityType.card, 'c-deleted');
      await store.delete(EntityType.collection, 'gone');

      expect((await load()).keys.toSet(), {'live', 'c-live'});
    },
  );

  test(
    'archived collections and their cards stay searchable, flagged',
    () async {
      await addCollection('old', 'Old trips');
      await addCard('card-old', 'old', text: 'Rome');
      await addCollection('live', 'Trips');
      await addCard('card-live', 'live', text: 'Oslo');
      await store.setCollectionArchived('old', archived: true);

      final docs = await load();
      expect(docs['old']!.archived, isTrue);
      expect(docs['card-old']!.archived, isTrue);
      expect(docs['live']!.archived, isFalse);
      expect(docs['card-live']!.archived, isFalse);
    },
  );
}
