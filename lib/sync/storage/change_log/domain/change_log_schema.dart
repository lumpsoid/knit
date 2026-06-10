/// Column names and DDL for the `change_log` table — spec §6.6.
///
/// `change_log` is the durable thing pushed over the relay and replayed to
/// rebuild the projection (§8.9); the entity tables are a disposable cache of it.
/// Each row is a full signed snapshot of an entity (not a field delta), and the
/// op's signature *is* the entity's signature.
abstract class ChangeLogSchema {
  static const String table = 'change_log';

  /// Local-only autoincrement; drives push order. Never shared.
  static const String colSeq = 'seq';

  /// Idempotency key — sig-keyed `op_id` (spec §7.3). UNIQUE.
  static const String colOpId = 'op_id';

  /// Routing/index hint; authoritative type is `payload.t`.
  static const String colEntityType = 'entity_type';
  static const String colEntityId = 'entity_id';

  /// Routing hint `put`/`delete`; `payload.deleted` is authoritative (spec §7.0).
  static const String colOp = 'op';

  static const String colHlcMs = 'hlc_ms';
  static const String colHlcCounter = 'hlc_counter';
  static const String colAuthor = 'author';

  /// The canonical signed snapshot, verbatim bytes (spec §7.1).
  static const String colPayload = 'payload';

  /// Ed25519 (hex) over `utf8(payload)`; == the entity's sig.
  static const String colSig = 'sig';

  /// `local` | `remote`.
  static const String colOrigin = 'origin';

  /// 1 once a local op is confirmed by the relay (pending = local & !acked).
  static const String colAcked = 'acked';

  static const String createTable =
      '''
      CREATE TABLE IF NOT EXISTS $table (
        $colSeq         INTEGER PRIMARY KEY AUTOINCREMENT,
        $colOpId        TEXT UNIQUE NOT NULL,
        $colEntityType  TEXT NOT NULL,
        $colEntityId    TEXT NOT NULL,
        $colOp          TEXT NOT NULL,
        $colHlcMs       INTEGER NOT NULL,
        $colHlcCounter  INTEGER NOT NULL,
        $colAuthor      TEXT NOT NULL,
        $colPayload     TEXT NOT NULL,
        $colSig         TEXT NOT NULL,
        $colOrigin      TEXT NOT NULL,
        $colAcked       INTEGER NOT NULL DEFAULT 0
      )
      ''';
}
