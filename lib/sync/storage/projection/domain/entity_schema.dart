/// Column names and DDL for the entity projection tables — spec §6.3 (envelope)
/// + §6.4 (entity tables).
///
/// These tables are the materialized projection: a fast, disposable cache of
/// `change_log` (spec §6.8/§8.9). The UI queries them; merge writes the winning
/// snapshot into them. Every synced table carries the [EnvelopeColumns] prefix.
library;

import 'package:knit/sync/snapshot.dart';

/// The envelope every synced row carries (spec §6.3).
abstract class EnvelopeColumns {
  static const String colId = 'id';
  static const String colAuthor = 'author';
  static const String colCreatedBy = 'created_by';
  static const String colCreatedAt = 'created_at';
  static const String colHlcMs = 'hlc_ms';
  static const String colHlcCounter = 'hlc_counter';
  static const String colDeleted = 'deleted';
  static const String colSig = 'sig';

  /// Shared DDL fragment — the envelope columns, spliced into each table.
  static const String ddl =
      '''
        $colId          TEXT PRIMARY KEY,
        $colAuthor      TEXT NOT NULL,
        $colCreatedBy   TEXT NOT NULL,
        $colCreatedAt   INTEGER NOT NULL,
        $colHlcMs       INTEGER NOT NULL,
        $colHlcCounter  INTEGER NOT NULL,
        $colDeleted     INTEGER NOT NULL DEFAULT 0,
        $colSig         TEXT NOT NULL''';
}

/// A topic notebook (spec §6.4) — title + optional description + optional cover
/// image.
abstract class CollectionSchema {
  static const String table = 'collection';
  static const String colTitle = 'title';
  static const String colDescription = 'description';
  static const String colCoverAttachmentId = 'cover_attachment_id';

  static const String createTable =
      '''
      CREATE TABLE IF NOT EXISTS $table (
        ${EnvelopeColumns.ddl},
        $colTitle              TEXT NOT NULL,
        $colDescription        TEXT,
        $colCoverAttachmentId  TEXT
      )
      ''';
}

/// One step/point/clip in a feed (spec §6.4) — carries the separate placement
/// clock (`position_*`).
abstract class CardSchema {
  static const String table = 'card';
  static const String colCollectionId = 'collection_id';
  static const String colKind = 'kind';
  static const String colText = 'text';
  static const String colAttachmentId = 'attachment_id';
  static const String colPosition = 'position';
  static const String colPositionMs = 'position_ms';
  static const String colPositionCounter = 'position_counter';

  static const String createTable =
      '''
      CREATE TABLE IF NOT EXISTS $table (
        ${EnvelopeColumns.ddl},
        $colCollectionId     TEXT NOT NULL,
        $colKind             TEXT NOT NULL,
        $colText             TEXT,
        $colAttachmentId     TEXT,
        $colPosition         TEXT NOT NULL,
        $colPositionMs       INTEGER NOT NULL,
        $colPositionCounter  INTEGER NOT NULL
      )
      ''';
}

/// The one neutral edge primitive (spec §6.4): any node -> any node.
abstract class LinkSchema {
  static const String table = 'link';
  static const String colSourceType = 'source_type';
  static const String colSourceId = 'source_id';
  static const String colTargetType = 'target_type';
  static const String colTargetId = 'target_id';
  static const String colLabel = 'label';

  static const String createTable =
      '''
      CREATE TABLE IF NOT EXISTS $table (
        ${EnvelopeColumns.ddl},
        $colSourceType  TEXT NOT NULL,
        $colSourceId    TEXT NOT NULL,
        $colTargetType  TEXT NOT NULL,
        $colTargetId    TEXT NOT NULL,
        $colLabel       TEXT
      )
      ''';
}

/// Media metadata (spec §6.4) — bytes live on the filesystem; `local_path` is
/// device-local, NOT synced, NOT signed. `name` is the original file name of a
/// `file`-kind attachment (spec §7.4.8), synced + signed; null for image/audio.
abstract class AttachmentSchema {
  static const String table = 'attachment';
  static const String colKind = 'kind';
  static const String colMime = 'mime';
  static const String colContentHash = 'content_hash';
  static const String colSize = 'size';
  static const String colName = 'name';
  static const String colLocalPath = 'local_path';

  static const String createTable =
      '''
      CREATE TABLE IF NOT EXISTS $table (
        ${EnvelopeColumns.ddl},
        $colKind         TEXT NOT NULL,
        $colMime         TEXT NOT NULL,
        $colContentHash  TEXT NOT NULL,
        $colSize         INTEGER NOT NULL,
        $colName         TEXT,
        $colLocalPath    TEXT
      )
      ''';
}

/// A peer's signed display name (spec §6.5/§7.4.7) — its `id` IS the pubkey.
abstract class ProfileSchema {
  static const String table = 'profile';
  static const String colNickname = 'nickname';

  static const String createTable =
      '''
      CREATE TABLE IF NOT EXISTS $table (
        ${EnvelopeColumns.ddl},
        $colNickname  TEXT
      )
      ''';
}

/// The table name backing each entity type, and the full set of create
/// statements (used by `ensureSchema` / rebuild truncation).
abstract class ProjectionTables {
  static String of(EntityType type) => switch (type) {
    EntityType.collection => CollectionSchema.table,
    EntityType.card => CardSchema.table,
    EntityType.link => LinkSchema.table,
    EntityType.attachment => AttachmentSchema.table,
    EntityType.profile => ProfileSchema.table,
  };

  static const List<String> createStatements = [
    CollectionSchema.createTable,
    CardSchema.createTable,
    LinkSchema.createTable,
    AttachmentSchema.createTable,
    ProfileSchema.createTable,
  ];

  static const List<EntityType> all = EntityType.values;
}
