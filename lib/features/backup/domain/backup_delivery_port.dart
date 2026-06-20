import 'package:result_dart/result_dart.dart';
import 'package:knit/features/backup/domain/backup_failure.dart';
import 'package:knit/features/backup/domain/backup_models.dart';

/// Hands a finished [BackupArchive] to the platform so the user can store or
/// send it (the OS share sheet). The one place the system-share dependency lives.
abstract interface class BackupDeliveryPort {
  Future<Result<void, BackupFailure>> share(BackupArchive archive);
}
