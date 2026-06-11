import 'package:sqflite/sqflite.dart';
import 'package:sql_migrator/src/domain/migration_executor.dart';

/// Adapter for `package:sqflite` databases.
///
/// Usage:
/// ```dart
/// import 'package:sqflite/sqflite.dart';
/// import 'package:sql_migrator/sql_migrator.dart';
///
/// final db = await openDatabase('app.db');
/// final executor = SqfliteExecutor(db);
/// final migrator = Migrator(executor: executor, migrations: myMigrations);
/// await migrator.migrate();
/// ```

/// A [MigrationExecutor] backed by a sqflite [Database] instance.
class SqfliteExecutor implements MigrationExecutor {
  /// Wraps a sqflite `Database` instance.
  ///
  /// Example:
  /// ```dart
  /// final db = await openDatabase('my_app.db');
  /// final executor = SqfliteExecutor(db);
  /// ```
  SqfliteExecutor(this._db);

  final Database _db;

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    await _db.execute(sql, arguments ?? []);
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final results = await _db.rawQuery(sql, arguments ?? []);
    // sqflite returns List<Map<String, Object?>> — cast for safety
    return List<Map<String, Object?>>.from(results);
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(MigrationExecutor tx) action,
  ) async {
    return _db.transaction((txn) async {
      final txExecutor = _SqfliteTxnExecutor(txn);
      return action(txExecutor);
    });
  }
}

class _SqfliteTxnExecutor implements MigrationExecutor {
  _SqfliteTxnExecutor(this._txn);
  final Transaction _txn;

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    await _txn.execute(sql, arguments ?? []);
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final results = await _txn.rawQuery(sql, arguments ?? []);
    return List<Map<String, Object?>>.from(results);
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(MigrationExecutor tx) action,
  ) async {
    // Nested transactions in SQLite are savepoints — sqflite handles this
    // We just pass through
    return action(this);
  }
}
