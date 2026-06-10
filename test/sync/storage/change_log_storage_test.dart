import 'package:flutter_test/flutter_test.dart';
import 'package:knit/sync/sync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'op_builders.dart';

/// The same contract is verified against both implementations — the whole point
/// of abstracting [ChangeLogStorage]: in-memory for dev/tests, sqflite for prod.
void main() {
  sqfliteFfiInit();

  Future<ChangeLogStorage> inMemory() async {
    final s = InMemoryChangeLogStorage();
    await s.ensureSchema();
    return s;
  }

  Future<ChangeLogStorage> sqflite() async {
    // singleInstance:false → a fresh in-memory DB per test (the ffi factory
    // otherwise reuses one singleton for inMemoryDatabasePath).
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    final s = SqfliteChangeLogStorage(db: db);
    await s.ensureSchema();
    return s;
  }

  for (final variant in <(String, Future<ChangeLogStorage> Function())>[
    ('InMemoryChangeLogStorage', inMemory),
    ('SqfliteChangeLogStorage', sqflite),
  ]) {
    final (name, open) = variant;

    group(name, () {
      late ChangeLogStorage store;
      setUp(() async => store = await open());

      test('append assigns seq and readOrdered returns seq ASC', () async {
        await store.append(opOf(collection(hlcMs: 100)));
        await store.append(opOf(collection(id: 'col-2', hlcMs: 110)));
        final ops = await store.readOrdered();
        expect(ops.map((o) => o.entityId), ['col-1', 'col-2']);
        expect(ops.first.seq! < ops.last.seq!, isTrue);
      });

      test('duplicate op_id is deduped (idempotent, spec §7.3)', () async {
        final op = opOf(collection(hlcMs: 100));
        await store.append(op);
        await store.append(op);
        expect((await store.readOrdered()).length, 1);
        expect(await store.hasOp(op.opId), isTrue);
        expect(await store.hasOp('nope'), isFalse);
      });

      test('pending = local & !acked; markAcked clears it', () async {
        await store.append(opOf(collection(hlcMs: 100)));
        await store.append(opOf(collection(id: 'r', hlcMs: 100), origin: SyncOrigin.remote));
        expect(await store.pendingCount(), 1, reason: 'remote not pending');

        final local = (await store.readPending()).single;
        await store.markAcked(local.opId);
        expect(await store.pendingCount(), 0);
      });

      test('payload round-trips back into a Snapshot', () async {
        await store.append(opOf(card(hlcMs: 100, text: 'grind finer', position: 'a3')));
        final snap = (await store.readOrdered()).single.toSnapshot();
        expect(snap.type, EntityType.card);
        expect(snap.content['text'], 'grind finer');
        expect(snap.position, 'a3');
      });

      test('clear empties the log', () async {
        await store.append(opOf(collection(hlcMs: 100)));
        await store.clear();
        expect(await store.readOrdered(), isEmpty);
      });
    });
  }
}
