/// Base exception for all migration-related errors.
sealed class MigrationException implements Exception {
  const MigrationException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() =>
      'MigrationException: $message'
      '${cause != null ? '\n  Caused by: $cause' : ''}';
}

/// Thrown when migration definitions are invalid (e.g. duplicate versions).
class MigrationValidationException extends MigrationException {
  const MigrationValidationException(super.message, [super.cause]);
}

/// Thrown when a migration that was already applied has been modified.
class MigrationChecksumMismatchException extends MigrationException {
  const MigrationChecksumMismatchException({
    required this.version,
    required this.expectedChecksum,
    required this.actualChecksum,
  }) : super(
         'Checksum mismatch for migration v$version. '
         'Expected $expectedChecksum but got $actualChecksum. '
         'Applied migrations must not be modified.',
       );
  final int version;
  final String expectedChecksum;
  final String actualChecksum;
}

/// Thrown when a migration fails during execution.
class MigrationExecutionException extends MigrationException {
  const MigrationExecutionException({
    required this.version,
    required this.direction,
    required String message,
    Object? cause,
  }) : super('Failed to $direction migration v$version: $message', cause);
  final int version;
  final MigrationDirection direction;
}

/// Thrown when attempting to rollback past the earliest applied migration.
class MigrationRollbackException extends MigrationException {
  const MigrationRollbackException(super.message, [super.cause]);
}

/// Thrown when the migration lock cannot be acquired.
class MigrationLockException extends MigrationException {
  const MigrationLockException(super.message, [super.cause]);
}

/// The direction of a migration operation.
enum MigrationDirection { up, down }
