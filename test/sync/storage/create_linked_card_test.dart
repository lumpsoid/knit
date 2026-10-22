import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/storage/infra/sqflite/sqflite_unit_of_work.dart';
import 'package:knit/sync/sync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// `SyncStore.createLinkedCard` (§6.4 link block): the card and its one link
/// out commit together, and a rebuild-from-log agrees (§8.9). Run against both
/// storage impls.
void main() {
  Future<void> seed(SyncStore store) async {
    for (final id in ['here', 'there']) {
      await store.create(EntityType.collection, id, {
        'title': id,
      }, physicalNowMs: 1000);
    }
  }

  Future<void> createsBoth(SyncStore store) async {
    await seed(store);
    final logged = await store.pendingCount();
    final ops = await store.createLinkedCard(
      cardId: 'block',
      content: {'collection_id': 'here', 'kind': 'link', 'text': null},
      position: 'a0',
      linkId: 'edge',
      targetType: EntityType.collection,
      targetId: 'there',
      physicalNowMs: 2000,
    );

    expect(ops.map((op) => op.entityId), ['block', 'edge']);
    final card = (await store.feed('here')).single;
    expect(card.id, 'block');
    expect(card.content['kind'], 'link');
    expect(card.content['text'], isNull);
    expect(card.position, 'a0');
    final link = (await store.linksOut('block')).single;
    expect(link.id, 'edge');
    expect(link.content['source_type'], 'card');
    expect(link.content['target_type'], 'collection');
    expect(link.content['target_id'], 'there');
    expect(link.createdBy, await store.authorPubkey());
    expect(await store.pendingCount(), logged + 2);
    expect(await store.deviceClock.load(), store.clock.now);

    await store.rebuild();
    expect((await store.feed('here')).single.sig, card.sig);
    expect((await store.linksOut('block')).single.sig, link.sig);
  }

  Future<void> createsTheTarget(SyncStore store) async {
    await seed(store);
    final logged = await store.pendingCount();
    final ops = await store.createLinkedCard(
      cardId: 'block',
      content: {'collection_id': 'here', 'kind': 'text', 'text': 'Trips'},
      position: 'a0',
      linkId: 'edge',
      targetType: EntityType.collection,
      targetId: 'fresh',
      newTargetContent: {'title': 'Fresh', 'cover_attachment_id': null},
      physicalNowMs: 2000,
    );

    expect(ops.map((op) => op.entityId), ['fresh', 'block', 'edge']);
    expect(await store.pendingCount(), logged + 3);
    final fresh = (await store.get(EntityType.collection, 'fresh'))!;
    expect(fresh.content['title'], 'Fresh');
    expect((await store.feed('here')).single.content['text'], 'Trips');
    expect((await store.backlinks('fresh')).single.id, 'edge');

    await store.rebuild();
    expect((await store.get(EntityType.collection, 'fresh'))!.sig, fresh.sig);
    expect((await store.backlinks('fresh')).single.id, 'edge');
  }

  test('in memory: a new target collection lands with them', () async {
    final store = SyncStore.inMemory();
    await store.open();
    await createsTheTarget(store);
  });

  test('in memory: card + link in one go, rebuild agrees', () async {
    final store = SyncStore.inMemory();
    await store.open();
    await createsBoth(store);
  });

  test('sqflite: card + link in one go, rebuild agrees', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('knit_linked_');
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
    await createsBoth(store);
  });

  test('sqflite: a new target collection lands with them', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('knit_linked_new_');
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
    await createsTheTarget(store);
  });
}
