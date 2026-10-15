import 'dart:convert';
import 'dart:typed_data';

import 'package:result_dart/result_dart.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/core/attachments/attachments.dart';
import 'package:knit/features/backup/domain/backup_failure.dart';
import 'package:knit/features/backup/domain/backup_import_repository.dart';
import 'package:knit/features/backup/domain/backup_models.dart';
import 'package:knit/features/backup/infra/backup_archive_codec.dart';
import 'package:knit/sync/sync.dart';

/// [BackupImportRepository] over the graph's [SyncStore] + blob store.
///
/// Restore = **replay**: each signed op runs back through
/// [SyncStore.applyRemote], which dedups by `op_id`, **re-verifies the signature
/// over the payload bytes**, skew-guards, and merges in one transaction (§8.5) —
/// so a restore inherits the full integrity chain and is order-independent
/// (§8.9). Blobs are content-addressed: each is re-hashed and only written when
/// the bytes match their `content_hash` (tamper/corruption check).
///
/// Note (§6.6): `applyRemote` records every op as `origin: remote, acked: true`,
/// so after restoring your own backup the pending-sync count reads zero — correct
/// for a restore (typically onto a fresh device).
class SyncStoreBackupImportRepository implements BackupImportRepository {
  SyncStoreBackupImportRepository({
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
  Future<Result<ImportSummary, BackupFailure>> importArchive(
    Uint8List bytes,
  ) async {
    final ParsedBackup parsed;
    try {
      parsed = _codec.decode(bytes);
    } on FormatException catch (e, st) {
      return Failure(BackupCorruptArchiveFailure(e, st));
    }

    try {
      // Blobs first so an attachment op's bytes are present once it applies.
      var blobsRestored = 0;
      var blobsMismatched = 0;
      for (final entry in parsed.blobs.entries) {
        final actual = await sha256Hex(entry.value);
        if (actual != entry.key) {
          blobsMismatched++;
          continue;
        }
        await _graph.blobStore.put(entry.key, entry.value);
        blobsRestored++;
      }

      var opsApplied = 0;
      var opsDeduped = 0;
      var opsQuarantined = 0;
      for (final line in parsed.opLines) {
        final op = PersistedOp.fromDb(jsonDecode(line) as Map<String, Object?>);
        final outcome = await _graph.store.applyRemote(
          op,
          _now().millisecondsSinceEpoch,
        );
        switch (outcome) {
          case ApplyOutcome.applied:
            opsApplied++;
          case ApplyOutcome.deduped:
            opsDeduped++;
          case ApplyOutcome.quarantinedBadSig:
          case ApplyOutcome.quarantinedSkew:
            opsQuarantined++;
        }
      }

      return Ok(
        ImportSummary(
          opsApplied: opsApplied,
          opsDeduped: opsDeduped,
          opsQuarantined: opsQuarantined,
          blobsRestored: blobsRestored,
          blobsMismatched: blobsMismatched,
        ),
      );
    } catch (e, st) {
      return Failure(BackupImportFailure(e, st));
    }
  }
}
