/// Column names and DDL for the `quarantine` table — spec §6.7/§8.8.
///
/// Ops set aside, **not applied** and not advancing the device clock, but
/// retained (diagnosable) and surfaced as a sync warning. Local-only.
abstract class QuarantineSchema {
  static const String table = 'quarantine';

  static const String colOpId = 'op_id';
  static const String colRelaySeq = 'relay_seq';
  static const String colReason = 'reason';
  static const String colRawOp = 'raw_op';
  static const String colSeenAt = 'seen_at';

  static const String createTable =
      '''
      CREATE TABLE IF NOT EXISTS $table (
        $colOpId      TEXT PRIMARY KEY,
        $colRelaySeq  INTEGER,
        $colReason    TEXT NOT NULL,
        $colRawOp     TEXT NOT NULL,
        $colSeenAt    INTEGER NOT NULL
      )
      ''';
}
