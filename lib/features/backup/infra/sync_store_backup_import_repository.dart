import 'dart:convert';
import 'dart:typed_data';

import 'package:result_dart/result_dart.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/app/device_eraser.dart';
import 'package:knit/core/attachments/attachments.dart';
import 'package:knit/features/backup/domain/backup_failure.dart';
import 'package:knit/features/backup/domain/backup_import_repository.dart';
import 'package:knit/features/backup/domain/backup_models.dart';
import 'package:knit/features/backup/domain/identity_key_cipher.dart';
import 'package:knit/features/backup/domain/restore_policy.dart';
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
/// A bundle from another identity replaces the device: the keypair is unsealed
/// first (a wrong passphrase stops here, nothing erased), then the device is
/// erased, the keypair adopted, and the ops replayed.
///
/// Note (§6.6): `applyRemote` records every op as `origin: remote, acked: true`,
/// so after restoring your own backup the pending-sync count reads zero — correct
/// for a restore (typically onto a fresh device).
class SyncStoreBackupImportRepository implements BackupImportRepository {
  SyncStoreBackupImportRepository({
    required AppGraph graph,
    required IdentityKeyCipher cipher,
    BackupArchiveCodec codec = const BackupArchiveCodec(),
    RestorePolicy policy = const RestorePolicy(),
    DateTime Function() now = DateTime.now,
  }) : _graph = graph,
       _eraser = DeviceEraser(graph: graph),
       _cipher = cipher,
       _codec = codec,
       _policy = policy,
       _now = now;

  final AppGraph _graph;
  final DeviceEraser _eraser;
  final IdentityKeyCipher _cipher;
  final BackupArchiveCodec _codec;
  final RestorePolicy _policy;
  final DateTime Function() _now;

  @override
  Future<Result<RestorePlan, BackupFailure>> plan(Uint8List bytes) async {
    final BackupBundle bundle;
    try {
      bundle = _codec.decode(bytes).toBundle();
    } on FormatException catch (e, st) {
      return Failure(BackupCorruptArchiveFailure(e, st));
    }
    try {
      final store = _graph.store;
      final deviceAuthor = await store.hasIdentity()
          ? await store.authorPubkey()
          : null;
      return Ok(
        RestorePlan(
          bundle: bundle,
          kind: _policy.decide(deviceAuthor: deviceAuthor, bundle: bundle),
        ),
      );
    } catch (e, st) {
      return Failure(BackupImportFailure(e, st));
    }
  }

  @override
  Future<Result<ImportSummary, BackupFailure>> merge(
    BackupBundle bundle,
  ) async {
    try {
      return Ok(await _replay(bundle));
    } catch (e, st) {
      return Failure(BackupImportFailure(e, st));
    }
  }

  @override
  Future<Result<ImportSummary, BackupFailure>> replaceDevice(
    BackupBundle bundle,
    String passphrase,
  ) async {
    final sealed = bundle.identity;
    if (sealed == null) {
      return Failure(
        BackupMissingIdentityFailure('bundle ${bundle.author} has no keypair'),
      );
    }
    final opened = await _cipher.open(sealed, passphrase);
    final Keypair keypair;
    switch (opened) {
      case Ok(:final value):
        keypair = value;
      case Failure(:final error):
        return Failure(error);
    }

    try {
      await _eraser.resetDevice();
      await _graph.store.adoptIdentity(keypair);
      return Ok(await _replay(bundle));
    } catch (e, st) {
      return Failure(BackupImportFailure(e, st));
    }
  }

  Future<ImportSummary> _replay(BackupBundle bundle) async {
    // Blobs first so an attachment op's bytes are present once it applies.
    var blobsRestored = 0;
    var blobsMismatched = 0;
    for (final entry in bundle.blobs.entries) {
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
    for (final line in bundle.opLines) {
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

    return ImportSummary(
      opsApplied: opsApplied,
      opsDeduped: opsDeduped,
      opsQuarantined: opsQuarantined,
      blobsRestored: blobsRestored,
      blobsMismatched: blobsMismatched,
    );
  }
}
