import 'package:sql_migrator/src/domain/migration_executor.dart';
import 'package:sql_migrator/src/domain/migration_logger.dart';
import 'package:sql_migrator/src/domain/models/exceptions.dart';
import 'package:sql_migrator/src/domain/models/migration.dart';
import 'package:sql_migrator/src/domain/models/migration_callback.dart';
import 'package:sql_migrator/src/domain/models/migration_record.dart';
import 'package:sql_migrator/src/domain/models/migration_status.dart';
import 'package:sql_migrator/src/domain/models/migrator_config.dart';
import 'package:sql_migrator/src/infra/checksum.dart';
import 'package:sql_migrator/src/infra/migration_logger/print_migration_logger.dart';

/// The main migration engine.
///
/// Manages schema versioning for a SQLite database by applying and rolling
/// back [Migration] objects in order. All migrations run inside transactions
/// for atomicity.
///
/// ## Usage
/// ```dart
/// final migrator = Migrator(
///   executor: SqfliteExecutor(database),
///   migrations: allMigrations,
/// );
///
/// // Apply all pending migrations
/// await migrator.migrate();
///
/// // Rollback the last migration
/// await migrator.rollback();
///
/// // Migrate to a specific version
/// await migrator.migrateTo(3);
/// ```
class Migrator {
  Migrator({
    required MigrationExecutor executor,
    required List<Migration> migrations,
    this.config = const MigratorConfig(),
    this.logger = const PrintMigrationLogger(),
    this.onMigrationComplete,
  }) : _executor = executor,
       _migrations = List.unmodifiable(
         List<Migration>.from(migrations)
           ..sort((a, b) => a.version.compareTo(b.version)),
       ) {
    _validateMigrations();
  }
  final MigrationExecutor _executor;
  final List<Migration> _migrations;
  final MigratorConfig config;
  final MigrationLogger logger;
  final MigrationCallback? onMigrationComplete;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Apply all pending migrations up to the latest version.
  ///
  /// Returns the list of migrations that were applied.
  Future<List<MigrationRecord>> migrate() async {
    return _withLock(() async {
      await _ensureMigrationTable();
      final applied = await _getAppliedVersions();
      final pending = _migrations.where((m) => !applied.contains(m.version));

      if (pending.isEmpty) {
        logger.info(
          'Database is up to date (v${_currentVersionFrom(applied)}).',
        );
        return [];
      }

      logger.info('Applying ${pending.length} pending migration(s)...');

      final records = <MigrationRecord>[];
      for (final migration in pending) {
        final record = await _applyUp(migration);
        records.add(record);
      }

      logger.info(
        'Migrations complete. Database is now at v${records.last.version}.',
      );
      return records;
    });
  }

  /// Migrate to a specific target version.
  ///
  /// If [targetVersion] is higher than the current version, pending migrations
  /// up to (and including) [targetVersion] are applied.
  /// If [targetVersion] is lower, applied migrations above it are rolled back
  /// in reverse order.
  /// If [targetVersion] equals the current version, this is a no-op.
  ///
  /// Pass `0` to roll back all migrations.
  Future<List<MigrationRecord>> migrateTo(int targetVersion) async {
    if (targetVersion < 0) {
      throw const MigrationValidationException('Target version must be >= 0.');
    }

    return _withLock(() async {
      await _ensureMigrationTable();
      final applied = await _getAppliedVersions();
      final currentVersion = _currentVersionFrom(applied);

      if (targetVersion == currentVersion) {
        logger.info('Already at v$currentVersion. Nothing to do.');
        return [];
      }

      final records = <MigrationRecord>[];

      if (targetVersion > currentVersion) {
        // Migrate UP
        final pending = _migrations.where(
          (m) => m.version > currentVersion && m.version <= targetVersion,
        );
        for (final migration in pending) {
          records.add(await _applyUp(migration));
        }
      } else {
        // Migrate DOWN
        final toRollback = _migrations.reversed.where(
          (m) => applied.contains(m.version) && m.version > targetVersion,
        );
        for (final migration in toRollback) {
          records.add(await _applyDown(migration));
        }
      }

      final newVersion = targetVersion == 0 ? 0 : records.last.version;
      logger.info('Database is now at v$newVersion.');
      return records;
    });
  }

  /// Roll back the most recently applied migration.
  ///
  /// Pass [steps] to roll back multiple migrations (default: 1).
  Future<List<MigrationRecord>> rollback({int steps = 1}) async {
    if (steps < 1) {
      throw const MigrationValidationException('Rollback steps must be >= 1.');
    }

    return _withLock(() async {
      await _ensureMigrationTable();
      final applied = await _getAppliedVersions();

      if (applied.isEmpty) {
        throw const MigrationRollbackException('No migrations to roll back.');
      }

      final sortedApplied = applied.toList()..sort((a, b) => b.compareTo(a));
      final toRollback = sortedApplied.take(steps);

      final records = <MigrationRecord>[];
      for (final version in toRollback) {
        final migration = _migrations.firstWhere(
          (m) => m.version == version,
          orElse: () => throw MigrationRollbackException(
            'Cannot find migration definition for v$version. '
            'Was it removed from the migration list?',
          ),
        );
        records.add(await _applyDown(migration));
      }

      final remaining = applied.difference(toRollback.toSet());
      final newVersion = remaining.isEmpty
          ? 0
          : remaining.reduce((a, b) => a > b ? a : b);
      logger.info(
        'Rolled back ${records.length} migration(s). '
        'Database is now at v$newVersion.',
      );
      return records;
    });
  }

  /// Returns the current schema version, or 0 if no migrations applied.
  Future<int> currentVersion() async {
    await _ensureMigrationTable();
    final applied = await _getAppliedVersions();
    return _currentVersionFrom(applied);
  }

  /// Returns records for all currently applied (non-rolled-back) migrations.
  Future<List<MigrationRecord>> appliedMigrations() async {
    await _ensureMigrationTable();
    final rows = await _executor.query(
      'SELECT * FROM ${config.tableName} '
      'WHERE rolled_back = 0 '
      'ORDER BY version ASC',
    );
    return rows.map(MigrationRecord.fromRow).toList();
  }

  /// Returns the list of migrations that have not yet been applied.
  Future<List<Migration>> pendingMigrations() async {
    await _ensureMigrationTable();
    final applied = await _getAppliedVersions();
    return _migrations.where((m) => !applied.contains(m.version)).toList();
  }

  /// Validates that all applied migration checksums match their current
  /// definitions. Throws [MigrationChecksumMismatchException] on first mismatch
  Future<void> validateIntegrity() async {
    await _ensureMigrationTable();
    final records = await appliedMigrations();

    for (final record in records) {
      final migration = _migrations.cast<Migration?>().firstWhere(
        (m) => m!.version == record.version,
        orElse: () => null,
      );

      if (migration == null) {
        logger.warning(
          'Applied migration v${record.version} has no matching definition. '
          'It may have been removed.',
        );
        continue;
      }

      final expected = computeMigrationChecksum(
        migration.version,
        migration.description,
      );
      if (expected != record.checksum) {
        throw MigrationChecksumMismatchException(
          version: record.version,
          expectedChecksum: record.checksum,
          actualChecksum: expected,
        );
      }
    }

    logger.info('Integrity check passed for ${records.length} migration(s).');
  }

  /// Produces a human-readable status report.
  Future<MigrationStatus> status() async {
    await _ensureMigrationTable();
    final applied = await appliedMigrations();
    final pending = await pendingMigrations();
    final currentVer = applied.isEmpty ? 0 : applied.last.version;
    final latestVer = _migrations.isEmpty ? 0 : _migrations.last.version;

    return MigrationStatus(
      currentVersion: currentVer,
      latestVersion: latestVer,
      appliedCount: applied.length,
      pendingCount: pending.length,
      appliedMigrations: applied,
      pendingMigrations: pending,
    );
  }

  void _validateMigrations() {
    if (_migrations.isEmpty) return;

    final versions = <int>{};
    for (final m in _migrations) {
      if (m.version <= 0) {
        throw MigrationValidationException(
          'Migration version must be positive, got ${m.version}.',
        );
      }
      if (!versions.add(m.version)) {
        throw MigrationValidationException(
          'Duplicate migration version: ${m.version}.',
        );
      }
    }
  }

  Future<void> _ensureMigrationTable() async {
    await _executor.execute('''
      CREATE TABLE IF NOT EXISTS ${config.tableName} (
        version       INTEGER NOT NULL,
        description   TEXT    NOT NULL,
        checksum      TEXT    NOT NULL,
        applied_at    TEXT    NOT NULL,
        execution_time_ms INTEGER NOT NULL DEFAULT 0,
        rolled_back   INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (version, rolled_back)
      )
    ''');
  }

  Future<Set<int>> _getAppliedVersions() async {
    final rows = await _executor.query(
      'SELECT version FROM ${config.tableName} WHERE rolled_back = 0',
    );
    return rows.map((r) => r['version'] as int? ?? 0).toSet();
  }

  int _currentVersionFrom(Set<int> applied) {
    if (applied.isEmpty) return 0;
    return applied.reduce((a, b) => a > b ? a : b);
  }

  Future<MigrationRecord> _applyUp(Migration migration) async {
    logger.info('↑ Applying v${migration.version}: ${migration.description}');

    final checksum = computeMigrationChecksum(
      migration.version,
      migration.description,
    );

    if (config.validateChecksums) {
      await _checkExistingChecksum(migration, checksum);
    }

    final stopwatch = Stopwatch()..start();

    try {
      await _executor.transaction((tx) async {
        await migration.up(tx);

        final record = MigrationRecord(
          version: migration.version,
          description: migration.description,
          checksum: checksum,
          appliedAt: DateTime.now().toUtc(),
          executionTimeMs: 0,
        );

        await tx.execute(
          'INSERT OR REPLACE INTO ${config.tableName} '
          '(version, description, checksum, applied_at, execution_time_ms,'
          ' rolled_back) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          [
            record.version,
            record.description,
            record.checksum,
            record.appliedAt.toIso8601String(),
            record.executionTimeMs,
            0, // rolled_back
          ],
        );
      });
    } catch (e, st) {
      stopwatch.stop();
      logger.error('Failed applying v${migration.version}', e, st);
      throw MigrationExecutionException(
        version: migration.version,
        direction: MigrationDirection.up,
        message: e.toString(),
        cause: e,
      );
    }

    stopwatch.stop();
    final elapsedMs = stopwatch.elapsedMilliseconds;

    // Update execution time outside the migration transaction
    await _executor.execute(
      'UPDATE ${config.tableName} SET execution_time_ms = ? '
      'WHERE version = ? AND rolled_back = 0',
      [elapsedMs, migration.version],
    );

    final record = MigrationRecord(
      version: migration.version,
      description: migration.description,
      checksum: checksum,
      appliedAt: DateTime.now().toUtc(),
      executionTimeMs: elapsedMs,
    );

    logger.info('  ✓ v${migration.version} applied in ${elapsedMs}ms');

    if (onMigrationComplete != null) {
      await onMigrationComplete!(migration, MigrationDirection.up, elapsedMs);
    }

    return record;
  }

  Future<MigrationRecord> _applyDown(Migration migration) async {
    logger.info(
      '↓ Rolling back v${migration.version}: ${migration.description}',
    );

    final stopwatch = Stopwatch()..start();

    try {
      await _executor.transaction((tx) async {
        await migration.down(tx);

        // Mark as rolled back rather than deleting — keeps audit trail
        await tx.execute(
          'UPDATE ${config.tableName} SET rolled_back = 1 '
          'WHERE version = ? AND rolled_back = 0',
          [migration.version],
        );
      });
    } catch (e, st) {
      stopwatch.stop();
      logger.error('Failed rolling back v${migration.version}', e, st);
      throw MigrationExecutionException(
        version: migration.version,
        direction: MigrationDirection.down,
        message: e.toString(),
        cause: e,
      );
    }

    stopwatch.stop();
    final elapsedMs = stopwatch.elapsedMilliseconds;

    final checksum = computeMigrationChecksum(
      migration.version,
      migration.description,
    );

    final record = MigrationRecord(
      version: migration.version,
      description: migration.description,
      checksum: checksum,
      appliedAt: DateTime.now().toUtc(),
      executionTimeMs: elapsedMs,
      rolledBack: true,
    );

    logger.info('  ✓ v${migration.version} rolled back in ${elapsedMs}ms');

    if (onMigrationComplete != null) {
      await onMigrationComplete!(migration, MigrationDirection.down, elapsedMs);
    }

    return record;
  }

  Future<void> _checkExistingChecksum(
    Migration migration,
    String currentChecksum,
  ) async {
    final rows = await _executor.query(
      'SELECT checksum FROM ${config.tableName} '
      'WHERE version = ? AND rolled_back = 0',
      [migration.version],
    );

    if (rows.isNotEmpty) {
      final stored = rows.first['checksum'] as String? ?? '';
      if (stored != currentChecksum) {
        throw MigrationChecksumMismatchException(
          version: migration.version,
          expectedChecksum: stored,
          actualChecksum: currentChecksum,
        );
      }
    }
  }

  Future<T> _withLock<T>(Future<T> Function() action) async {
    if (!config.useLocking) return action();

    // SQLite advisory lock via a dedicated lock table
    await _executor.execute('''
      CREATE TABLE IF NOT EXISTS _migration_lock (
        id          INTEGER PRIMARY KEY CHECK (id = 1),
        locked_at   TEXT NOT NULL,
        locked_by   TEXT NOT NULL
      )
    ''');

    final lockId = 'migrator_${DateTime.now().microsecondsSinceEpoch}';
    final deadline = DateTime.now().add(config.lockTimeout);

    while (true) {
      try {
        await _executor.transaction((tx) async {
          final existing = await tx.query(
            'SELECT locked_at FROM _migration_lock WHERE id = 1',
          );

          if (existing.isNotEmpty) {
            final lockedAt = DateTime.parse(
              existing.first['locked_at'] as String? ?? '',
            );
            final staleDuration = config.lockTimeout;
            if (DateTime.now().toUtc().difference(lockedAt) > staleDuration) {
              // Stale lock — forcefully release
              await tx.execute('DELETE FROM _migration_lock WHERE id = 1');
            } else {
              throw const MigrationLockException(
                'Lock is held by another process.',
              );
            }
          }

          await tx.execute(
            'INSERT INTO _migration_lock (id, locked_at, locked_by)'
            ' VALUES (1, ?, ?)',
            [DateTime.now().toUtc().toIso8601String(), lockId],
          );
        });

        // Lock acquired
        break;
      } on MigrationLockException {
        if (DateTime.now().isAfter(deadline)) {
          throw MigrationLockException(
            'Could not acquire migration lock within ${config.lockTimeout}.',
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }

    try {
      return await action();
    } finally {
      // Release lock
      await _executor.execute(
        'DELETE FROM _migration_lock WHERE id = 1 AND locked_by = ?',
        [lockId],
      );
    }
  }
}
