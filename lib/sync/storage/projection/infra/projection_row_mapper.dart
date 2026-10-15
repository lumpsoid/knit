import 'package:knit/sync/hlc.dart';
import 'package:knit/sync/snapshot.dart';
import 'package:knit/sync/storage/projection/domain/entity_schema.dart';

/// Maps a [Snapshot] to/from a typed entity-table row (spec §6.4). The envelope
/// columns are shared; the rest are the entity-specific content fields, kept on
/// the same keys [Snapshot.fromPayload] uses so projection rows and parsed ops
/// are interchangeable in merge.
abstract class ProjectionRowMapper {
  static Map<String, Object?> _envelope(Snapshot s) => {
    EnvelopeColumns.colId: s.id,
    EnvelopeColumns.colAuthor: s.author,
    EnvelopeColumns.colCreatedBy: s.createdBy,
    EnvelopeColumns.colCreatedAt: s.createdAt,
    EnvelopeColumns.colHlcMs: s.hlc.ms,
    EnvelopeColumns.colHlcCounter: s.hlc.counter,
    EnvelopeColumns.colDeleted: s.deleted ? 1 : 0,
    EnvelopeColumns.colSig: s.sig,
  };

  /// Snapshot -> row for [snapshot.type]'s table.
  static Map<String, Object?> toRow(Snapshot s) {
    final c = s.content;
    return switch (s.type) {
      EntityType.collection => {
        ..._envelope(s),
        CollectionSchema.colTitle: c[CollectionSchema.colTitle],
        CollectionSchema.colDescription: c[CollectionSchema.colDescription],
        CollectionSchema.colCoverAttachmentId:
            c[CollectionSchema.colCoverAttachmentId],
      },
      EntityType.card => {
        ..._envelope(s),
        CardSchema.colCollectionId: c[CardSchema.colCollectionId],
        CardSchema.colKind: c[CardSchema.colKind],
        CardSchema.colText: c[CardSchema.colText],
        CardSchema.colAttachmentId: c[CardSchema.colAttachmentId],
        CardSchema.colPosition: s.position,
        CardSchema.colPositionMs: s.placement!.ms,
        CardSchema.colPositionCounter: s.placement!.counter,
      },
      EntityType.link => {
        ..._envelope(s),
        LinkSchema.colSourceType: c[LinkSchema.colSourceType],
        LinkSchema.colSourceId: c[LinkSchema.colSourceId],
        LinkSchema.colTargetType: c[LinkSchema.colTargetType],
        LinkSchema.colTargetId: c[LinkSchema.colTargetId],
        LinkSchema.colLabel: c[LinkSchema.colLabel],
      },
      EntityType.attachment => {
        ..._envelope(s),
        AttachmentSchema.colKind: c[AttachmentSchema.colKind],
        AttachmentSchema.colMime: c[AttachmentSchema.colMime],
        AttachmentSchema.colContentHash: c[AttachmentSchema.colContentHash],
        AttachmentSchema.colSize: c[AttachmentSchema.colSize],
        AttachmentSchema.colName: c[AttachmentSchema.colName],
        AttachmentSchema.colLocalPath: c[AttachmentSchema.colLocalPath],
      },
      EntityType.profile => {
        ..._envelope(s),
        ProfileSchema.colNickname: c[ProfileSchema.colNickname],
      },
    };
  }

  /// Row -> Snapshot for [type]'s table.
  static Snapshot fromRow(EntityType type, Map<String, Object?> row) {
    Snapshot build({
      Hlc? placement,
      String? position,
      required Map<String, Object?> content,
    }) => Snapshot(
      type: type,
      id: row[EnvelopeColumns.colId]! as String,
      author: row[EnvelopeColumns.colAuthor]! as String,
      createdBy: row[EnvelopeColumns.colCreatedBy]! as String,
      createdAt: row[EnvelopeColumns.colCreatedAt]! as int,
      hlc: Hlc(
        row[EnvelopeColumns.colHlcMs]! as int,
        row[EnvelopeColumns.colHlcCounter]! as int,
      ),
      deleted: (row[EnvelopeColumns.colDeleted]! as int) != 0,
      sig: row[EnvelopeColumns.colSig]! as String,
      placement: placement,
      position: position,
      content: content,
    );

    return switch (type) {
      EntityType.collection => build(
        content: {
          CollectionSchema.colTitle: row[CollectionSchema.colTitle],
          CollectionSchema.colDescription: row[CollectionSchema.colDescription],
          CollectionSchema.colCoverAttachmentId:
              row[CollectionSchema.colCoverAttachmentId],
        },
      ),
      EntityType.card => build(
        placement: Hlc(
          row[CardSchema.colPositionMs]! as int,
          row[CardSchema.colPositionCounter]! as int,
        ),
        position: row[CardSchema.colPosition]! as String,
        content: {
          CardSchema.colCollectionId: row[CardSchema.colCollectionId],
          CardSchema.colKind: row[CardSchema.colKind],
          CardSchema.colText: row[CardSchema.colText],
          CardSchema.colAttachmentId: row[CardSchema.colAttachmentId],
        },
      ),
      EntityType.link => build(
        content: {
          LinkSchema.colSourceType: row[LinkSchema.colSourceType],
          LinkSchema.colSourceId: row[LinkSchema.colSourceId],
          LinkSchema.colTargetType: row[LinkSchema.colTargetType],
          LinkSchema.colTargetId: row[LinkSchema.colTargetId],
          LinkSchema.colLabel: row[LinkSchema.colLabel],
        },
      ),
      EntityType.attachment => build(
        content: {
          AttachmentSchema.colKind: row[AttachmentSchema.colKind],
          AttachmentSchema.colMime: row[AttachmentSchema.colMime],
          AttachmentSchema.colContentHash: row[AttachmentSchema.colContentHash],
          AttachmentSchema.colSize: row[AttachmentSchema.colSize],
          AttachmentSchema.colName: row[AttachmentSchema.colName],
          AttachmentSchema.colLocalPath: row[AttachmentSchema.colLocalPath],
        },
      ),
      EntityType.profile => build(
        content: {ProfileSchema.colNickname: row[ProfileSchema.colNickname]},
      ),
    };
  }
}
