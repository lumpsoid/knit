import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/storage/infra/sqflite/sqflite_unit_of_work.dart';
import 'package:knit/sync/sync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// `SyncStore.deleteCards`: each card gets a soft-delete on the content clock
/// (placement frozen, §8.4); the batch commits in one transaction.
void main() {
  late SyncStore store;

  setUp(() async {
    store = SyncStore.inMemory();
    await store.open();
    await store.create(EntityType.collection, 'col', {
      'title': 'Steps',
    }, physicalNowMs: 1000);
    for (final (id, pos) in [('c1', 'a0'), ('c2', 'a1'), ('c3', 'a2')]) {
      await store.create(
        EntityType.card,
        id,
        {'collection_id': 'col', 'kind': 'text', 'text': id},
        position: pos,
        physicalNowMs: 1000,
      );
    }
  });

  test('deletes the cards on the content clock, placement frozen', () async {
    final created = (await store.get(EntityType.card, 'c1'))!;
    final ops = await store.deleteCards(['c1', 'c2'], physicalNowMs: 5000);

    expect(ops, hasLength(2));
    final c1 = (await store.get(EntityType.card, 'c1'))!;
    expect(c1.deleted, isTrue);
    expect(c1.hlc.ms, 5000);
    expect(c1.placement, created.placement, reason: 'placement frozen');
    expect((await store.get(EntityType.card, 'c2'))!.deleted, isTrue);
    expect((await store.get(EntityType.card, 'c3'))!.deleted, isFalse);
    expect(await store.deviceClock.load(), store.clock.now);
  });

  test('survives rebuild-from-log', () async {
    await store.deleteCards(['c1', 'c3'], physicalNowMs: 5000);
    await store.rebuild();
    expect((await store.get(EntityType.card, 'c1'))!.deleted, isTrue);
    expect((await store.get(EntityType.card, 'c2'))!.deleted, isFalse);
    expect((await store.get(EntityType.card, 'c3'))!.deleted, isTrue);
  });

  test('sqflite: a missing card rolls the whole batch back', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('knit_delete_');
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
    await store.create(EntityType.collection, 'col', {'title': 'Steps'});
    await store.create(EntityType.card, 'c1', {
      'collection_id': 'col',
      'kind': 'text',
      'text': 'c1',
    }, position: 'a0');
    final logged = await store.pendingCount();

    await expectLater(store.deleteCards(['c1', 'missing']), throwsStateError);

    expect((await store.get(EntityType.card, 'c1'))!.deleted, isFalse);
    expect(await store.pendingCount(), logged);
  });
}
