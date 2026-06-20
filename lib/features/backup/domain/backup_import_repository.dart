import 'dart:typed_data';

import 'package:result_dart/result_dart.dart';
import 'package:knit/features/backup/domain/backup_failure.dart';
import 'package:knit/features/backup/domain/backup_models.dart';

/// Restores a backup bundle into the local store by replaying its signed ops
/// through the merge-core (re-verify + dedup + skew guard) and rehydrating the
/// content-addressed blobs. A narrow, single-purpose port (business_logic.md §5).
abstract interface class BackupImportRepository {
  Future<Result<ImportSummary, BackupFailure>> importArchive(Uint8List bytes);
}
