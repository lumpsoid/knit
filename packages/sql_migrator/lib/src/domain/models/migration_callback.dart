import 'package:sql_migrator/src/domain/models/exceptions.dart';
import 'package:sql_migrator/src/domain/models/migration.dart';

/// Callback invoked after each migration completes successfully.
typedef MigrationCallback =
    Future<void> Function(
      Migration migration,
      MigrationDirection direction,
      int elapsedMs,
    );
