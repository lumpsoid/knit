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

  setUp(() async {
    graph = AppGraph();
    store = SyncStore.inMemory();
    await store.open();
    graph.bindStore(store);
    blobs = InMemoryAttachmentBlobStore();
    graph.bindBlobStore(blobs);
    write = SyncStoreAttachmentWriteRepository(graph: graph, ids: ids);
  });

  PickedImage png(List<int> b) =>
      PickedImage(bytes: Uint8List.fromList(b), mime: 'image/png');

  Future<List<Snapshot>> liveAttachments() async =>
      (await store.readAll(EntityType.attachment))
          .where((s) => !s.deleted)
          .toList();

  test('create writes the signed §7.4.8 metadata + the blob, no local_path',
      () async {
    final id = (await write.createFromPicked(png([1, 2, 3]))).getOrThrow();
    final snap = (await store.get(EntityType.attachment, id))!;
    final hash = await sha256Hex([1, 2, 3]);

    expect(snap.content[AttachmentSchema.colKind], 'image');
    expect(snap.content[AttachmentSchema.colMime], 'image/png');
    expect(snap.content[AttachmentSchema.colContentHash], hash);
    expect(snap.content[AttachmentSchema.colSize], 3);
    expect(snap.content[AttachmentSchema.colLocalPath], isNull);
    expect(snap.sig, isNotEmpty); // it is a signed record
    expect(await blobs.exists(hash), isTrue);
  });

  test('identical bytes dedupe to one record + one blob', () async {
    final a = (await write.createFromPicked(png([9, 9, 9]))).getOrThrow();
    final b = (await write.createFromPicked(png([9, 9, 9]))).getOrThrow();
    expect(a, b);
    expect((await liveAttachments()).length, 1);
  });

  test('different bytes create distinct records', () async {
    final a = (await write.createFromPicked(png([1]))).getOrThrow();
    final b = (await write.createFromPicked(png([2]))).getOrThrow();
    expect(a, isNot(b));
    expect((await liveAttachments()).length, 2);
  });

  test('delete soft-deletes the record and GCs the unshared blob', () async {
    final id = (await write.createFromPicked(png([5, 5]))).getOrThrow();
    final hash = (await store.get(EntityType.attachment, id))!
        .content[AttachmentSchema.colContentHash] as String;

    final deleted = (await write.delete(id)).getOrThrow();
    expect(deleted, id);
    expect((await store.get(EntityType.attachment, id))!.deleted, isTrue);
    expect(await blobs.exists(hash), isFalse);
  });

  test('delete keeps the blob while another live record shares the hash',
      () async {
    final id1 = (await write.createFromPicked(png([7, 7]))).getOrThrow();
    final hash = (await store.get(EntityType.attachment, id1))!
        .content[AttachmentSchema.colContentHash] as String;

    // A second record sharing the hash (as if it arrived via sync, bypassing
    // the create-time dedup) — the blob must survive deleting the first.
    final id2 = ids.newId();
    await store.create(EntityType.attachment, id2, {
      AttachmentSchema.colKind: 'image',
      AttachmentSchema.colMime: 'image/png',
      AttachmentSchema.colContentHash: hash,
      AttachmentSchema.colSize: 2,
    });

    await write.delete(id1);
    expect(await blobs.exists(hash), isTrue);
  });

  test('delete of an unknown id fails with AttachmentNotFound', () async {
    final result = await write.delete('does-not-exist');
    expect(result.isFailure, isTrue);
    expect(result.error, isA<AttachmentNotFound>());
  });
}
