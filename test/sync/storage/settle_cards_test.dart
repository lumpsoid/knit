import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/storage/infra/sqflite/sqflite_unit_of_work.dart';
import 'package:knit/sync/sync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'op_builders.dart';

/// `SyncStore.setCardsSettled` (§3.3): settling is a content write that stamps
/// `settled_at` with the write's own time (placement frozen, §8.4); the batch
/// commits in one transaction and survives rebuild-from-log.
void main() {
  late SyncStore store;

  setUp(() async {
    store = SyncStore.inMemory();
    await store.open();
    await store.create(EntityType.collection, 'col', {
      'title': 'Steps',
    }, physicalNowMs: 1000);
    for (final (id, pos) in [('c1', 'a0'), ('c2', 'a1')]) {
      await store.create(
        EntityType.card,
        id,
        {'collection_id': 'col', 'kind': 'text', 'text': id},
        position: pos,
        physicalNowMs: 1000,
      );
    }
  });

  test(
    'a new card is live: settled_at is null in its signed payload',
    () async {
      final c1 = (await store.get(EntityType.card, 'c1'))!;
      expect(c1.content['settled_at'], isNull);
      expect(CanonicalSerializer.string(c1), contains('"settled_at":null'));
    },
  );

  test('settles cards on the content clock, placement frozen', () async {
    final created = (await store.get(EntityType.card, 'c1'))!;
    final ops = await store.setCardsSettled(
      ['c1', 'c2'],
      settled: true,
      physicalNowMs: 5000,
    );

    expect(ops, hasLength(2));
    final c1 = (await store.get(EntityType.card, 'c1'))!;
    expect(c1.content['settled_at'], 5000);
    expect(c1.content['text'], 'c1');
    expect(c1.hlc, const Hlc(5000, 0));
    expect(c1.placement, created.placement, reason: 'placement frozen');
    expect(c1.position, 'a0');
    expect(ops.first.payload, contains('"settled_at":5000'));
    expect(await store.deviceClock.load(), store.clock.now);
  });

  test('unsettle clears settled_at', () async {
    await store.setCardsSettled(['c1'], settled: true, physicalNowMs: 5000);
    await store.setCardsSettled(['c1'], settled: false, physicalNowMs: 6000);

    final c1 = (await store.get(EntityType.card, 'c1'))!;
    expect(c1.content['settled_at'], isNull);
    expect(c1.hlc.ms, 6000);
  });

  test('an edit keeps the card settled', () async {
    await store.setCardsSettled(['c1'], settled: true, physicalNowMs: 5000);
    await store.edit(EntityType.card, 'c1', {
      'text': 'edited',
    }, physicalNowMs: 6000);

    expect(
      (await store.get(EntityType.card, 'c1'))!.content['settled_at'],
      5000,
    );
  });

  test('rebuild-from-log reproduces the settled projection (§8.9)', () async {
    await store.setCardsSettled(['c2'], settled: true, physicalNowMs: 5000);
    final before = (await store.get(EntityType.card, 'c2'))!;
    await store.rebuild();
    final after = (await store.get(EntityType.card, 'c2'))!;
    expect(after.content['settled_at'], 5000);
    expect(after.sig, before.sig);
  });

  test('a card from a peer without the field can still be settled', () async {
    // An older peer's signed payload: the v1 card field set, no settled_at.
    const author = 'bb';
    final payload = CanonicalSerializer.string(
      card(
        id: 'legacy',
        collectionId: 'col',
        hlcMs: 2000,
        posMs: 2000,
        text: 'old',
      ).copyWith(author: author, createdBy: author),
    ).replaceFirst('"settled_at":null,', '');
    expect(payload, isNot(contains('settled_at')));
    final parsed = jsonDecode(payload) as Map<String, Object?>;
    final sig = fakeSignHex(utf8.encode(author), utf8.encode(payload));
    final legacy = Snapshot.fromPayload(parsed).copyWith(sig: sig);
    final op = PersistedOp.fromSnapshot(
      legacy,
      opId: OpId.ofSnapshot(legacy),
      payload: payload,
      origin: SyncOrigin.remote,
    );
    expect(await store.applyRemote(op, 2000), ApplyOutcome.applied);

    await store.setCardsSettled(['legacy'], settled: true, physicalNowMs: 5000);

    final settled = (await store.get(EntityType.card, 'legacy'))!;
    expect(settled.content['settled_at'], 5000);
    expect(settled.createdBy, author);
  });

  test('sqflite: a missing card rolls the whole batch back', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('knit_settle_');
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

    await expectLater(
      store.setCardsSettled(['c1', 'missing'], settled: true),
      throwsStateError,
    );

    expect(
      (await store.get(EntityType.card, 'c1'))!.content['settled_at'],
      isNull,
    );
    expect(await store.pendingCount(), logged);
  });
}
