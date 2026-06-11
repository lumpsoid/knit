import 'package:sql_migrator/src/domain/domain.dart';

/// A simple in-memory [MigrationExecutor] for unit testing migrations
/// without a real SQLite database.
class InMemoryExecutor implements MigrationExecutor {
  final Map<String, List<Map<String, Object?>>> _tables = {};
  final List<String> executedStatements = [];

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    executedStatements.add(sql);

    final normalized = sql.trim().toUpperCase();

    // DDL
    if (normalized.startsWith('CREATE TABLE IF NOT EXISTS')) {
      _tables.putIfAbsent(_extractTableName(sql), () => []);
      return;
    }

    if (normalized.startsWith('CREATE TABLE')) {
      _tables.putIfAbsent(_extractTableName(sql), () => []);
      return;
    }

    if (normalized.startsWith('DROP TABLE')) {
      _tables.remove(_extractTableName(sql));
      return;
    }

    // INSERT [OR REPLACE]
    if (normalized.startsWith('INSERT')) {
      final tableName = _extractTableName(sql);
      _tables.putIfAbsent(tableName, () => []);

      if (arguments != null && arguments.isNotEmpty) {
        final columns = _extractInsertColumns(sql);
        final row = <String, Object?>{};
        for (var i = 0; i < columns.length && i < arguments.length; i++) {
          row[columns[i]] = arguments[i];
        }

        // OR REPLACE: remove existing row whose primary-key column
        // matches. The migration table uses "version" (with rolled_back = 0),
        // but arbitrary test tables use whatever the first column is ("id").
        if (normalized.contains('OR REPLACE')) {
          // Prefer the explicit "version" key used by the migration table;
          // otherwise fall back to the first column in the INSERT list.
          final keyColumn = columns.contains('version')
              ? 'version'
              : (columns.isEmpty ? null : columns.first);

          if (keyColumn != null && row.containsKey(keyColumn)) {
            final keyValue = row[keyColumn];
            // For the migration table, only remove the row when it is also
            // NOT rolled back (rolled_back == 0), matching the PRIMARY KEY
            // definition (version, rolled_back).
            if (keyColumn == 'version') {
              _tables[tableName]?.removeWhere(
                (r) =>
                    r[keyColumn] == keyValue &&
                    (r['rolled_back'] == 0 || r['rolled_back'] == null),
              );
            } else {
              // General table (e.g. "users" with "id") — replace by key only.
              _tables[tableName]?.removeWhere((r) => r[keyColumn] == keyValue);
            }
          }
        }

        _tables[tableName]!.add(row);
      }
      return;
    }

    if (normalized.startsWith('UPDATE')) {
      final tableName = _extractTableName(sql);
      final table = _tables[tableName];
      if (table == null || arguments == null || arguments.isEmpty) return;

      // Determine which SET column is being updated.
      final setRolledBack = normalized.contains('SET ROLLED_BACK');
      final setExecTime = normalized.contains('SET EXECUTION_TIME_MS');

      // The WHERE clause always ends with "WHERE version = ? AND rolled_back
      // = 0"
      // The version value is always the last argument.
      final whereVersion = arguments.last;

      for (final row in table) {
        final matchesVersion = row['version'] == whereVersion;
        final notRolledBack =
            row['rolled_back'] == 0 || row['rolled_back'] == null;

        if (matchesVersion && notRolledBack) {
          if (setRolledBack) {
            // SET rolled_back = 1
            row['rolled_back'] = 1;
          } else if (setExecTime) {
            // SET execution_time_ms = <first arg>
            row['execution_time_ms'] = arguments.first;
          }
        }
      }
      return;
    }

    // DELETE
    if (normalized.startsWith('DELETE')) {
      final tableName = _extractTableName(sql);
      if (arguments != null && arguments.isNotEmpty) {
        _tables[tableName]?.removeWhere((row) {
          return row.values.any((v) => arguments.contains(v));
        });
      } else {
        _tables[tableName]?.clear();
      }
      return;
    }

    // Any other DDL (ALTER, CREATE INDEX, …) — just record it.
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    executedStatements.add(sql);

    final tableName = _extractTableName(sql);
    final rows = _tables[tableName] ?? [];

    // Apply ALL applicable filters before returning.

    final upperSql = sql.toUpperCase();

    // Determine whether there is a rolled_back = 0 predicate in the SQL.
    final filterRolledBack = upperSql.contains('ROLLED_BACK = 0');

    // Extract WHERE column name for argument-based filtering.
    // Matches: WHERE <col> = ?
    final whereColMatch = RegExp(
      r'WHERE\s+(\w+)\s*=\s*\?',
      caseSensitive: false,
    ).firstMatch(sql);
    final whereColumn = whereColMatch?.group(1)?.toLowerCase();

    return rows.where((row) {
      // Check rolled_back = 0 predicate when present in SQL.
      if (filterRolledBack) {
        // Only rows that explicitly have rolled_back == 0 satisfy the predicate
        // Rows without the column (null) do NOT satisfy it.
        final rb = row['rolled_back'];
        if (rb != 0) {
          return false; // null != 0  →  false, so those rows are excluded ✓
        }
      }

      if (arguments != null && arguments.isNotEmpty && whereColumn != null) {
        // Only compare the specific column from the WHERE clause,
        // not all row values — avoids false positives when
        // execution_time_ms or other columns happen to equal the
        // argument value.
        if (row[whereColumn] != arguments.first) return false;
      }

      return true;
    }).toList();
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(MigrationExecutor tx) action,
  ) async {
    return action(this);
  }

  // Helpers

  /// Check if a table exists in the in-memory store.
  bool hasTable(String name) => _tables.containsKey(name);

  /// Get all rows for a table.
  List<Map<String, Object?>> getRows(String tableName) =>
      List.unmodifiable(_tables[tableName] ?? []);

  /// Reset all state.
  void reset() {
    _tables.clear();
    executedStatements.clear();
  }

  String _extractTableName(String sql) {
    final normalized = sql
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    final pattern = RegExp(
      r'(?:FROM|INTO|UPDATE|TABLE(?:\s+IF(?:\s+NOT)?\s+EXISTS)?)\s+(\w+)',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(normalized);
    return match?.group(1) ?? '_unknown';
  }

  List<String> _extractInsertColumns(String sql) {
    final match = RegExp(
      r'\(([^)]+)\)\s*VALUES',
      caseSensitive: false,
    ).firstMatch(sql);
    if (match == null) return [];
    return match.group(1)!.split(',').map((c) => c.trim()).toList();
  }
}
