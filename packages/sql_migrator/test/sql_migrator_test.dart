import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sql_migrator/sql_migrator.dart';

/// Two example migrations used across the suite.
List<Migration> _migrations() => [
  Migration(
    version: 1,
    description: 'create users',
    up: (db) => db.execute(
      'CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT NOT NULL)',
    ),
    down: (db) => db.execute('DROP TABLE users'),
  ),
  Migration(
    version: 2,
    description: 'create posts',
    up: (db) => db.execute(
      'CREATE TABLE posts (id INTEGER PRIMARY KEY, body TEXT NOT NULL)',
    ),
    down: (db) => db.execute('DROP TABLE posts'),
  ),
];

void main() {
  sqfliteFfiInit();

  Migrator migratorOf(
    MigrationExecutor executor, {
    List<Migration>? migrations,
  }) => Migrator(
    executor: executor,
    migrations: migrations ?? _migrations(),
    logger: const NoOpMigrationLogger(),
  );

  group('validation', () {
    test('duplicate versions throw MigrationValidationException', () {
      expect(
        () => migratorOf(
          InMemoryExecutor(),
          migrations: [
            Migration(version: 1, description: 'a', up: _noop, down: _noop),
            Migration(version: 1, description: 'b', up: _noop, down: _noop),
          ],
        ),
        throwsA(isA<MigrationValidationException>()),
      );
    });

    test('non-positive version throws', () {
      expect(
        () => migratorOf(
          InMemoryExecutor(),
          migrations: [
            Migration(version: 0, description: 'a', up: _noop, down: _noop),
          ],
        ),
        throwsA(isA<MigrationValidationException>()),
      );
    });
  });

  group('InMemoryExecutor', () {
    test(
      'migrate applies all pending, currentVersion tracks the tip',
      () async {
        final m = migratorOf(InMemoryExecutor());
        final applied = await m.migrate();
        expect(applied.map((r) => r.version), [1, 2]);
        expect(await m.currentVersion(), 2);
        expect((await m.pendingMigrations()), isEmpty);
      },
    );

    test('migrate is idempotent — second run applies nothing', () async {
      final m = migratorOf(InMemoryExecutor());
      await m.migrate();
      expect(await m.migrate(), isEmpty);
    });

    test('rollback marks the tip rolled back, lowers the version', () async {
      final m = migratorOf(InMemoryExecutor());
      await m.migrate();
      final rolled = await m.rollback();
      expect(rolled.single.version, 2);
      expect(rolled.single.rolledBack, isTrue);
      expect(await m.currentVersion(), 1);
    });

    test('migrateTo(0) rolls back everything', () async {
      final m = migratorOf(InMemoryExecutor());
      await m.migrate();
      await m.migrateTo(0);
      expect(await m.currentVersion(), 0);
    });

    test('checksum mismatch on a modified applied migration', () async {
      final exec = InMemoryExecutor();
      await migratorOf(exec).migrate();
      // Re-run with a changed description for v1 → checksum differs.
      final tampered = migratorOf(
        exec,
        migrations: [
          Migration(version: 1, description: 'CHANGED', up: _noop, down: _noop),
        ],
      );
      expect(
        tampered.validateIntegrity,
        throwsA(isA<MigrationChecksumMismatchException>()),
      );
    });
  });

  group('SqfliteExecutor (ffi, real DB)', () {
    late MigrationExecutor exec;

    setUp(() async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      exec = SqfliteExecutor(db);
    });

    test('migrate creates real tables; rollback drops them', () async {
      final m = migratorOf(exec);
      await m.migrate();
      // The tables now exist — querying them must not throw.
      expect(await exec.query('SELECT * FROM users'), isEmpty);
      expect(await exec.query('SELECT * FROM posts'), isEmpty);

      await m.migrateTo(0);
      expect(await m.currentVersion(), 0);
      // posts was dropped by its down migration.
      expect(() => exec.query('SELECT * FROM posts'), throwsA(anything));
    });

    test('status reports applied + pending after a partial migrate', () async {
      final m = migratorOf(exec);
      await m.migrateTo(1);
      final status = await m.status();
      expect(status.currentVersion, 1);
      expect(status.latestVersion, 2);
      expect(status.pendingCount, 1);
      expect(status.isUpToDate, isFalse);
    });
  });
}

Future<void> _noop(MigrationExecutor db) async {}
