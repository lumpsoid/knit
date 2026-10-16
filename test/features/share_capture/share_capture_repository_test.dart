import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/core/attachments/attachments.dart';
import 'package:knit/core/ids/uuid_id_generator.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/infra/sync_store_collection_read_repository.dart';
import 'package:knit/features/share_capture/domain/share_capture_planner.dart';
import 'package:knit/features/share_capture/domain/shared_item.dart';
import 'package:knit/features/share_capture/infra/sync_store_share_capture_read_repository.dart';
import 'package:knit/features/share_capture/infra/sync_store_share_capture_write_repository.dart';
import 'package:knit/sync/sync.dart';

/// Saves a share through the real signed write path over an in-memory
/// [SyncStore], then reads it back through the Collection's read repository.
void main() {
  late AppGraph graph;
  late SyncStoreShareCaptureReadRepository read;
  late SyncStoreShareCaptureWriteRepository write;
  late SyncStoreCollectionReadRepository collectionRead;
  late Map<String, Uint8List> files;

  setUp(() async {
    final store = SyncStore.inMemory();
    await store.open();
    graph = AppGraph()
      ..bindStore(store)
      ..bindBlobStore(InMemoryAttachmentBlobStore());
    const ids = UuidIdGenerator();
    files = {};
    read = SyncStoreShareCaptureReadRepository(graph: graph);
    write = SyncStoreShareCaptureWriteRepository(
      graph: graph,
      ids: ids,
      attachments: SyncStoreAttachmentWriteRepository(graph: graph, ids: ids),
      readBytes: (path) async => files[path] ?? (throw StateError(path)),
    );
    collectionRead = SyncStoreCollectionReadRepository(graph: graph);
  });

  test('a new collection shows up as a target', () async {
    final id = (await write.createCollection('Inbox')).getOrThrow();
    final targets = (await read.loadTargets()).getOrThrow();
    expect(targets.single.collectionId, id);
    expect(targets.single.title, 'Inbox');
    expect((await read.lastCardPosition(id)).getOrThrow(), isNull);
  });

  test('text, link, image and file cards are saved in order', () async {
    final id = (await write.createCollection('Inbox')).getOrThrow();
    files['/c/photo.jpg'] = Uint8List.fromList([1, 2, 3]);
    files['/c/doc.pdf'] = Uint8List.fromList([4, 5]);
    final cards = const ShareCapturePlanner().plan([
      const SharedText('a note'),
      const SharedText('https://example.com'),
      const SharedFile(
        path: '/c/photo.jpg',
        mime: 'image/jpeg',
        name: 'photo.jpg',
      ),
      const SharedFile(
        path: '/c/doc.pdf',
        mime: 'application/pdf',
        name: 'doc.pdf',
      ),
    ]);

    expect((await write.saveCards(id, cards)).getOrThrow(), 4);

    final feed = (await collectionRead.loadCollection(id)).getOrThrow().cards;
    expect(feed.map((c) => c.kind), [
      CardKind.text,
      CardKind.link,
      CardKind.image,
      CardKind.file,
    ]);
    expect(feed[0].text, 'a note');
    expect(feed[1].text, 'https://example.com');
    expect(feed[2].attachmentId, isNotNull);
    expect(feed[3].fileName, 'doc.pdf');
    expect(feed[3].fileSize, 2);

    final bytes = (await SyncStoreAttachmentReadRepository(
      graph: graph,
    ).bytesOf(feed[2].attachmentId!)).getOrThrow();
    expect(bytes.bytes, [1, 2, 3]);
    expect(bytes.mime, 'image/jpeg');

    expect((await read.lastCardPosition(id)).getOrThrow(), feed.last.position);
  });

  test('an unreadable file fails and keeps the cards before it', () async {
    final id = (await write.createCollection('Inbox')).getOrThrow();
    final cards = const ShareCapturePlanner().plan([
      const SharedText('kept'),
      const SharedFile(path: '/gone.pdf', mime: 'application/pdf', name: 'g'),
    ]);

    expect((await write.saveCards(id, cards)).isFailure, isTrue);
    final feed = (await collectionRead.loadCollection(id)).getOrThrow().cards;
    expect(feed.map((c) => c.text), ['kept']);
  });
}
