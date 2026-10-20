import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/schema/knit_migrations.dart';
import 'package:knit/sync/sync.dart';
import 'package:sql_migrator/sql_migrator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Regression coverage for `knitMigrations()` against a real (ffi) SQLite.
///
/// v1 is a frozen historical snapshot (without `attachment.name` /
/// `collection.description`); v2/v3 add those columns. Every device runs the
/// same linear chain, so the tests just run it and assert the resulting tables
/// — no fresh-vs-old divergence to special-case.
void main() {
  sqfliteFfiInit();

  Future<Database> openDb() => databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );

  Migrator migratorFor(Database db) =>
      Migrator(executor: SqfliteExecutor(db), migrations: knitMigrations());

  Future<Set<String>> columnsOf(Database db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.map((r) => r['name'] as String).toSet();
  }

  test('fresh install applies the whole chain to v6 without error', () async {
    final db = await openDb();
    final migrator = migratorFor(db);

    await migrator.migrate();

    expect(await migrator.currentVersion(), 6);
    expect(
      await columnsOf(db, AttachmentSchema.table),
      contains(AttachmentSchema.colName),
    );
    expect(
      await columnsOf(db, CollectionSchema.table),
      contains(CollectionSchema.colDescription),
    );
    expect(
      await columnsOf(db, CardSchema.table),
      contains(CardSchema.colSettledAt),
    );
    expect(
      await columnsOf(db, CollectionSchema.table),
      contains(CollectionSchema.colArchivedAt),
    );
  });

  test(
    'frozen v1 lacks the later columns; migrateTo(1) is the old-device shape',
    () async {
      final db = await openDb();
      await migratorFor(db).migrateTo(1);

      expect(
        await columnsOf(db, AttachmentSchema.table),
        isNot(contains(AttachmentSchema.colName)),
      );
      expect(
        await columnsOf(db, CollectionSchema.table),
        isNot(contains(CollectionSchema.colDescription)),
      );
      expect(
        await columnsOf(db, CardSchema.table),
        isNot(contains(CardSchema.colSettledAt)),
      );
      expect(
        await columnsOf(db, CollectionSchema.table),
        isNot(contains(CollectionSchema.colArchivedAt)),
      );
    },
  );

  test('an old v1 device backfills cleanly when it upgrades', () async {
    final db = await openDb();
    final migrator = migratorFor(db);

    await migrator.migrateTo(1); // a device created by the first build
    await migrator.migrate(); // ... later upgrades

    expect(await migrator.currentVersion(), 6);
    expect(
      await columnsOf(db, AttachmentSchema.table),
      contains(AttachmentSchema.colName),
    );
    expect(
      await columnsOf(db, CollectionSchema.table),
      contains(CollectionSchema.colDescription),
    );
  });

  test('v4 creates the feed + link read-path indexes', () async {
    final db = await openDb();
    await migratorFor(db).migrate();

    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index'",
    );
    expect(
      rows.map((r) => r['name']),
      containsAll(['idx_card_feed', 'idx_link_source', 'idx_link_target']),
    );
  });

  test('migrate is a no-op once the chain is applied', () async {
    final db = await openDb();
    final migrator = migratorFor(db);

    await migrator.migrate();
    expect(await migrator.migrate(), isEmpty);
    expect(await migrator.currentVersion(), 6);
  });

  test('migrated schema converges to the live *Schema constants', () async {
    // The migration chain must reach the same column set as `ensureSchema`
    // builds from the current constants — otherwise the frozen baseline and the
    // constants have drifted (a column added to one but not the other).
    final migrated = await openDb();
    await migratorFor(migrated).migrate();

    final expected = await openDb();
    const constantDdl = [
      ...ProjectionTables.createStatements,
      ChangeLogSchema.createTable,
      DeviceClockSchema.createTable,
      LocalIdentitySchema.createTable,
      QuarantineSchema.createTable,
    ];
    for (final ddl in constantDdl) {
      await expected.execute(ddl);
    }

    for (final table in [
      CollectionSchema.table,
      CardSchema.table,
      LinkSchema.table,
      AttachmentSchema.table,
      ProfileSchema.table,
      ChangeLogSchema.table,
      DeviceClockSchema.table,
      LocalIdentitySchema.table,
      QuarantineSchema.table,
    ]) {
      expect(
        await columnsOf(migrated, table),
        await columnsOf(expected, table),
        reason: 'column set drifted for "$table"',
      );
    }
  });
}
