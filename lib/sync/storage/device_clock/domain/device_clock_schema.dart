/// Column names and DDL for the single-row `device_clock` table — spec §6.7.
///
/// The single per-device HLC: local-only, never synced/signed. Crash-safety
/// (spec §8.1): its update must commit in the **same transaction** as the op
/// that advanced it — drive it through a `UnitOfWork` alongside the projection
/// and change_log writes.
abstract class DeviceClockSchema {
  static const String table = 'device_clock';

  /// The CHECK-constrained single-row id.
  static const String colId = 'id';
  static const int rowId = 0;

  static const String colHlcMs = 'hlc_ms';
  static const String colHlcCounter = 'hlc_counter';

  static const String createTable =
      '''
      CREATE TABLE IF NOT EXISTS $table (
        $colId          INTEGER PRIMARY KEY CHECK ($colId = $rowId),
        $colHlcMs       INTEGER NOT NULL,
        $colHlcCounter  INTEGER NOT NULL
      )
      ''';
}
