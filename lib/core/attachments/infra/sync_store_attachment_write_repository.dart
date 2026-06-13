import 'package:knit/app/app_graph.dart';
import 'package:knit/core/attachments/domain/attachment_blob_store.dart';
import 'package:knit/core/attachments/domain/attachment_failure.dart';
import 'package:knit/core/attachments/domain/attachment_hashing.dart';
import 'package:knit/core/attachments/domain/attachment_write_repository.dart';
import 'package:knit/core/attachments/domain/picked_image.dart';
import 'package:knit/core/ids/id_generator.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [AttachmentWriteRepository] over the graph's [SyncStore] write path. The
/// bytes go to the content-addressed [AttachmentBlobStore] out-of-band; only the
/// `{kind, mime, content_hash, size}` metadata is signed via `store.create`
/// (spec §7.4.8 — `local_path` is never written, so nothing unsigned reaches the
/// projection). Identical images dedupe to one record + one blob.
class SyncStoreAttachmentWriteRepository implements AttachmentWriteRepository {
  SyncStoreAttachmentWriteRepository({
    required AppGraph graph,
    required IdGenerator ids,
  })  : _graph = graph,
        _ids = ids;

  final AppGraph _graph;
  final IdGenerator _ids;

  static const String _imageKind = 'image';

  AttachmentBlobStore get _blobs => _graph.blobStore;

  @override
  Future<Result<String, AttachmentFailure>> createFromPicked(
    PickedImage image,
  ) async {
    try {
      final hash = await sha256Hex(image.bytes);

      // Record-level dedup: reuse a live record that already holds these bytes.
      for (final s in await _graph.store.readAll(EntityType.attachment)) {
        if (!s.deleted && s.content[AttachmentSchema.colContentHash] == hash) {
          return Ok(s.id);
        }
      }

      await _blobs.put(hash, image.bytes);
      final id = _ids.newId();
      await _graph.store.create(EntityType.attachment, id, {
        AttachmentSchema.colKind: _imageKind,
        AttachmentSchema.colMime: image.mime,
        AttachmentSchema.colContentHash: hash,
        AttachmentSchema.colSize: image.bytes.length,
      });
      return Ok(id);
    } catch (e) {
      return Failure(AttachmentWriteFailure(e.toString()));
    }
  }

  @override
  Future<Result<String, AttachmentFailure>> delete(String attachmentId) async {
    try {
      final record = await _graph.store.get(EntityType.attachment, attachmentId);
      if (record == null) return Failure(AttachmentNotFound(attachmentId));

      final hash =
          record.content[AttachmentSchema.colContentHash] as String?;
      await _graph.store.delete(EntityType.attachment, attachmentId);

      // Reference-counted GC: drop the blob only when no live record shares it.
      if (hash != null) {
        final stillShared = (await _graph.store.readAll(EntityType.attachment))
            .any((s) =>
                !s.deleted &&
                s.id != attachmentId &&
                s.content[AttachmentSchema.colContentHash] == hash);
        if (!stillShared) await _blobs.delete(hash);
      }
      return Ok(attachmentId);
    } catch (e) {
      return Failure(AttachmentWriteFailure(e.toString()));
    }
  }
}
