/// Extension → mime lookup for files that arrive without a declared media type
/// (the file picker, a share from another app). Unknown or missing extensions
/// fall back to [fallback], which stores the bytes as a generic file (§7.4.8).
class MimeTypes {
  const MimeTypes._();

  static const String fallback = 'application/octet-stream';

  static const Map<String, String> _byExtension = {
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
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
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

  /// The mime type for [name] judged by its extension, or [fallback].
  static String forFileName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot == -1) return fallback;
    final ext = name.substring(dot + 1).toLowerCase();
    return _byExtension[ext] ?? fallback;
  }
}
