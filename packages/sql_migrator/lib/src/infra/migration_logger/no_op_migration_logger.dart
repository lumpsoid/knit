import 'package:sql_migrator/src/domain/migration_logger.dart';

/// Silent logger that discards all messages. Useful for tests.
class NoOpMigrationLogger implements MigrationLogger {
  const NoOpMigrationLogger();

  @override
  void info(String message) {}
  @override
  void warning(String message) {}
  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {}
}
