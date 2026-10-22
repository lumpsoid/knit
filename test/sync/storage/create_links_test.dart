import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/storage/infra/sqflite/sqflite_unit_of_work.dart';
import 'package:knit/sync/sync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// `SyncStore.createLinks` (§6.4): a batch of links commits in one
/// transaction, skipping every pair a live link already joins and every pair
/// repeated within the batch; with a new collection, that collection lands
/// in the same transaction. A rebuild-from-log agrees (§8.9). Run against
/// both storage impls.
void main() {
  Future<void> seed(SyncStore store) async {
    for (final id in ['here', 'there']) {
      await store.create(EntityType.collection, id, {
        'title': id,
      }, physicalNowMs: 1000);
    }
    for (final (id, pos) in [('c1', 'a0'), ('c2', 'a1'), ('c3', 'a2')]) {
      await store.create(
        EntityType.card,
        id,
        {'collection_id': 'here', 'kind': 'text', 'text': id},
        position: pos,
        physicalNowMs: 1000,
      );
    }
  }

  ({String linkId, LinkPair pair}) toCollection(
    String linkId,
    String cardId,
    String collectionId,
  ) => (
    linkId: linkId,
    pair: LinkPair(
      sourceType: EntityType.card.name,
      sourceId: cardId,
      targetType: EntityType.collection.name,
      targetId: collectionId,
    ),
  );

  Future<void> skipsLinkedPairs(SyncStore store) async {
    await seed(store);
    await store.createLink(
      linkId: 'old',
      sourceType: EntityType.card,
      sourceId: 'c2',
      targetType: EntityType.collection,
      targetId: 'there',
      physicalNowMs: 1500,
    );
    final logged = await store.pendingCount();

    final ops = await store.createLinks([
      toCollection('l1', 'c1', 'there'),
      toCollection('l2', 'c2', 'there'), // already linked
      toCollection('l3', 'c3', 'there'),
      toCollection('l4', 'c1', 'there'), // repeats l1's pair
    ], physicalNowMs: 2000);

    expect(ops.map((op) => op.entityId), ['l1', 'l3']);
    expect(await store.pendingCount(), logged + 2);
    expect(await store.get(EntityType.link, 'l2'), isNull);
    expect(await store.get(EntityType.link, 'l4'), isNull);
    expect((await store.backlinks('there')).map((l) => l.id).toSet(), {
      'old',
      'l1',
      'l3',
    });
    expect(await store.deviceClock.load(), store.clock.now);

    await store.rebuild();
    expect((await store.backlinks('there')).map((l) => l.id).toSet(), {
      'old',
      'l1',
      'l3',
    });
  }

  Future<void> nothingNew(SyncStore store) async {
    await seed(store);
    await store.createLink(
      linkId: 'old',
      sourceType: EntityType.card,
      sourceId: 'c1',
      targetType: EntityType.collection,
      targetId: 'there',
      physicalNowMs: 1500,
    );
    final logged = await store.pendingCount();
    final ops = await store.createLinks([toCollection('l1', 'c1', 'there')]);
    expect(ops, isEmpty);
    expect(await store.pendingCount(), logged);
  }

  Future<void> withNewCollection(SyncStore store) async {
    await seed(store);
    final logged = await store.pendingCount();

    final ops = await store.createLinks(
      [toCollection('l1', 'c1', 'fresh'), toCollection('l2', 'c2', 'fresh')],
      newCollection: (
        id: 'fresh',
        content: {'title': 'Fresh', 'cover_attachment_id': null},
      ),
      physicalNowMs: 2000,
    );

    expect(ops.map((op) => op.entityId), ['fresh', 'l1', 'l2']);
    expect(await store.pendingCount(), logged + 3);
    final fresh = (await store.get(EntityType.collection, 'fresh'))!;
    expect(fresh.content['title'], 'Fresh');
    expect(fresh.createdBy, await store.authorPubkey());
    expect(await store.backlinks('fresh'), hasLength(2));

    await store.rebuild();
    expect((await store.get(EntityType.collection, 'fresh'))!.sig, fresh.sig);
    expect(await store.backlinks('fresh'), hasLength(2));
  }

  Future<SyncStore> inMemory() async {
    final store = SyncStore.inMemory();
    await store.open();
    return store;
  }

  Future<SyncStore> sqflite() async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('knit_create_links_');
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

  for (final (name, make) in [('in memory', inMemory), ('sqflite', sqflite)]) {
    group(name, () {
      test('skips linked pairs and repeats, rebuild agrees', () async {
        await skipsLinkedPairs(await make());
      });
      test('writes nothing when every pair is linked', () async {
        await nothingNew(await make());
      });
      test('creates a new collection with its links', () async {
        await withNewCollection(await make());
      });
    });
  }
}
