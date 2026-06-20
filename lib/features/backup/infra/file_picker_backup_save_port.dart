import 'package:file_picker/file_picker.dart';
import 'package:result_dart/result_dart.dart';
import 'package:knit/features/backup/domain/backup_failure.dart';
import 'package:knit/features/backup/domain/backup_models.dart';
import 'package:knit/features/backup/domain/backup_save_port.dart';

/// [BackupSavePort] over `package:file_picker` — opens a save-file dialog and
/// writes the bundle bytes to the chosen path. `saveFile` returns the path on
/// success or `null` when the user cancels.
class FilePickerBackupSavePort implements BackupSavePort {
  const FilePickerBackupSavePort();

  @override
  Future<Result<bool, BackupFailure>> save(BackupArchive archive) async {
    try {
      final path = await FilePicker.saveFile(
        fileName: archive.fileName,
        bytes: archive.bytes,
        type: FileType.custom,
        allowedExtensions: const ['zip'],
      );
      return Ok(path != null);
    } catch (e, st) {
      return Failure(BackupSaveFailure(e, st));
    }
  }
}
