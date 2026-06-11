import 'package:flutter_test/flutter_test.dart';
import 'package:knit/sync/sync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// One contract, verified against both impls (spec §6.7/§8.8).
void main() {
  sqfliteFfiInit();

  Future<QuarantineStorage> inMemory() async {
    final s = InMemoryQuarantineStorage();
    await s.ensureSchema();
    return s;
  }

  Future<QuarantineStorage> sqflite() async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    final s = SqfliteQuarantineStorage(db: db);
    await s.ensureSchema();
    return s;
  }

  QuarantinedOp op(String id, QuarantineReason reason) => QuarantinedOp(
        opId: id,
        reason: reason,
        rawOp: '{"id":"$id"}',
        seenAt: 1718020800000,
      );

  for (final (name, open) in <(String, Future<QuarantineStorage> Function())>[
    ('InMemoryQuarantineStorage', inMemory),
    ('SqfliteQuarantineStorage', sqflite),
  ]) {
    group(name, () {
      late QuarantineStorage store;
      setUp(() async => store = await open());

      test('add then readAll; reason and raw_op round-trip', () async {
        await store.add(op('o1', QuarantineReason.badSig));
        await store.add(op('o2', QuarantineReason.skew));
        final all = await store.readAll();
        expect(all.map((o) => o.opId).toSet(), {'o1', 'o2'});
        final o1 = all.firstWhere((o) => o.opId == 'o1');
        expect(o1.reason, QuarantineReason.badSig);
        expect(o1.rawOp, '{"id":"o1"}');
        expect(o1.seenAt, 1718020800000);
      });

      test('every reason round-trips through the db codec', () {
        for (final r in QuarantineReason.values) {
          expect(QuarantineReason.fromDb(r.toDb()), r);
        }
      });

      test('duplicate op_id is ignored (idempotent)', () async {
        await store.add(op('dup', QuarantineReason.badSig));
        await store.add(op('dup', QuarantineReason.skew));
        expect((await store.readAll()).length, 1);
      });

      test('remove drops one op (skew auto-retry path)', () async {
        await store.add(op('o1', QuarantineReason.skew));
        await store.remove('o1');
        expect(await store.readAll(), isEmpty);
      });

      test('clear empties the store', () async {
        await store.add(op('o1', QuarantineReason.badSig));
        await store.clear();
        expect(await store.readAll(), isEmpty);
      });
    });
  }
}
