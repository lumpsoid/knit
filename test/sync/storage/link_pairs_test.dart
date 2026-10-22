import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/storage/infra/sqflite/sqflite_unit_of_work.dart';
import 'package:knit/sync/sync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'op_builders.dart';

/// One link per pair (spec §6.4): the pure duplicate rule and read dedupe,
/// then the [SyncStore] reads, the no-op create and the pair-wide delete —
/// against both storage impls.
void main() {
  group('LinkPair / isDuplicateLink', () {
    test('same source and target are duplicates, labels aside', () {
      final a = link(id: 'a', hlcMs: 1, label: 'one');
      final b = link(id: 'b', hlcMs: 2, label: 'two');
      expect(isDuplicateLink(a, b), isTrue);
      expect(LinkPair.of(a), LinkPair.of(b));
    });

    test('another target, or another target type, is not', () {
      final a = link(id: 'a', hlcMs: 1);
      final elsewhere = link(id: 'b', targetId: 'col-2', hlcMs: 1);
      expect(isDuplicateLink(a, elsewhere), isFalse);
      final asCard = a.copyWith(
        id: 'c',
        content: {...a.content, 'target_type': 'card'},
      );
      expect(isDuplicateLink(a, asCard), isFalse);
    });
  });

  group('distinctLinks', () {
    test('keeps the oldest of each pair, in input order', () {
      final newer = link(id: 'a', hlcMs: 1).copyWith(createdAt: 2000);
      final older = link(id: 'z', hlcMs: 1).copyWith(createdAt: 1000);
      final other = link(id: 'm', targetId: 'col-2', hlcMs: 1);
      expect(distinctLinks([other, newer, older]).map((l) => l.id), ['m', 'z']);
    });

    test('ties on created_at go to the smaller id', () {
      final b = link(id: 'b', hlcMs: 1);
      final a = link(id: 'a', hlcMs: 1);
      expect(distinctLinks([b, a]).single.id, 'a');
    });

    test('drops tombstones and rows passed twice', () {
      final live = link(id: 'b', hlcMs: 1);
      final dead = link(id: 'a', hlcMs: 1, deleted: true);
      expect(distinctLinks([dead, live, live]).map((l) => l.id), ['b']);
    });

    test('countLinks counts a pair once per end', () {
      final counts = countLinks(
        [
          link(id: 'a', hlcMs: 1),
          link(id: 'b', hlcMs: 1),
          link(id: 'c', sourceId: 'card-2', targetId: 'card-1', hlcMs: 1),
        ],
        ['card-1', 'col-1', 'nope'],
      );
      expect(counts, {'card-1': 2, 'col-1': 1});
    });
  });

  Future<void> seed(SyncStore store) async {
    for (final id in ['here', 'there']) {
      await store.create(EntityType.collection, id, {
        'title': id,
      }, physicalNowMs: 1000);
    }
    for (final id in ['c1', 'c2']) {
      await store.create(
        EntityType.card,
        id,
        {'collection_id': 'here', 'kind': 'text', 'text': id},
        position: id == 'c1' ? 'a0' : 'a1',
        physicalNowMs: 1000,
      );
    }
  }

  /// A raw link write, bypassing the rule — as another device, or data from
  /// before it, would leave.
  Future<void> rawLink(
    SyncStore store,
    String id,
    String targetType,
    String targetId,
    int at,
  ) => store.create(EntityType.link, id, {
    'source_type': 'card',
    'source_id': 'c1',
    'target_type': targetType,
    'target_id': targetId,
  }, physicalNowMs: at);

  Future<void> readsAsOne(SyncStore store) async {
    await seed(store);
    await rawLink(store, 'l2', 'collection', 'there', 3000);
    await rawLink(store, 'l1', 'collection', 'there', 2000);
    await rawLink(store, 'l3', 'card', 'c2', 2000);

    expect((await store.linksOut('c1')).map((l) => l.id).toSet(), {'l1', 'l3'});
    expect((await store.linksOutOf(['c1'])).length, 2);
    expect((await store.backlinks('there')).single.id, 'l1');
    expect(await store.linkCounts(['c1', 'there', 'c2']), {
      'c1': 2,
      'there': 1,
      'c2': 1,
    });
    final hubs = await store.collectionHubs(['there']);
    expect(hubs['there']!.single.collectionId, 'here');
  }

  Future<void> createIsNoOp(SyncStore store) async {
    await seed(store);
    await rawLink(store, 'l1', 'collection', 'there', 2000);
    final logged = await store.pendingCount();

    final id = await store.createLink(
      linkId: 'fresh',
      sourceType: EntityType.card,
      sourceId: 'c1',
      targetType: EntityType.collection,
      targetId: 'there',
    );
    expect(id, 'l1');
    expect(await store.pendingCount(), logged);
    expect(await store.get(EntityType.link, 'fresh'), isNull);

    final other = await store.createLink(
      linkId: 'fresh',
      sourceType: EntityType.card,
      sourceId: 'c1',
      targetType: EntityType.card,
      targetId: 'c2',
    );
    expect(other, 'fresh');
    expect(await store.pendingCount(), logged + 1);
  }

  Future<void> deleteTakesThePair(SyncStore store) async {
    await seed(store);
    await rawLink(store, 'l1', 'collection', 'there', 2000);
    await rawLink(store, 'l2', 'collection', 'there', 3000);
    await rawLink(store, 'l3', 'card', 'c2', 2000);

    final ops = await store.deleteLink('l1');
    expect(ops.map((op) => op.entityId), ['l1', 'l2']);
    expect((await store.linksOut('c1')).single.id, 'l3');
    expect(await store.projection.backlinks('there'), isEmpty);

    await store.rebuild();
    expect((await store.linksOut('c1')).single.id, 'l3');
    expect(await store.backlinks('there'), isEmpty);
  }

  Future<SyncStore> sqflite() async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('knit_link_pairs_');
    addTearDown(() => dir.delete(recursive: true));
    final db = await databaseFactoryFfi.openDatabase('${dir.path}/knit.db');
    addTearDown(db.close);
    final store = SyncStore(
      changeLog: SqfliteChangeLogStorage(db: db),
      projection: SqfliteProjectionStorage(db: db),
      deviceClock: SqfliteDeviceClockStorage(db: db),
      localIdentity: SqfliteLocalIdentityStorage(db: db),
      quarantine: SqfliteQuarantineStorage(db: db),
      signer: FakeSigner(),
      unitOfWork: SqfliteUnitOfWork(db),
    );
    await store.open();
    return store;
  }

  Future<SyncStore> inMemory() async {
    final store = SyncStore.inMemory();
    await store.open();
    return store;
  }

  for (final (name, open) in <(String, Future<SyncStore> Function())>[
    ('in memory', inMemory),
    ('sqflite', sqflite),
  ]) {
    group('SyncStore ($name)', () {
      test('duplicate links read as one, the oldest', () async {
        await readsAsOne(await open());
      });
      test('createLink on a linked pair writes nothing', () async {
        await createIsNoOp(await open());
      });
      test('deleteLink removes every duplicate; rebuild agrees', () async {
        await deleteTakesThePair(await open());
      });
    });
  }
}
