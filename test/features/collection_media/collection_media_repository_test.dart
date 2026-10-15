import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/core/attachments/domain/picked_file.dart';
import 'package:knit/core/attachments/domain/picked_image.dart';
import 'package:knit/core/attachments/infra/in_memory_attachment_blob_store.dart';
import 'package:knit/core/attachments/infra/sync_store_attachment_write_repository.dart';
import 'package:knit/core/ids/uuid_id_generator.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/infra/sync_store_collection_write_repository.dart';
import 'package:knit/features/collection_media/infra/sync_store_collection_media_read_repository.dart';
import 'package:knit/features/timeline/infra/sync_store_timeline_write_repository.dart';
import 'package:knit/sync/sync.dart';

/// The media read over a real in-memory [SyncStore]: only media cards of the
/// target collection come back, with file metadata resolved and deleted cards
/// dropped.
void main() {
  late SyncStoreTimelineWriteRepository timelineWrite;
  late SyncStoreCollectionWriteRepository cards;
  late SyncStoreAttachmentWriteRepository attachments;
  late SyncStoreCollectionMediaReadRepository read;

  setUp(() async {
    final graph = AppGraph();
    final store = SyncStore.inMemory();
    await store.open();
    graph.bindStore(store);
    graph.bindBlobStore(InMemoryAttachmentBlobStore());
    const ids = UuidIdGenerator();
    timelineWrite = SyncStoreTimelineWriteRepository(graph: graph, ids: ids);
    cards = SyncStoreCollectionWriteRepository(graph: graph, ids: ids);
    attachments = SyncStoreAttachmentWriteRepository(graph: graph, ids: ids);
    read = SyncStoreCollectionMediaReadRepository(graph: graph);
  });

  Future<String> addCard(
    String collectionId,
    CardKind kind,
    String position, {
    String? text,
    String? attachmentId,
  }) async => (await cards.addCard(
    collectionId: collectionId,
    kind: kind,
    position: position,
    text: text,
    attachmentId: attachmentId,
  )).getOrThrow();

  test('returns only media cards, with file name + size resolved', () async {
    final colId = (await timelineWrite.createCollection('Trip')).getOrThrow();
    final other = (await timelineWrite.createCollection('Other')).getOrThrow();

    final photoAtt = (await attachments.createFromPicked(
      PickedImage(bytes: Uint8List.fromList([1, 2]), mime: 'image/png'),
    )).getOrThrow();
    final fileAtt = (await attachments.createFromFile(
      PickedFile(
        bytes: Uint8List.fromList([7, 7, 7]),
        mime: 'application/pdf',
        name: 'ticket.pdf',
      ),
    )).getOrThrow();

    await addCard(colId, CardKind.text, 'a0', text: 'just a note');
    final photo = await addCard(
      colId,
      CardKind.image,
      'a1',
      attachmentId: photoAtt,
    );
    final file = await addCard(
      colId,
      CardKind.file,
      'a2',
      attachmentId: fileAtt,
    );
    final link = await addCard(colId, CardKind.link, 'a3', text: 'x.io');
    await addCard(colId, CardKind.link, 'a4', text: ' ');
    final gone = await addCard(colId, CardKind.link, 'a5', text: 'y.io');
    await cards.deleteCard(gone);
    await addCard(other, CardKind.link, 'a0', text: 'elsewhere.io');

    final media = (await read.loadMedia(colId)).getOrThrow();

    expect(media.items.map((i) => i.cardId).toSet(), {photo, file, link});
    expect(media.counts.photos, 1);
    expect(media.counts.files, 1);
    expect(media.counts.links, 1);
    final fileItem = media.byCardId(file)!;
    expect(fileItem.fileName, 'ticket.pdf');
    expect(fileItem.fileSize, 3);
    expect(media.byCardId(photo)!.attachmentId, photoAtt);
  });

  test('an empty collection has no media', () async {
    final colId = (await timelineWrite.createCollection('Empty')).getOrThrow();
    expect((await read.loadMedia(colId)).getOrThrow().isEmpty, isTrue);
  });
}
