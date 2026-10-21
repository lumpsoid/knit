import 'package:result_dart/result_dart.dart';
import 'package:knit/features/backup/domain/backup_failure.dart';
import 'package:knit/core/files/domain/outgoing_file.dart';

/// Builds a backup bundle of everything on this device: the signed log, the
/// attachment bytes, and the keypair sealed under [passphrase], as a `.zip`
/// named `knit-backup-<author8>-<ms>.zip`.
abstract interface class BackupExportRepository {
  Future<Result<OutgoingFile, BackupFailure>> exportAll(String passphrase);
}
