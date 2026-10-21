import 'package:flutter_test/flutter_test.dart';
import 'package:knit/sync/sync.dart';

import 'op_builders.dart';

/// Collection hubs (spec §8.6.4): the pure derivation, then the batched
/// [SyncStore] reads that feed it and the collection-link tile.
void main() {
  /// A link made from the collection [sourceId] itself.
  Snapshot collectionLink({
    required String id,
    required String sourceId,
    required String targetId,
  }) {
    final l = link(id: id, sourceId: sourceId, targetId: targetId, hlcMs: 1);
    return l.copyWith(content: {...l.content, 'source_type': 'collection'});
  }

  /// A link from card [sourceId] to the *card* [targetId].
  Snapshot cardToCard({
    required String id,
    required String sourceId,
    required String targetId,
  }) {
    final l = link(id: id, sourceId: sourceId, targetId: targetId, hlcMs: 1);
    return l.copyWith(content: {...l.content, 'target_type': 'card'});
  }

  group('buildCollectionHubs', () {
    final house = collection(id: 'house', title: 'House', hlcMs: 1);
    final trips = collection(id: 'trips', title: 'trips', hlcMs: 1);
    final garden = collection(id: 'garden', title: 'Garden', hlcMs: 1);

    test('cards and the collection itself make one hub each', () {
      final hubs = buildCollectionHubs(
        collectionIds: ['garden'],
        links: [
          link(id: 'l1', sourceId: 'c1', targetId: 'garden', hlcMs: 1),
          link(id: 'l2', sourceId: 'c2', targetId: 'garden', hlcMs: 1),
          collectionLink(id: 'l3', sourceId: 'house', targetId: 'garden'),
          link(id: 'l4', sourceId: 'c3', targetId: 'garden', hlcMs: 1),
        ],
        sourceCards: [
          card(id: 'c1', collectionId: 'house', hlcMs: 1),
          card(id: 'c2', collectionId: 'house', hlcMs: 1),
          card(id: 'c3', collectionId: 'trips', hlcMs: 1),
        ],
        sourceCollections: [house, trips],
      );
      // Deduped by source collection; sorted by title, ignoring case.
      expect(hubs, {
        'garden': const [
          CollectionHub(collectionId: 'house', title: 'House'),
          CollectionHub(collectionId: 'trips', title: 'trips'),
        ],
      });
    });

    test('a collection is never its own hub', () {
      final hubs = buildCollectionHubs(
        collectionIds: ['house'],
        links: [link(id: 'l1', sourceId: 'c1', targetId: 'house', hlcMs: 1)],
        sourceCards: [card(id: 'c1', collectionId: 'house', hlcMs: 1)],
        sourceCollections: [house],
      );
      expect(hubs, isEmpty);
    });

    test('deleted or missing sources count for nothing', () {
      final hubs = buildCollectionHubs(
        collectionIds: ['garden'],
        links: [
          // A deleted card in a live collection.
          link(id: 'l1', sourceId: 'c1', targetId: 'garden', hlcMs: 1),
          // A live card in a deleted collection.
          link(id: 'l2', sourceId: 'c2', targetId: 'garden', hlcMs: 1),
          // A card that never arrived.
          link(id: 'l3', sourceId: 'c9', targetId: 'garden', hlcMs: 1),
          // A deleted link.
          link(
            id: 'l4',
            sourceId: 'c3',
            targetId: 'garden',
            hlcMs: 1,
            deleted: true,
          ),
        ],
        sourceCards: [
          card(id: 'c1', collectionId: 'house', hlcMs: 2, deleted: true),
          card(id: 'c2', collectionId: 'gone', hlcMs: 1),
          card(id: 'c3', collectionId: 'house', hlcMs: 1),
        ],
        sourceCollections: [
          house,
          collection(id: 'gone', hlcMs: 2, deleted: true),
        ],
      );
      expect(hubs, isEmpty);
    });

    test('an archived hub still counts', () {
      final hubs = buildCollectionHubs(
        collectionIds: ['garden'],
        links: [link(id: 'l1', sourceId: 'c1', targetId: 'garden', hlcMs: 1)],
        sourceCards: [card(id: 'c1', collectionId: 'old', hlcMs: 1)],
        sourceCollections: [
          collection(id: 'old', title: 'Old', hlcMs: 1, archivedAt: 5),
        ],
      );
      expect(hubs['garden']!.single.collectionId, 'old');
    });

    test('links to cards, or to other collections, are ignored', () {
      final hubs = buildCollectionHubs(
        collectionIds: ['garden'],
        links: [
          cardToCard(id: 'l1', sourceId: 'c1', targetId: 'garden'),
          link(id: 'l2', sourceId: 'c1', targetId: 'trips', hlcMs: 1),
        ],
        sourceCards: [card(id: 'c1', collectionId: 'house', hlcMs: 1)],
        sourceCollections: [house, trips, garden],
      );
      expect(hubs, isEmpty);
    });
  });

  group('SyncStore', () {
    late SyncStore store;

    setUp(() async {
      store = SyncStore.inMemory();
      await store.open();
      for (final s in [
        collection(id: 'house', title: 'House', hlcMs: 1),
        collection(
          id: 'garden',
          title: 'Garden',
          hlcMs: 1,
          coverAttachmentId: 'cov',
        ),
        collection(id: 'gone', hlcMs: 2, deleted: true),
        card(id: 'c1', collectionId: 'house', hlcMs: 1, createdAt: 10),
        card(
          id: 'g1',
          collectionId: 'garden',
          hlcMs: 1,
          createdAt: 20,
          text: 'tomatoes',
          settledAt: 3,
        ),
        card(id: 'g2', collectionId: 'garden', hlcMs: 1, createdAt: 5),
        link(id: 'l1', sourceId: 'c1', targetId: 'garden', hlcMs: 1),
      ]) {
        await store.applyRemote(opOf(s, origin: SyncOrigin.remote), 10);
      }
    });

    test('collectionHubs reads the hubs over the given collections', () async {
      expect(await store.collectionHubs(['garden', 'house']), {
        'garden': const [CollectionHub(collectionId: 'house', title: 'House')],
      });
      expect(await store.collectionHubs(const []), isEmpty);
    });

    test('collectionSummaries reads just those home rows', () async {
      final rows = await store.collectionSummaries(['garden', 'gone', 'nope']);
      final garden = rows.single;
      expect(garden.collectionId, 'garden');
      expect(garden.cardCount, 2);
      expect(garden.coverAttachmentId, 'cov');
      expect(garden.lastCard?.text, 'tomatoes');
      expect(garden.lastCard?.settled, isTrue);
    });
  });
}
