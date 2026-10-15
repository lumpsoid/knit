import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/attachments/attachments.dart';

/// Contract test for [AttachmentBlobStore], run identically over both impls
/// (storage convention): the in-memory map and the on-disk filesystem store.
void main() {
  Future<AttachmentBlobStore> inMemory() async => InMemoryAttachmentBlobStore();

  Future<AttachmentBlobStore> filesystem() async {
    final dir = Directory.systemTemp.createTempSync('knit_blob_test');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    return FilesystemAttachmentBlobStore(baseDir: dir.path);
  }

  final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
  const hash = 'abc123';

  for (final (name, open) in <(String, Future<AttachmentBlobStore> Function())>[
    ('InMemoryAttachmentBlobStore', inMemory),
    ('FilesystemAttachmentBlobStore', filesystem),
  ]) {
    group(name, () {
      late AttachmentBlobStore store;
      setUp(() async => store = await open());

      test('readBytes is null and exists is false before any put', () async {
        expect(await store.readBytes(hash), isNull);
        expect(await store.exists(hash), isFalse);
      });

      test('put then readBytes round-trips the bytes', () async {
        await store.put(hash, bytes);
        expect(await store.readBytes(hash), bytes);
        expect(await store.exists(hash), isTrue);
      });

      test('put is idempotent for the same hash', () async {
        await store.put(hash, bytes);
        await store.put(hash, bytes);
        expect(await store.readBytes(hash), bytes);
      });

      test('delete removes the blob', () async {
        await store.put(hash, bytes);
        await store.delete(hash);
        expect(await store.readBytes(hash), isNull);
        expect(await store.exists(hash), isFalse);
      });

      test('delete of an absent hash is a no-op', () async {
        await store.delete(hash); // must not throw
        expect(await store.exists(hash), isFalse);
      });
    });
  }
}
