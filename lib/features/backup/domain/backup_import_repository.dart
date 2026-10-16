import 'dart:typed_data';

import 'package:result_dart/result_dart.dart';
import 'package:knit/features/backup/domain/backup_failure.dart';
import 'package:knit/features/backup/domain/backup_models.dart';

/// Restores a backup bundle into the local store by replaying its signed ops
/// through the merge-core (re-verify + dedup + skew guard) and rehydrating the
/// content-addressed blobs.
abstract interface class BackupImportRepository {
  /// Decode [bytes] and decide how they restore onto this device.
  Future<Result<RestorePlan, BackupFailure>> plan(Uint8List bytes);

  /// Replay [bundle] onto the current identity ([RestoreKind.merge]).
  Future<Result<ImportSummary, BackupFailure>> merge(BackupBundle bundle);

  /// Unseal the bundle's keypair with [passphrase], erase this device, adopt
  /// the keypair, then replay [bundle] ([RestoreKind.replaceDevice]). A wrong
  /// passphrase fails before anything is erased.
  Future<Result<ImportSummary, BackupFailure>> replaceDevice(
    BackupBundle bundle,
    String passphrase,
  );
}
