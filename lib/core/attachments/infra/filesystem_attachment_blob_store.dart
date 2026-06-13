import 'dart:io';
import 'dart:typed_data';

import 'package:knit/core/attachments/domain/attachment_blob_store.dart';

/// Filesystem [AttachmentBlobStore] — the running-app impl. Bytes live on disk
/// under [baseDir], one file per `content_hash` (spec §6.4/§7.4.8). The hash is
/// the filename, so the path is fully derived from `content_hash` and nothing
/// device-local needs to be signed or persisted in the projection.
class FilesystemAttachmentBlobStore implements AttachmentBlobStore {
  FilesystemAttachmentBlobStore({required this.baseDir});

  /// Directory that holds the blob files (created lazily on first write).
  final String baseDir;

  File _fileFor(String contentHash) => File('$baseDir/$contentHash');

  @override
  Future<void> put(String contentHash, Uint8List bytes) async {
    final file = _fileFor(contentHash);
    if (await file.exists()) return; // content-addressed → already identical
    await Directory(baseDir).create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<Uint8List?> readBytes(String contentHash) async {
    final file = _fileFor(contentHash);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<bool> exists(String contentHash) => _fileFor(contentHash).exists();

  @override
  Future<void> delete(String contentHash) async {
    final file = _fileFor(contentHash);
    if (await file.exists()) await file.delete();
  }
}
