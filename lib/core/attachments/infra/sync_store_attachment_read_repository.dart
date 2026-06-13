import 'package:knit/app/app_graph.dart';
import 'package:knit/core/attachments/domain/attachment_blob_store.dart';
import 'package:knit/core/attachments/domain/attachment_failure.dart';
import 'package:knit/core/attachments/domain/attachment_models.dart';
import 'package:knit/core/attachments/domain/attachment_read_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [AttachmentReadRepository] over the graph: read the signed metadata record
/// for its `content_hash` + `mime`, then load the bytes from the content-
/// addressed [AttachmentBlobStore].
class SyncStoreAttachmentReadRepository implements AttachmentReadRepository {
  SyncStoreAttachmentReadRepository({required AppGraph graph}) : _graph = graph;

  final AppGraph _graph;

  AttachmentBlobStore get _blobs => _graph.blobStore;

  @override
  Future<Result<AttachmentBytes, AttachmentFailure>> bytesOf(
    String attachmentId,
  ) async {
    final record = await _graph.store.get(EntityType.attachment, attachmentId);
    if (record == null || record.deleted) {
      return Failure(AttachmentNotFound(attachmentId));
    }

    final hash = record.content[AttachmentSchema.colContentHash] as String?;
    if (hash == null) return Failure(AttachmentNotFound(attachmentId));

    final bytes = await _blobs.readBytes(hash);
    if (bytes == null) return Failure(AttachmentBytesMissing(hash));

    final mime = record.content[AttachmentSchema.colMime] as String? ??
        'application/octet-stream';
    return Ok(AttachmentBytes(bytes: bytes, mime: mime));
  }
}
