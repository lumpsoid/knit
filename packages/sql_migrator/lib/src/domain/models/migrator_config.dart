import 'package:sql_migrator/src/domain/models/exceptions.dart';

class MigratorConfig {
  const MigratorConfig({
    this.tableName = '_schema_migrations',
    this.validateChecksums = true,
    this.useLocking = true,
    this.lockTimeout = const Duration(seconds: 30),
  });

  /// Name of the table used to track applied migrations.
  final String tableName;

  /// If true, validates checksums of applied migrations against current
  /// definitions and throws [MigrationChecksumMismatchException] on mismatch.
  final bool validateChecksums;

  /// If true, acquires an advisory lock before running migrations to
  /// prevent concurrent execution (useful in multi-isolate scenarios).
  final bool useLocking;

  /// Timeout for acquiring the migration lock.
  final Duration lockTimeout;
}
