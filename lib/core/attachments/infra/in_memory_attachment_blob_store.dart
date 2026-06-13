import 'dart:typed_data';

import 'package:knit/core/attachments/domain/attachment_blob_store.dart';

/// In-memory [AttachmentBlobStore] for dev mode and tests — bytes held in a map
/// keyed by `content_hash`, no filesystem.
class InMemoryAttachmentBlobStore implements AttachmentBlobStore {
  final Map<String, Uint8List> _blobs = {};

  @override
  Future<void> put(String contentHash, Uint8List bytes) async =>
      _blobs[contentHash] = bytes;

  @override
  Future<Uint8List?> readBytes(String contentHash) async => _blobs[contentHash];

  @override
  Future<bool> exists(String contentHash) async =>
      _blobs.containsKey(contentHash);

  @override
  Future<void> delete(String contentHash) async => _blobs.remove(contentHash);
}
