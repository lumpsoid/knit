import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/core/attachments/attachments.dart';
import 'package:knit/core/ids/uuid_id_generator.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/infra/sync_store_collection_write_repository.dart';
import 'package:knit/features/timeline/infra/sync_store_timeline_write_repository.dart';
import 'package:knit/sync/sync.dart';

/// Drives [LegacyAttachmentSplitMigration] through its real [SyncStore]-backed
/// port over in-memory storage. A "legacy shared record" is reproduced directly
/// by pointing two cards at one attachment id (the pre-`83a99bc` shape); the
/// migration must give each its own record, all sharing one ref-counted blob.
void main() {
  const ids = UuidIdGenerator();
  late AppGraph graph;
  late SyncStore store;
  late InMemoryAttachmentBlobStore blobs;
  late SyncStoreTimelineWriteRepository timelineWrite;
  late SyncStoreCollectionWriteRepository write;
  late SyncStoreAttachmentWriteRepository attachmentWrite;
  late LegacyAttachmentSplitMigration migration;

  setUp(() async {
    graph = AppGraph();
    store = SyncStore.inMemory();
    await store.open();
    graph.bindStore(store);
    blobs = InMemoryAttachmentBlobStore();
    graph.bindBlobStore(blobs);
    timelineWrite = SyncStoreTimelineWriteRepository(graph: graph, ids: ids);
    write = SyncStoreCollectionWriteRepository(graph: graph, ids: ids);
    attachmentWrite =
        SyncStoreAttachmentWriteRepository(graph: graph, ids: ids);
    migration = LegacyAttachmentSplitMigration(
      SyncStoreLegacyAttachmentMigrationPort(graph: graph, ids: ids),
    );
  });

  PickedImage png(List<int> b) =>
      PickedImage(bytes: Uint8List.fromList(b), mime: 'image/png');

  Future<String> attachmentIdOf(String cardId) async =>
      (await store.get(EntityType.card, cardId))!.content['attachment_id']
          as String;

  Future<String?> contentHashOf(String attachmentId) async {
    final r = await store.get(EntityType.attachment, attachmentId);
    if (r == null || r.deleted) return null;
    return r.content[AttachmentSchema.colContentHash] as String?;
  }

  Future<int> liveAttachmentCount() async =>
      (await store.readAll(EntityType.attachment))
          .where((s) => !s.deleted)
          .length;

  // Two cards in [colId] that both point at one shared attachment record — the
  // pre-fix N:1 shape.
  Future<({String cardA, String cardB, String attId})> sharedRecord(
    String colId,
  ) async {
    final attId =
        (await attachmentWrite.createFromPicked(png([1, 2, 3]))).getOrThrow();
    final cardA = (await write.addCard(
      collectionId: colId,
      kind: CardKind.image,
      position: 'a0',
      attachmentId: attId,
    ))
        .getOrThrow();
    final cardB = (await write.addCard(
      collectionId: colId,
      kind: CardKind.image,
      position: 'a1',
      attachmentId: attId,
    ))
        .getOrThrow();
    return (cardA: cardA, cardB: cardB, attId: attId);
  }

  test('splits a record shared by two cards so each owns its own record',
      () async {
    final colId = (await timelineWrite.createCollection('C')).getOrThrow();
    final shared = await sharedRecord(colId);

    final repointed = await migration.run();
    expect(repointed, 1);

    final attA = await attachmentIdOf(shared.cardA);
    final attB = await attachmentIdOf(shared.cardB);

    // Each card now points at a distinct, live record.
    expect(attA, isNot(attB));
    expect(await contentHashOf(attA), isNotNull);
    expect(await contentHashOf(attB), isNotNull);
    // One card keeps the original record; the other got a fresh one.
    expect({attA, attB}, contains(shared.attId));
    // Both still describe the same bytes → one shared, ref-counted blob.
    expect(await contentHashOf(attA), await contentHashOf(attB));
    // The split adds exactly one record (the clone); no bytes are duplicated.
    expect(await liveAttachmentCount(), 2);
  });

  test('is idempotent — a second run repoints nothing', () async {
    final colId = (await timelineWrite.createCollection('C')).getOrThrow();
    await sharedRecord(colId);

    expect(await migration.run(), 1);
    final countAfterFirst = await liveAttachmentCount();

    expect(await migration.run(), 0);
    expect(await liveAttachmentCount(), countAfterFirst);
  });

  test('no-op when records are already uniquely owned (1:1)', () async {
    final colId = (await timelineWrite.createCollection('C')).getOrThrow();
    // Two cards, each its own record (the post-fix shape).
    final attA =
        (await attachmentWrite.createFromPicked(png([1, 2, 3]))).getOrThrow();
    final attB =
        (await attachmentWrite.createFromPicked(png([4, 5, 6]))).getOrThrow();
    await write.addCard(
      collectionId: colId,
      kind: CardKind.image,
      position: 'a0',
      attachmentId: attA,
    );
    await write.addCard(
      collectionId: colId,
      kind: CardKind.image,
      position: 'a1',
      attachmentId: attB,
    );

    expect(await migration.run(), 0);
    expect(await liveAttachmentCount(), 2);
  });

  test('leaves a record referenced by a single card untouched', () async {
    final colId = (await timelineWrite.createCollection('C')).getOrThrow();
    final attId =
        (await attachmentWrite.createFromPicked(png([1, 2, 3]))).getOrThrow();
    final cardId = (await write.addCard(
      collectionId: colId,
      kind: CardKind.image,
      position: 'a0',
      attachmentId: attId,
    ))
        .getOrThrow();

    expect(await migration.run(), 0);
    expect(await attachmentIdOf(cardId), attId);
    expect(await liveAttachmentCount(), 1);
  });

  test('skips a shared but missing/deleted attachment (broken reference)',
      () async {
    final colId = (await timelineWrite.createCollection('C')).getOrThrow();
    final shared = await sharedRecord(colId);
    // The shared record is gone, but both cards still reference its id.
    await store.delete(EntityType.attachment, shared.attId);

    expect(await migration.run(), 0);
    // Both cards still point at the same (now-broken) id — nothing was split.
    expect(await attachmentIdOf(shared.cardA), shared.attId);
    expect(await attachmentIdOf(shared.cardB), shared.attId);
  });

  test('splits a record shared by three cards into three records', () async {
    final colId = (await timelineWrite.createCollection('C')).getOrThrow();
    final attId =
        (await attachmentWrite.createFromPicked(png([7, 8, 9]))).getOrThrow();
    final cardIds = <String>[];
    for (var i = 0; i < 3; i++) {
      cardIds.add(
        (await write.addCard(
          collectionId: colId,
          kind: CardKind.image,
          position: 'a$i',
          attachmentId: attId,
        ))
            .getOrThrow(),
      );
    }

    expect(await migration.run(), 2);

    final atts = <String>{
      for (final id in cardIds) await attachmentIdOf(id),
    };
    expect(atts, hasLength(3), reason: 'each card owns a distinct record');
    expect(atts, contains(attId), reason: 'one card keeps the original');
    expect(await liveAttachmentCount(), 3);
  });
}
