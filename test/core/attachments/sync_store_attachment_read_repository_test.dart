import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/core/attachments/attachments.dart';
import 'package:knit/core/ids/uuid_id_generator.dart';
import 'package:knit/sync/sync.dart';

void main() {
  const ids = UuidIdGenerator();

  late AppGraph graph;
  late SyncStore store;
  late InMemoryAttachmentBlobStore blobs;
  late SyncStoreAttachmentWriteRepository write;
  late SyncStoreAttachmentReadRepository read;

  setUp(() async {
    graph = AppGraph();
    store = SyncStore.inMemory();
    await store.open();
    graph.bindStore(store);
    blobs = InMemoryAttachmentBlobStore();
    graph.bindBlobStore(blobs);
    write = SyncStoreAttachmentWriteRepository(graph: graph, ids: ids);
    read = SyncStoreAttachmentReadRepository(graph: graph);
  });

  PickedImage png(List<int> b) =>
      PickedImage(bytes: Uint8List.fromList(b), mime: 'image/png');

  test('bytesOf round-trips the stored bytes + mime', () async {
    final id = (await write.createFromPicked(png([4, 5, 6]))).getOrThrow();
    final out = (await read.bytesOf(id)).getOrThrow();
    expect(out.bytes, Uint8List.fromList([4, 5, 6]));
    expect(out.mime, 'image/png');
  });

  test('unknown id fails with AttachmentNotFound', () async {
    final result = await read.bytesOf('does-not-exist');
    expect(result.isFailure, isTrue);
    expect(result.error, isA<AttachmentNotFound>());
  });

  test('a deleted record fails with AttachmentNotFound', () async {
    final id = (await write.createFromPicked(png([1, 1]))).getOrThrow();
    await write.delete(id);
    final result = await read.bytesOf(id);
    expect(result.isFailure, isTrue);
    expect(result.error, isA<AttachmentNotFound>());
  });

  test(
    'sibling card still reads its bytes after a reused photo is deleted',
    () async {
      // Two cards capture the same photo → distinct records, one shared blob.
      final a = (await write.createFromPicked(png([8, 8, 8]))).getOrThrow();
      final b = (await write.createFromPicked(png([8, 8, 8]))).getOrThrow();
      await write.delete(a);

      // The layer the UI consumes still resolves the sibling's bytes — no orphan.
      final out = (await read.bytesOf(b)).getOrThrow();
      expect(out.bytes, Uint8List.fromList([8, 8, 8]));
      expect(out.mime, 'image/png');
    },
  );

  test(
    'record present but blob gone fails with AttachmentBytesMissing',
    () async {
      final id = (await write.createFromPicked(png([2, 2, 2]))).getOrThrow();
      final hash =
          (await store.get(
                EntityType.attachment,
                id,
              ))!.content[AttachmentSchema.colContentHash]
              as String;
      await blobs.delete(hash); // drop bytes, keep the metadata record

      final result = await read.bytesOf(id);
      expect(result.isFailure, isTrue);
      expect(result.error, isA<AttachmentBytesMissing>());
    },
  );
}
