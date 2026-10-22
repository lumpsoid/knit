import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/core/ids/uuid_id_generator.dart';
import 'package:knit/features/card_links/infra/sync_store_card_links_write_repository.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/infra/sync_store_collection_write_repository.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/features/connections/infra/sync_store_connections_read_repository.dart';
import 'package:knit/features/timeline/infra/sync_store_timeline_write_repository.dart';
import 'package:knit/sync/sync.dart';

/// Drives the §4.4 Connections view over a real in-memory [SyncStore]: a
/// card→collection link is read back as a live links-out / backlink pair, and
/// deleting an endpoint surfaces it as a *broken* connection (§8.6.1) that the
/// clear path removes — the visible half of the §9.1 gate-4 flow.
void main() {
  late AppGraph graph;
  late SyncStore store;
  late SyncStoreTimelineWriteRepository timelineWrite;
  late SyncStoreCollectionWriteRepository collectionWrite;
  late SyncStoreConnectionsReadRepository read;
  late SyncStoreCardLinksWriteRepository links;

  setUp(() async {
    graph = AppGraph();
    store = SyncStore.inMemory();
    await store.open();
    graph.bindStore(store);
    const ids = UuidIdGenerator();
    timelineWrite = SyncStoreTimelineWriteRepository(graph: graph, ids: ids);
    collectionWrite = SyncStoreCollectionWriteRepository(
      graph: graph,
      ids: ids,
    );
    read = SyncStoreConnectionsReadRepository(graph: graph);
    links = SyncStoreCardLinksWriteRepository(graph: graph, ids: ids);
  });

  Future<String> createCollection(String title) async =>
      (await timelineWrite.createCollection(title)).getOrThrow();

  Future<ConnectionsData> connections(
    ConnectedEntityKind kind,
    String id,
  ) async => (await read.loadConnections(kind, id)).getOrThrow();

  /// Builds: collection A holding a card linked to collection B.
  Future<({String a, String b, String card, String link})> linkedGraph() async {
    final a = await createCollection('Espresso');
    final b = await createCollection('Recipes');
    final card = (await collectionWrite.addCard(
      collectionId: a,
      kind: CardKind.text,
      position: 'a0',
      text: 'see recipes',
    )).getOrThrow();
    await links.addLink(
      sourceKind: ConnectedEntityKind.card,
      sourceId: card,
      targetKind: ConnectedEntityKind.collection,
      targetId: b,
    );
    final link = (await store.linksOut(card)).single.id;
    return (a: a, b: b, card: card, link: link);
  }

  test('a card shows the collection it links to as a live links-out', () async {
    final g = await linkedGraph();
    final data = await connections(ConnectedEntityKind.card, g.card);

    expect(data.incoming, isEmpty);
    expect(data.outgoing, hasLength(1));
    final out = data.outgoing.single;
    expect(out.direction, ConnectionDirection.outgoing);
    expect(out.otherKind, ConnectedEntityKind.collection);
    expect(out.otherId, g.b);
    expect(out.broken, isFalse);
    expect(out.label, 'Recipes');
    // A collection endpoint opens itself.
    expect(out.openCollectionId, g.b);
  });

  test('the linked collection shows the card as a live backlink', () async {
    final g = await linkedGraph();
    final data = await connections(ConnectedEntityKind.collection, g.b);

    expect(data.outgoing, isEmpty);
    expect(data.incoming, hasLength(1));
    final back = data.incoming.single;
    expect(back.direction, ConnectionDirection.incoming);
    expect(back.otherKind, ConnectedEntityKind.card);
    expect(back.otherId, g.card);
    expect(back.broken, isFalse);
    expect(back.label, 'see recipes');
    // A card endpoint opens the collection that holds it.
    expect(back.openCollectionId, g.a);
  });

  test(
    'deleting the source card renders the backlink broken, not gone (§8.6.1)',
    () async {
      final g = await linkedGraph();
      await collectionWrite.deleteCard(g.card);

      final data = await connections(ConnectedEntityKind.collection, g.b);
      expect(
        data.incoming,
        hasLength(1),
        reason: 'the link is never auto-removed',
      );
      final back = data.incoming.single;
      expect(back.broken, isTrue);
      expect(back.label, isNull);
      expect(back.linkId, g.link);
      // A broken endpoint can't be located, so there's nothing to open.
      expect(back.openCollectionId, isNull);
    },
  );

  test('deleting the target collection renders the links-out broken', () async {
    final g = await linkedGraph();
    await store.delete(EntityType.collection, g.b);

    final data = await connections(ConnectedEntityKind.card, g.card);
    expect(data.outgoing.single.broken, isTrue);
    expect(data.outgoing.single.label, isNull);
  });

  test('clearing a broken link removes it; endpoints survive', () async {
    final g = await linkedGraph();
    await collectionWrite.deleteCard(g.card);

    (await links.removeLink(g.link)).getOrThrow();

    final data = await connections(ConnectedEntityKind.collection, g.b);
    expect(data.isEmpty, isTrue, reason: 'the link is gone');
    expect(
      await store.get(EntityType.collection, g.b),
      isNotNull,
      reason: 'clearing a link never deletes an endpoint',
    );
  });

  test('loading connections for a missing entity fails', () async {
    final result = await read.loadConnections(
      ConnectedEntityKind.collection,
      'does-not-exist',
    );
    expect(result.isFailure, isTrue);
  });

  group('ownership and duplicates (§4.4/§6.4)', () {
    /// Seeds the projection with a collection someone else made (imported,
    /// read-only), holding the card 'theirs' linked to [targetId].
    Future<void> importedLinkTo(String targetId) async {
      Snapshot row(EntityType type, String id, Map<String, Object?> content) =>
          Snapshot(
            type: type,
            id: id,
            author: 'someone',
            createdBy: 'someone',
            createdAt: 1,
            hlc: const Hlc(1, 0),
            deleted: false,
            sig: 'sig-$id',
            placement: type == EntityType.card ? const Hlc(1, 0) : null,
            position: type == EntityType.card ? 'a0' : null,
            content: content,
          );
      await store.projection.upsert(
        row(EntityType.collection, 'imp', {'title': 'Imported'}),
      );
      await store.projection.upsert(
        row(EntityType.card, 'theirs', {
          'collection_id': 'imp',
          'kind': 'text',
          'text': 'their note',
        }),
      );
      await store.projection.upsert(
        row(EntityType.link, 'their-link', {
          'source_type': 'card',
          'source_id': 'theirs',
          'target_type': 'collection',
          'target_id': targetId,
          'label': null,
        }),
      );
    }

    test('own links are removable both ways', () async {
      final g = await linkedGraph();
      final out = (await connections(ConnectedEntityKind.card, g.card));
      expect(out.outgoing.single.removable, isTrue);
      final back = await connections(ConnectedEntityKind.collection, g.b);
      expect(back.incoming.single.removable, isTrue);
    });

    test('a link from an imported card is never removable', () async {
      final g = await linkedGraph();
      await importedLinkTo(g.b);

      final back = await connections(ConnectedEntityKind.collection, g.b);
      final byId = {for (final i in back.incoming) i.otherId: i};
      expect(byId['theirs']!.removable, isFalse);
      expect(byId[g.card]!.removable, isTrue);
      final theirs = await connections(ConnectedEntityKind.card, 'theirs');
      expect(theirs.outgoing.single.removable, isFalse);
    });

    test('linking a pair twice is one link, read once', () async {
      final g = await linkedGraph();
      final again = (await links.addLink(
        sourceKind: ConnectedEntityKind.card,
        sourceId: g.card,
        targetKind: ConnectedEntityKind.collection,
        targetId: g.b,
      )).getOrThrow();
      expect(again, g.link);
      expect((await connections(ConnectedEntityKind.card, g.card)).outgoing, [
        isA<ConnectionItem>(),
      ]);
      expect(
        (await connections(ConnectedEntityKind.collection, g.b)).incoming,
        hasLength(1),
      );
    });
  });
}
