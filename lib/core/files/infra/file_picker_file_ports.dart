import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:knit/core/files/domain/domain.dart';
import 'package:result_dart/result_dart.dart';

/// [FileSavePort] over `package:file_picker` — opens a save-file dialog and
/// writes the bytes to the chosen path. `saveFile` returns the path on success
/// or `null` when the user cancels.
class FilePickerFileSavePort implements FileSavePort {
  const FilePickerFileSavePort();

  @override
  Future<Result<bool, FileFailure>> save(OutgoingFile file) async {
    try {
      final path = await FilePicker.saveFile(
        fileName: file.fileName,
        bytes: file.bytes,
        type: FileType.custom,
        allowedExtensions: [file.extension],
      );
      return Ok(path != null);
    } catch (e, st) {
      return Failure(FileSaveFailure(e, st));
    }
  }
}

/// [FileSourcePort] over `package:file_picker`. Reads the picked file into
/// memory via [PlatformFile.readAsBytes], so it behaves the same whether the
/// platform returns a path or in-memory data. A cancel returns `null`.
class FilePickerFileSourcePort implements FileSourcePort {
  const FilePickerFileSourcePort();

  @override
  Future<Result<Uint8List?, FileFailure>> pick({
    List<String>? extensions,
  }) async {
    try {
      final result = await FilePicker.pickFiles(
        type: extensions == null ? FileType.any : FileType.custom,
        allowedExtensions: extensions,
      );
      if (result == null || result.files.isEmpty) {
        return const Ok<Uint8List?, FileFailure>(null);
      }
      return Ok(await result.files.first.readAsBytes());
    } catch (e, st) {
      return Failure(FileSourceFailure(e, st));
    }
  }
}
