import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:knit/core/attachments/domain/file_picker_port.dart';
import 'package:knit/core/attachments/domain/mime_types.dart';
import 'package:knit/core/attachments/domain/picked_file.dart';

/// [FilePickerPort] over `package:file_picker`. Picks a single file and reads
/// its bytes with `PlatformFile.readAsBytes` (the same whether the platform
/// hands back a path, a stream or in-memory data), and derives a mime type from
/// its extension since the picker does not surface one. The bytes are handed on
/// to the hashing + blob-store path; the original [PickedFile.name] is preserved
/// on the stored `attachment` record (spec §7.4.8).
class FilePickerAdapter implements FilePickerPort {
  const FilePickerAdapter();

  @override
  Future<PickedFile?> pickFile() async {
    final result = await FilePicker.pickFiles();
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } on StateError {
      return null; // the platform handed back neither data nor a path.
    }
    return PickedFile(
      bytes: bytes,
      mime: MimeTypes.forFileName(file.name),
      name: file.name,
    );
  }
}
