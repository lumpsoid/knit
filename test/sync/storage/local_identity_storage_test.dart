import 'package:flutter_test/flutter_test.dart';
import 'package:knit/sync/sync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// One contract, verified against both impls (spec §6.5).
void main() {
  sqfliteFfiInit();

  Future<LocalIdentityStorage> inMemory() async {
    final s = InMemoryLocalIdentityStorage();
    await s.ensureSchema();
    return s;
  }

  Future<LocalIdentityStorage> sqflite() async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    final s = SqfliteLocalIdentityStorage(db: db);
    await s.ensureSchema();
    return s;
  }

  for (final (name, open)
      in <(String, Future<LocalIdentityStorage> Function())>[
        ('InMemoryLocalIdentityStorage', inMemory),
        ('SqfliteLocalIdentityStorage', sqflite),
      ]) {
    group(name, () {
      late LocalIdentityStorage store;
      setUp(() async => store = await open());

      test('load is null before any save', () async {
        expect(await store.load(), isNull);
      });

      test(
        'save then load round-trips the identity (incl. secret BLOB)',
        () async {
          await store.save(
            const LocalIdentity(
              publicKeyHex: '9f86d0',
              secretKeyEnc: [1, 2, 3, 250, 0, 128],
              createdAt: 1718020800000,
            ),
          );
          final got = (await store.load())!;
          expect(got.publicKeyHex, '9f86d0');
          expect(got.secretKeyEnc, [1, 2, 3, 250, 0, 128]);
          expect(got.createdAt, 1718020800000);
        },
      );

      test('clear resets to null', () async {
        await store.save(
          const LocalIdentity(
            publicKeyHex: 'p',
            secretKeyEnc: [9],
            createdAt: 1,
          ),
        );
        await store.clear();
        expect(await store.load(), isNull);
      });
    });
  }
}
