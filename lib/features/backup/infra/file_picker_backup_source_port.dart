import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:result_dart/result_dart.dart';
import 'package:knit/features/backup/domain/backup_failure.dart';
import 'package:knit/features/backup/domain/backup_source_port.dart';

/// [BackupSourcePort] over `package:file_picker` — the one place the file-pick
/// dependency lives. Picks a single `.zip` and reads its bytes into memory via
/// [PlatformFile.readAsBytes], so it behaves the same whether the platform
/// returns a path or in-memory data. A cancel returns `null`, not a failure.
class FilePickerBackupSourcePort implements BackupSourcePort {
  const FilePickerBackupSourcePort();

  @override
  Future<Result<Uint8List?, BackupFailure>> pickArchive() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['zip'],
      );
      if (result == null || result.files.isEmpty) {
        return const Ok<Uint8List?, BackupFailure>(null);
      }
      return Ok(await result.files.first.readAsBytes());
    } catch (e, st) {
      return Failure(BackupSourceFailure(e, st));
    }
  }
}
