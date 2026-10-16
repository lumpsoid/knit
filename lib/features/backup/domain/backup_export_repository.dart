import 'package:result_dart/result_dart.dart';
import 'package:knit/features/backup/domain/backup_failure.dart';
import 'package:knit/features/backup/domain/backup_models.dart';

/// Builds a backup bundle of everything on this device: the signed log, the
/// attachment bytes, and the keypair sealed under [passphrase].
abstract interface class BackupExportRepository {
  Future<Result<BackupArchive, BackupFailure>> exportAll(String passphrase);
}
