import 'package:result_dart/result_dart.dart';
import 'package:knit/features/backup/domain/backup_failure.dart';
import 'package:knit/features/backup/domain/backup_models.dart';

/// Produces a full backup bundle from the local store — the signed `change_log`
/// (the durable truth, §8.9) plus the content-addressed attachment blobs. A
/// narrow, single-purpose port (business_logic.md §5): it only reads and packs.
abstract interface class BackupExportRepository {
  Future<Result<BackupArchive, BackupFailure>> exportAll();
}
