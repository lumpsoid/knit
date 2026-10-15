import 'package:knit/app/app_graph.dart';
import 'package:knit/core/attachments/domain/legacy_attachment_split_migration.dart';
import 'package:knit/core/ids/id_generator.dart';
import 'package:knit/sync/sync.dart';

/// [LegacyAttachmentMigrationPort] over the graph's [SyncStore] signed write
/// path. Cards and attachment records are read from the projection; the clone
/// (`store.create`) and the repoint (`store.edit`) are ordinary signed local
/// writes, so the split lands in the change log and survives a rebuild (§8.9).
class SyncStoreLegacyAttachmentMigrationPort
    implements LegacyAttachmentMigrationPort {
  SyncStoreLegacyAttachmentMigrationPort({
    required AppGraph graph,
    required IdGenerator ids,
  }) : _graph = graph,
       _ids = ids;

  final AppGraph _graph;
  final IdGenerator _ids;

  @override
  Future<List<CardAttachmentRef>> liveCardAttachmentRefs() async {
    final refs = <CardAttachmentRef>[];
    for (final card in await _graph.store.readAll(EntityType.card)) {
      if (card.deleted) continue;
      final attachmentId = card.content[CardSchema.colAttachmentId] as String?;
      if (attachmentId != null) {
        refs.add(
          CardAttachmentRef(cardId: card.id, attachmentId: attachmentId),
        );
      }
    }
    refs.sort((a, b) => a.cardId.compareTo(b.cardId));
    return refs;
  }

  @override
  Future<AttachmentRecordContent?> attachmentContent(
    String attachmentId,
  ) async {
    final record = await _graph.store.get(EntityType.attachment, attachmentId);
    if (record == null || record.deleted) return null;
    return AttachmentRecordContent(
      kind: record.content[AttachmentSchema.colKind] as String,
      mime: record.content[AttachmentSchema.colMime] as String,
      contentHash: record.content[AttachmentSchema.colContentHash] as String,
      size: (record.content[AttachmentSchema.colSize] as num).toInt(),
      name: record.content[AttachmentSchema.colName] as String?,
    );
  }

  @override
  Future<String> cloneAttachment(AttachmentRecordContent content) async {
    final id = _ids.newId();
    await _graph.store.create(EntityType.attachment, id, {
      AttachmentSchema.colKind: content.kind,
      AttachmentSchema.colMime: content.mime,
      AttachmentSchema.colContentHash: content.contentHash,
      AttachmentSchema.colSize: content.size,
      AttachmentSchema.colName: content.name,
    });
    return id;
  }

  @override
  Future<void> repointCard(String cardId, String attachmentId) async {
    await _graph.store.edit(EntityType.card, cardId, {
      CardSchema.colAttachmentId: attachmentId,
    });
  }
}
