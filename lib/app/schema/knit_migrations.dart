import 'package:knit/sync/sync.dart';
import 'package:sql_migrator/sql_migrator.dart';

/// The Knit sqflite schema as ordered migrations (`package:sql_migrator`). The
/// production graph runs these against the per-device DB before building the
/// [SyncStore], so the migrator — not `SyncStore.ensureSchema` — owns the
/// schema and its future versioned changes.
///
/// v1 is the baseline: every sync table (§6.3–6.7). The DDL is reused verbatim
/// from each storage's schema constant, and each statement is
/// `CREATE TABLE IF NOT EXISTS`, so this stays idempotent with any later
/// `ensureSchema` call.
List<Migration> knitMigrations() => [
      Migration(
        version: 1,
        description: 'baseline sync schema (collection/card/link/attachment/'
            'profile + change_log/device_clock/local_identity/quarantine)',
        up: (db) async {
          for (final ddl in _baselineDdl) {
            await db.execute(ddl);
          }
        },
        down: (db) async {
          for (final table in _baselineTables) {
            await db.execute('DROP TABLE IF EXISTS $table');
          }
        },
      ),
    ];

const List<String> _baselineDdl = [
  ...ProjectionTables.createStatements,
  ChangeLogSchema.createTable,
  DeviceClockSchema.createTable,
  LocalIdentitySchema.createTable,
  QuarantineSchema.createTable,
];

const List<String> _baselineTables = [
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
