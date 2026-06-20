import 'package:result_dart/result_dart.dart';
import 'package:knit/features/backup/domain/backup_failure.dart';
import 'package:knit/features/backup/domain/backup_models.dart';

/// Saves a finished [BackupArchive] to a user-chosen location (a save-file
/// dialog). The one place the file-save dependency lives. Returns `true` when
/// the bundle was saved, `false` when the user cancelled — a cancel is not a
/// failure.
abstract interface class BackupSavePort {
  Future<Result<bool, BackupFailure>> save(BackupArchive archive);
}
