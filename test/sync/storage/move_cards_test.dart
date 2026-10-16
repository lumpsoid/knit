import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/storage/infra/sqflite/sqflite_unit_of_work.dart';
import 'package:knit/sync/sync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// `SyncStore.moveCards` (§8.4): each moved card is one signed op that
/// rewrites `collection_id` and lands a fresh placement on the same stamp; the
/// whole batch commits in one transaction and survives rebuild-from-log.
void main() {
  Future<void> seed(SyncStore store) async {
    await store.create(EntityType.collection, 'src', {
      'title': 'Source',
    }, physicalNowMs: 1000);
    await store.create(EntityType.collection, 'dst', {
      'title': 'Target',
    }, physicalNowMs: 1000);
    for (final (id, pos) in [('c1', 'a0'), ('c2', 'a1'), ('c3', 'a2')]) {
      await store.create(
        EntityType.card,
        id,
        {'collection_id': 'src', 'kind': 'text', 'text': id},
        position: pos,
        physicalNowMs: 1000,
      );
    }
  }

  group('in memory', () {
    late SyncStore store;
    setUp(() async {
      store = SyncStore.inMemory();
      await store.open();
      await seed(store);
    });

    test('moves cards: new collection_id + position, content intact', () async {
      final me = await store.authorPubkey();
      final ops = await store.moveCards('dst', {
        'c1': 'b0',
        'c3': 'b1',
      }, physicalNowMs: 2000);

      expect(ops, hasLength(2));
      final c1 = (await store.get(EntityType.card, 'c1'))!;
      expect(c1.content['collection_id'], 'dst');
      expect(c1.content['text'], 'c1');
      expect(c1.position, 'b0');
      expect(c1.createdBy, me);
      // Both clocks take the move's stamp, like a create (§8.4).
      expect(c1.hlc, const Hlc(2000, 0));
      expect(c1.placement, const Hlc(2000, 0));

      expect((await store.feed('dst')).map((s) => s.id), ['c1', 'c3']);
      expect((await store.feed('src')).map((s) => s.id), ['c2']);
      expect(await store.deviceClock.load(), store.clock.now);
      expect(await store.pendingCount(), 5 + 2);
    });

    test('rebuild-from-log reproduces the moved projection (§8.9)', () async {
      await store.moveCards('dst', {'c2': 'b0'}, physicalNowMs: 2000);
      final before = (await store.feed('dst')).single;
      await store.rebuild();
      final after = (await store.feed('dst')).single;
      expect(after.id, 'c2');
      expect(after.sig, before.sig);
      expect(after.position, before.position);
      expect((await store.feed('src')).map((s) => s.id), ['c1', 'c3']);
    });
  });

  test('sqflite: a failing card rolls the whole batch back', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('knit_move_');
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
    await seed(store);
    final logged = await store.pendingCount();

    await expectLater(
      store.moveCards('dst', {'c1': 'b0', 'missing': 'b1'}),
      throwsStateError,
    );

    final c1 = (await store.get(EntityType.card, 'c1'))!;
    expect(c1.content['collection_id'], 'src');
    expect(c1.position, 'a0');
    expect(await store.pendingCount(), logged);
  });
}
