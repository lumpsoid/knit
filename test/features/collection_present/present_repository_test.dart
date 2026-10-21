import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection_present/domain/present_failure.dart';
import 'package:knit/features/collection_present/domain/present_models.dart';
import 'package:knit/features/collection_present/infra/in_memory_present_progress_repository.dart';
import 'package:knit/features/collection_present/infra/sync_store_present_read_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [SyncStorePresentReadRepository] over a real in-memory [SyncStore], and the
/// in-memory progress store.
void main() {
  late SyncStore store;
  late SyncStorePresentReadRepository repo;

  setUp(() async {
    store = SyncStore.inMemory();
    await store.open();
    repo = SyncStorePresentReadRepository(graph: AppGraph()..bindStore(store));
  });

  Future<void> addCollection(String id, String title) => store.create(
    EntityType.collection,
    id,
    {'title': title, 'description': 'about $title'},
  );

  Future<void> addCard(
    String id,
    String position, {
    String collectionId = 'col',
    String kind = 'text',
    String? text,
    String? attachmentId,
  }) => store.create(EntityType.card, id, {
    'collection_id': collectionId,
    'kind': kind,
    'text': text,
    'attachment_id': attachmentId,
  }, position: position);

  Future<void> addLink(
    String id,
    String sourceId,
    String targetType,
    String targetId,
  ) => store.create(EntityType.link, id, {
    'source_type': 'card',
    'source_id': sourceId,
    'target_type': targetType,
    'target_id': targetId,
  });

  Future<PresentSource> load([String id = 'col']) async =>
      (await repo.loadSource(id)).getOrThrow();

  test('reads the header and the live cards in feed order', () async {
    await addCollection('col', 'Old town');
    await addCard('b', 'a2', text: 'second');
    await addCard('a', 'a1', text: 'first');
    await addCard('gone', 'a3', text: 'deleted');
    await store.delete(EntityType.card, 'gone');

    final source = await load();
    expect(source.collectionId, 'col');
    expect(source.title, 'Old town');
    expect(source.description, 'about Old town');
    expect(source.cards.map((c) => c.id), ['a', 'b']);
    expect(source.cards.first.text, 'first');
    expect(source.cards.first.kind, CardKind.text);
  });

  test('carries the settled and emphasized marks', () async {
    await addCollection('col', 'Old town');
    await addCard('s', 'a1');
    await addCard('e', 'a2');
    await store.setCardsSettled(['s'], settled: true);
    await store.setCardsEmphasized(['e'], emphasized: true);

    final cards = {for (final c in (await load()).cards) c.id: c};
    expect(cards['s']!.settled, isTrue);
    expect(cards['s']!.emphasized, isFalse);
    expect(cards['e']!.emphasized, isTrue);
  });

  test('carries every image of a card with several, in order', () async {
    await addCollection('col', 'Old town');
    await store.create(EntityType.card, 'p', {
      'collection_id': 'col',
      'kind': 'image',
      'attachment_id': 'i1',
      CardSchema.colMoreAttachmentIds: CardSchema.encodeMoreAttachmentIds([
        'i2',
        'i3',
      ]),
    }, position: 'a1');

    expect((await load()).cards.single.imageIds, ['i1', 'i2', 'i3']);
  });

  test("names an audio card by its attachment's file name", () async {
    await addCollection('col', 'Old town');
    await store.create(EntityType.attachment, 'att', {
      'kind': 'audio',
      'mime': 'audio/mpeg',
      'content_hash': 'h',
      'size': 10,
      'name': 'guide.mp3',
    });
    await addCard('a', 'a1', kind: 'audio', attachmentId: 'att');

    final card = (await load()).cards.single;
    expect(card.kind, CardKind.audio);
    expect(card.fileName, 'guide.mp3');
  });

  test('lists live links both ways, leaving broken ones out', () async {
    await addCollection('col', 'Old town');
    await addCollection('other', 'Museums');
    await addCard('a', 'a1', text: 'gate');
    await addCard('b', 'a2', text: 'square');
    await addCard('dead', 'a3', text: 'removed');
    await addLink('l1', 'a', 'collection', 'other');
    await addLink('l2', 'b', 'card', 'a');
    await addLink('l3', 'a', 'card', 'dead');
    await store.delete(EntityType.card, 'dead');

    final cards = {for (final c in (await load()).cards) c.id: c};
    final aLinks = cards['a']!.links;
    expect(aLinks.map((l) => (l.kind, l.id, l.label)), [
      (PresentLinkKind.collection, 'other', 'Museums'),
      (PresentLinkKind.card, 'b', 'square'),
    ]);
    expect(cards['b']!.links.single.id, 'a');
  });

  test('a missing collection fails to load', () async {
    final result = await repo.loadSource('nope');
    expect(result, isA<Failure<PresentSource, PresentFailure>>());
  });

  test('the in-memory progress store remembers and forgets', () async {
    final progress = InMemoryPresentProgressRepository();
    expect((await progress.loadAnchor('col')).getOrThrow(), isNull);
    await progress.saveAnchor('col', 'card');
    expect((await progress.loadAnchor('col')).getOrThrow(), 'card');
    await progress.saveAnchor('col', null);
    expect((await progress.loadAnchor('col')).getOrThrow(), isNull);
  });
}
