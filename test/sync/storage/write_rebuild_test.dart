import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/storage/infra/sqflite/sqflite_unit_of_work.dart';
import 'package:knit/sync/sync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// §9.1 gate 5 (the pass/fail line): local writes on a real sqflite store, then
/// kill & reopen → `rebuild()` yields a byte-identical projection and the device
/// clock resumes strictly monotone (spec §8.9). Also exercises the async signer
/// inside a real `SqfliteUnitOfWork` transaction.
void main() {
  sqfliteFfiInit();

  late Directory dir;
  late String dbPath;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('knit_rebuild_');
    dbPath = '${dir.path}/knit.db';
  });
  tearDown(() async => dir.delete(recursive: true));

  Future<(SyncStore, Database)> openStore() async {
    final db = await databaseFactoryFfi.openDatabase(dbPath);
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
    return (store, db);
  }

  String fingerprint(List<Snapshot> rows) {
    final sorted = rows.toList()..sort((a, b) => a.id.compareTo(b.id));
    return sorted
        .map(
          (s) =>
              '${s.type.name}|${s.id}|hlc=${s.hlc}|'
              'pos=${s.position}@${s.placement}|del=${s.deleted}|sig=${s.sig}|'
              'text=${s.content['text'] ?? s.content['title']}',
        )
        .join(';');
  }

  test(
    'kill & reopen → rebuild byte-identical + clock strictly monotone',
    () async {
      // --- Session 1: a realistic local edit history.
      final (s1, db1) = await openStore();
      await s1.create(EntityType.collection, 'col-1', {
        'title': 'Espresso',
      }, physicalNowMs: 1000);
      await s1.create(
        EntityType.card,
        'c1',
        {'collection_id': 'col-1', 'kind': 'text', 'text': 'grind'},
        position: 'a0',
        physicalNowMs: 1100,
      );
      await s1.create(
        EntityType.card,
        'c2',
        {'collection_id': 'col-1', 'kind': 'text', 'text': 'tamp'},
        position: 'a1',
        physicalNowMs: 1200,
      );
      await s1.edit(EntityType.card, 'c1', {
        'text': 'grind finer',
      }, physicalNowMs: 1300);
      await s1.reorder('c1', 'a5', physicalNowMs: 1400);
      await s1.delete(EntityType.card, 'c2', physicalNowMs: 1500);

      final preFp = fingerprint(await s1.projection.readAll());
      final preClock = s1.clock.now;
      expect(preClock >= const Hlc(1500, 0), isTrue);
      await db1.close(); // simulate kill

      // --- Session 2: reopen the same DB, rebuild from change_log.
      final (s2, db2) = await openStore();
      // Projection survived the kill; rebuild must reproduce it exactly.
      await s2.rebuild();
      final postFp = fingerprint(await s2.projection.readAll());

      expect(postFp, preFp, reason: 'projection byte-identical after rebuild');
      expect(
        s2.clock.now >= preClock,
        isTrue,
        reason: 'clock recovered (§8.9 step 3)',
      );

      // A post-rebuild local write is strictly monotone (out-ranks all history).
      final next = await s2.create(EntityType.collection, 'col-2', {
        'title': 'x',
      }, physicalNowMs: 1000);
      expect(next.hlcMs >= preClock.ms, isTrue);
      final newRow = (await s2.get(EntityType.collection, 'col-2'))!;
      expect(
        newRow.hlc > preClock,
        isTrue,
        reason: 'strictly greater than pre-kill max',
      );

      await db2.close();
    },
  );
}
