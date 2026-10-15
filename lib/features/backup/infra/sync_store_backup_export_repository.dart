import 'dart:convert';
import 'dart:typed_data';

import 'package:result_dart/result_dart.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/features/backup/domain/backup_export_repository.dart';
import 'package:knit/features/backup/domain/backup_failure.dart';
import 'package:knit/features/backup/domain/backup_models.dart';
import 'package:knit/features/backup/infra/backup_archive_codec.dart';
import 'package:knit/sync/sync.dart';

/// [BackupExportRepository] over the graph's [SyncStore] + blob store.
///
/// The bundle is the **signed `change_log`** (the durable truth, §8.9) — each op
/// serialized verbatim via [PersistedOp.toDb] so the canonical signed `payload`
/// survives byte-for-byte (no re-canonicalization) — plus the content-addressed
/// attachment **bytes** pulled from the blob store by `content_hash`. A missing
/// blob is skipped, not fatal: the metadata op still ships, and import surfaces
/// the gap.
class SyncStoreBackupExportRepository implements BackupExportRepository {
  SyncStoreBackupExportRepository({
    required AppGraph graph,
    BackupArchiveCodec codec = const BackupArchiveCodec(),
    DateTime Function() now = DateTime.now,
  }) : _graph = graph,
       _codec = codec,
       _now = now;

  final AppGraph _graph;
  final BackupArchiveCodec _codec;
  final DateTime Function() _now;

  @override
  Future<Result<BackupArchive, BackupFailure>> exportAll() async {
    try {
      final store = _graph.store;

      final ops = await store.changeLog.readOrdered();
      final opLines = ops
          .map((op) => jsonEncode(op.toDb()))
          .toList(growable: false);

      final blobs = <String, Uint8List>{};
      for (final attachment in await store.readAll(EntityType.attachment)) {
        final hash =
            attachment.content[AttachmentSchema.colContentHash] as String?;
        if (hash == null || hash.isEmpty || blobs.containsKey(hash)) continue;
        final bytes = await _graph.blobStore.readBytes(hash);
        if (bytes != null) blobs[hash] = bytes;
      }

      final author = await store.authorPubkey();
      final stampMs = _now().millisecondsSinceEpoch;
      final manifest = BackupManifest(
        createdAtMs: stampMs,
        author: author,
        opCount: opLines.length,
        blobCount: blobs.length,
      );

      final bytes = _codec.encode(
        manifest: manifest,
        opLines: opLines,
        blobs: blobs,
      );
      final shortAuthor = author.length >= 8 ? author.substring(0, 8) : author;
      return Ok(
        BackupArchive(
          bytes: bytes,
          fileName: 'knit-backup-$shortAuthor-$stampMs.zip',
        ),
      );
    } catch (e, st) {
      return Failure(BackupExportFailure(e, st));
    }
  }
}
