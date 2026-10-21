import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/connections/domain/unlinked_mentions.dart';
import 'package:knit/features/connections/infra/sync_store_mention_read_repository.dart';
import 'package:knit/sync/sync.dart';

import '../collection_share/share_fixture.dart';

/// The "Mentioned in" corpus (§4.4, §8.6.5) over a real in-memory store: live
/// text cards of live collections, flagged own or imported, and the cards
/// already linking to the focus — then the finder's pick over it.
void main() {
  late SyncStore store;
  late SyncStoreMentionReadRepository repo;

  /// Kai imports Mira's `trip` ("Trip to Kyoto", cards c1…c4) and owns `kyoto`
  /// plus `notes`, whose cards mention Kyoto in several ways.
  setUp(() async {
    final sender = await device('mira');
    await seedTrip(sender);
    await sender.create(
      EntityType.card,
      'c5',
      {'collection_id': 'trip', 'kind': 'text', 'text': 'Kyoto from Mira'},
      position: 'a4',
      physicalNowMs: 1200,
    );
    store = await device('kai');
    for (final op in (await sender.shareSet('trip')).ops) {
      await store.applyRemote(op, 5000);
    }
    repo = SyncStoreMentionReadRepository(graph: graphOf(store));

    await store.create(EntityType.collection, 'kyoto', {'title': 'Kyoto'});
    await store.create(EntityType.collection, 'notes', {'title': 'Notes'});
    await store.create(EntityType.collection, 'gone', {'title': 'Gone'});
    Future<void> card(String id, String collection, String text) =>
        store.create(EntityType.card, id, {
          'collection_id': collection,
          'kind': 'text',
          'text': text,
        }, position: 'a0');
    await card('plain', 'notes', 'Flights to Kyoto booked');
    await card('linked', 'notes', 'Kyoto hotels');
    await card('deleted', 'notes', 'Kyoto temples');
    await card('inside', 'kyoto', 'Kyoto day one');
    await card('orphan', 'gone', 'Kyoto in a deleted collection');
    await store.delete(EntityType.card, 'deleted');
    await store.delete(EntityType.collection, 'gone');
    await store.create(EntityType.link, 'l1', {
      'source_type': 'card',
      'source_id': 'linked',
      'target_type': 'collection',
      'target_id': 'kyoto',
    });
  });

  test('the corpus holds live cards with own/imported flags', () async {
    final corpus = (await repo.loadMentionCorpus('kyoto')).getOrThrow();
    final byId = {for (final c in corpus.cards) c.cardId: c};
    expect(byId.keys, isNot(contains('deleted')));
    expect(byId.keys, isNot(contains('orphan')));
    expect(byId['plain']!.canLink, isTrue);
    expect(byId['plain']!.collectionTitle, 'Notes');
    expect(byId['c5']!.canLink, isFalse);
    expect(corpus.linkedCardIds, {'linked'});
  });

  test('only the unlinked own card elsewhere is a mention', () async {
    final corpus = (await repo.loadMentionCorpus('kyoto')).getOrThrow();
    final mentions = UnlinkedMentionFinder.find(
      collectionId: 'kyoto',
      title: 'Kyoto',
      corpus: corpus,
    );
    expect(mentions.items.map((m) => m.cardId), ['plain']);
    expect(mentions.items.single.collectionId, 'notes');
    expect(mentions.more, 0);
  });
}
