import 'dart:typed_data';

import 'package:knit/app/app_graph.dart';
import 'package:knit/core/attachments/domain/attachment_blob_store.dart';
import 'package:knit/core/attachments/domain/attachment_failure.dart';
import 'package:knit/core/attachments/domain/attachment_hashing.dart';
import 'package:knit/core/attachments/domain/attachment_write_repository.dart';
import 'package:knit/core/attachments/domain/picked_audio.dart';
import 'package:knit/core/attachments/domain/picked_file.dart';
import 'package:knit/core/attachments/domain/picked_image.dart';
import 'package:knit/core/ids/id_generator.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [AttachmentWriteRepository] over the graph's [SyncStore] write path. The
/// bytes go to the content-addressed [AttachmentBlobStore] out-of-band; only the
/// `{kind, mime, content_hash, size}` metadata is signed via `store.create`
/// (spec §7.4.8 — `local_path` is never written, so nothing unsigned reaches the
/// projection).
///
/// Invariant: **1 referent : 1 attachment record.** Identical bytes share one
/// content-addressed blob, ref-counted across records. Every capture mints its
/// own record, so removing one card's attachment can never orphan a sibling
/// card that reused the same photo/bytes.
class SyncStoreAttachmentWriteRepository implements AttachmentWriteRepository {
  SyncStoreAttachmentWriteRepository({
    required AppGraph graph,
    required IdGenerator ids,
  })  : _graph = graph,
        _ids = ids;

  final AppGraph _graph;
  final IdGenerator _ids;

  static const String _imageKind = 'image';
  static const String _audioKind = 'audio';
  static const String _fileKind = 'file';

  AttachmentBlobStore get _blobs => _graph.blobStore;

  @override
  Future<Result<String, AttachmentFailure>> createFromPicked(
    PickedImage image,
  ) => _create(image.bytes, image.mime, _imageKind);

  @override
  Future<Result<String, AttachmentFailure>> createFromAudio(
    PickedAudio audio,
  ) => _create(audio.bytes, audio.mime, _audioKind);

  @override
  Future<Result<String, AttachmentFailure>> createFromFile(
    PickedFile file,
  ) => _create(file.bytes, file.mime, _fileKind, name: file.name);

  /// Shared capture path (spec §7.4.8): hash → blob put → signed metadata
  /// record. Identical bytes share one content-addressed blob (idempotent put),
  /// but every capture mints its OWN record (1 referent : 1 record), so removing
  /// one card's attachment can never orphan a sibling that reused the bytes.
  Future<Result<String, AttachmentFailure>> _create(
    Uint8List bytes,
    String mime,
    String kind, {
    String? name,
  }) async {
    try {
      final hash = await sha256Hex(bytes);

      await _blobs.put(hash, bytes);
      final id = _ids.newId();
      await _graph.store.create(EntityType.attachment, id, {
        AttachmentSchema.colKind: kind,
        AttachmentSchema.colMime: mime,
        AttachmentSchema.colContentHash: hash,
        AttachmentSchema.colSize: bytes.length,
        AttachmentSchema.colName: name,
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
