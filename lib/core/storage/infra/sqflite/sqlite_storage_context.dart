import 'package:knit/core/storage/domain/storage_context.dart';
import 'package:sqflite/sqflite.dart';

/// A [StorageContext] carrying a sqflite [DatabaseExecutor] — either a
/// `Database` or a `Transaction`. Storages read `ctx.executor` to join the
/// ambient transaction:
///
/// ```dart
/// DatabaseExecutor _exec(StorageContext? ctx) =>
///     ctx is SqliteStorageContext ? ctx.executor : _db;
/// ```
class SqliteStorageContext implements StorageContext {
  const SqliteStorageContext(this.executor, {this.isInTransaction = true});

  /// The sqflite executor bound to this context (a `Database` or `Transaction`).
  final DatabaseExecutor executor;

  @override
  final bool isInTransaction;
}
