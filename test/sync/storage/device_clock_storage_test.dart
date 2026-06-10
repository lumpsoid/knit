import 'package:flutter_test/flutter_test.dart';
import 'package:knit/sync/sync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  Future<DeviceClockStorage> inMemory() async {
    final s = InMemoryDeviceClockStorage();
    await s.ensureSchema();
    return s;
  }

  Future<DeviceClockStorage> sqflite() async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    final s = SqfliteDeviceClockStorage(db: db);
    await s.ensureSchema();
    return s;
  }

  for (final (name, open) in <(String, Future<DeviceClockStorage> Function())>[
    ('InMemoryDeviceClockStorage', inMemory),
    ('SqfliteDeviceClockStorage', sqflite),
  ]) {
    group(name, () {
      late DeviceClockStorage store;
      setUp(() async => store = await open());

      test('load is null before any save', () async {
        expect(await store.load(), isNull);
      });

      test('save then load round-trips the stamp', () async {
        await store.save(const Hlc(1718020800000, 7));
        expect(await store.load(), const Hlc(1718020800000, 7));
      });

      test('save replaces the single row', () async {
        await store.save(const Hlc(100, 0));
        await store.save(const Hlc(200, 1));
        expect(await store.load(), const Hlc(200, 1));
      });

      test('clear resets to null', () async {
        await store.save(const Hlc(100, 0));
        await store.clear();
        expect(await store.load(), isNull);
      });
    });
  }
}
