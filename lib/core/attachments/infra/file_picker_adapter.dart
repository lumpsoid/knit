import 'package:file_picker/file_picker.dart';
import 'package:knit/core/attachments/domain/file_picker_port.dart';
import 'package:knit/core/attachments/domain/picked_file.dart';

/// [FilePickerPort] over `package:file_picker`. Picks a single file with its
/// bytes loaded into memory (`withData: true`, so it works the same whether the
/// platform hands back a path or in-memory data), and derives a mime type from
/// its extension since the picker does not surface one. The bytes are handed on
/// to the hashing + blob-store path; the original [PickedFile.name] is preserved
/// on the stored `attachment` record (spec §7.4.8).
class FilePickerAdapter implements FilePickerPort {
  const FilePickerAdapter();

  static const Map<String, String> _mimeByExtension = {
    'pdf': 'application/pdf',
    'txt': 'text/plain',
    'md': 'text/markdown',
    'csv': 'text/csv',
    'json': 'application/json',
    'xml': 'application/xml',
    'zip': 'application/zip',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx':
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'mp3': 'audio/mpeg',
    'aac': 'audio/aac',
    'm4a': 'audio/mp4',
    'ogg': 'audio/ogg',
    'oga': 'audio/ogg',
    'opus': 'audio/opus',
    'wav': 'audio/wav',
    'flac': 'audio/flac',
    'mp4': 'video/mp4',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
  };

  @override
  Future<PickedFile?> pickFile() async {
    final result = await FilePicker.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;
    return PickedFile(bytes: bytes, mime: _mimeOf(file.name), name: file.name);
  }

  static String _mimeOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot == -1) return 'application/octet-stream';
    final ext = name.substring(dot + 1).toLowerCase();
    return _mimeByExtension[ext] ?? 'application/octet-stream';
  }
}
