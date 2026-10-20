import 'package:knit/sync/sync.dart';
import 'package:sql_migrator/sql_migrator.dart';

/// The Knit sqflite schema as ordered migrations (`package:sql_migrator`). The
/// production graph runs these against the per-device DB before building the
/// [SyncStore], so the migrator — not `SyncStore.ensureSchema` — owns the
/// schema and its versioned evolution.
///
/// ## v1 is a frozen historical snapshot — never edit it
///
/// v1 is the schema **as the first build shipped it**, written out as literal
/// DDL. It deliberately does *not* reuse the `*Schema.createTable` constants:
/// those track the *current* schema (and feed `ensureSchema` for the in-memory
/// dev/test storages), so reusing them would let a column added to a constant
/// silently change what v1 creates — and then a later additive migration would
/// `ADD COLUMN` something v1 already made, throwing "duplicate column name" on
/// every fresh install. That is exactly what broke `attachment.name` /
/// `collection.description` before they were reframed as the migrations below.
///
/// **To change the schema:** edit the storage's `*Schema` constant (for
/// `ensureSchema` / new code) AND append a new `Migration(version: N, …)` with
/// the matching `ALTER`. Never touch v1, and never fold the new column back
/// into the frozen baseline. Every device — fresh or upgrading — then runs the
/// same honest linear chain to the current schema.
List<Migration> knitMigrations() => [
  Migration(
    version: 1,
    description:
        'baseline sync schema (collection/card/link/attachment/'
        'profile + change_log/device_clock/local_identity/quarantine)',
    up: (db) async {
      for (final ddl in _v1BaselineDdl) {
        await db.execute(ddl);
      }
    },
    down: (db) async {
      for (final table in _v1BaselineTables) {
        await db.execute('DROP TABLE IF EXISTS $table');
      }
    },
  ),
  // v2: the file-attachment `name` field (spec §7.4.8). Absent from the v1
  // baseline, so this adds it on every device — no guard needed.
  Migration(
    version: 2,
    description: 'add attachment.name for file attachments (§7.4.8)',
    up: (db) => db.execute(
      'ALTER TABLE ${AttachmentSchema.table} '
      'ADD COLUMN ${AttachmentSchema.colName} TEXT',
    ),
    down: (db) => db.execute(
      'ALTER TABLE ${AttachmentSchema.table} '
      'DROP COLUMN ${AttachmentSchema.colName}',
    ),
  ),
  // v3: the optional `description` field on a collection (spec §3.1/§7.4).
  Migration(
    version: 3,
    description: 'add collection.description (§3.1/§7.4)',
    up: (db) => db.execute(
      'ALTER TABLE ${CollectionSchema.table} '
      'ADD COLUMN ${CollectionSchema.colDescription} TEXT',
    ),
    down: (db) => db.execute(
      'ALTER TABLE ${CollectionSchema.table} '
      'DROP COLUMN ${CollectionSchema.colDescription}',
    ),
  ),
  // v4: read-path indexes for large collections — the paged card feed and
  // the batched per-card link counts (§8.6/§8.7). Indexes only; no data change.
  Migration(
    version: 4,
    description: 'add card feed + link source/target indexes',
    up: (db) async {
      for (final ddl in ProjectionTables.indexStatements) {
        await db.execute(ddl);
      }
    },
    down: (db) async {
      for (final name in const [
        'idx_card_feed',
        'idx_link_source',
        'idx_link_target',
      ]) {
        await db.execute('DROP INDEX IF EXISTS $name');
      }
    },
  ),
  // v5: when a card was settled (spec §3.3/§7.4.3); null while it is live.
  Migration(
    version: 5,
    description: 'add card.settled_at (§3.3/§7.4.3)',
    up: (db) => db.execute(
      'ALTER TABLE ${CardSchema.table} '
      'ADD COLUMN ${CardSchema.colSettledAt} INTEGER',
    ),
    down: (db) => db.execute(
      'ALTER TABLE ${CardSchema.table} '
      'DROP COLUMN ${CardSchema.colSettledAt}',
    ),
  ),
  // v6: when a collection was archived (spec §3.4/§7.4.1); null while it is
  // on the home timeline.
  Migration(
    version: 6,
    description: 'add collection.archived_at (§3.4/§7.4.1)',
    up: (db) => db.execute(
      'ALTER TABLE ${CollectionSchema.table} '
      'ADD COLUMN ${CollectionSchema.colArchivedAt} INTEGER',
    ),
    down: (db) => db.execute(
      'ALTER TABLE ${CollectionSchema.table} '
      'DROP COLUMN ${CollectionSchema.colArchivedAt}',
    ),
  ),
  // v7: when a card was emphasized (spec §3.3/§7.4.3); null when it is not.
  Migration(
    version: 7,
    description: 'add card.emphasized_at (§3.3/§7.4.3)',
    up: (db) => db.execute(
      'ALTER TABLE ${CardSchema.table} '
      'ADD COLUMN ${CardSchema.colEmphasizedAt} INTEGER',
    ),
    down: (db) => db.execute(
      'ALTER TABLE ${CardSchema.table} '
      'DROP COLUMN ${CardSchema.colEmphasizedAt}',
    ),
  ),
];

/// The frozen v1 schema — literal DDL, the shape the first build shipped.
/// `attachment.name` (v2), `collection.description` (v3), `card.settled_at`
/// (v5), `collection.archived_at` (v6) and `card.emphasized_at` (v7) are
/// intentionally absent; later migrations add them. Do not edit these strings.
const List<String> _v1BaselineDdl = [
  '''
  CREATE TABLE IF NOT EXISTS collection (
    id           TEXT PRIMARY KEY,
    author       TEXT NOT NULL,
    created_by   TEXT NOT NULL,
    created_at   INTEGER NOT NULL,
    hlc_ms       INTEGER NOT NULL,
    hlc_counter  INTEGER NOT NULL,
    deleted      INTEGER NOT NULL DEFAULT 0,
    sig          TEXT NOT NULL,
    title                TEXT NOT NULL,
    cover_attachment_id  TEXT
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS card (
    id           TEXT PRIMARY KEY,
    author       TEXT NOT NULL,
    created_by   TEXT NOT NULL,
    created_at   INTEGER NOT NULL,
    hlc_ms       INTEGER NOT NULL,
    hlc_counter  INTEGER NOT NULL,
    deleted      INTEGER NOT NULL DEFAULT 0,
    sig          TEXT NOT NULL,
    collection_id     TEXT NOT NULL,
    kind              TEXT NOT NULL,
    text              TEXT,
    attachment_id     TEXT,
    position          TEXT NOT NULL,
    position_ms       INTEGER NOT NULL,
    position_counter  INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS link (
    id           TEXT PRIMARY KEY,
    author       TEXT NOT NULL,
    created_by   TEXT NOT NULL,
    created_at   INTEGER NOT NULL,
    hlc_ms       INTEGER NOT NULL,
    hlc_counter  INTEGER NOT NULL,
    deleted      INTEGER NOT NULL DEFAULT 0,
    sig          TEXT NOT NULL,
    source_type  TEXT NOT NULL,
    source_id    TEXT NOT NULL,
    target_type  TEXT NOT NULL,
    target_id    TEXT NOT NULL,
    label        TEXT
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS attachment (
    id           TEXT PRIMARY KEY,
    author       TEXT NOT NULL,
    created_by   TEXT NOT NULL,
    created_at   INTEGER NOT NULL,
    hlc_ms       INTEGER NOT NULL,
    hlc_counter  INTEGER NOT NULL,
    deleted      INTEGER NOT NULL DEFAULT 0,
    sig          TEXT NOT NULL,
    kind          TEXT NOT NULL,
    mime          TEXT NOT NULL,
    content_hash  TEXT NOT NULL,
    size          INTEGER NOT NULL,
    local_path    TEXT
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS profile (
    id           TEXT PRIMARY KEY,
    author       TEXT NOT NULL,
    created_by   TEXT NOT NULL,
    created_at   INTEGER NOT NULL,
    hlc_ms       INTEGER NOT NULL,
    hlc_counter  INTEGER NOT NULL,
    deleted      INTEGER NOT NULL DEFAULT 0,
    sig          TEXT NOT NULL,
    nickname  TEXT
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS change_log (
    seq          INTEGER PRIMARY KEY AUTOINCREMENT,
    op_id        TEXT UNIQUE NOT NULL,
    entity_type  TEXT NOT NULL,
    entity_id    TEXT NOT NULL,
    op           TEXT NOT NULL,
    hlc_ms       INTEGER NOT NULL,
    hlc_counter  INTEGER NOT NULL,
    author       TEXT NOT NULL,
    payload      TEXT NOT NULL,
    sig          TEXT NOT NULL,
    origin       TEXT NOT NULL,
    acked        INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS device_clock (
    id           INTEGER PRIMARY KEY CHECK (id = 0),
    hlc_ms       INTEGER NOT NULL,
    hlc_counter  INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS local_identity (
    public_key      TEXT PRIMARY KEY,
    secret_key_enc  BLOB NOT NULL,
    created_at      INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS quarantine (
    op_id      TEXT PRIMARY KEY,
    relay_seq  INTEGER,
    reason     TEXT NOT NULL,
    raw_op     TEXT NOT NULL,
    seen_at    INTEGER NOT NULL
  )
  ''',
];

const List<String> _v1BaselineTables = [
  CollectionSchema.table,
  CardSchema.table,
  LinkSchema.table,
  AttachmentSchema.table,
  ProfileSchema.table,
  ChangeLogSchema.table,
  DeviceClockSchema.table,
  LocalIdentitySchema.table,
  QuarantineSchema.table,
];
