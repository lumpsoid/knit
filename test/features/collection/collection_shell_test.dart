import 'dart:typed_data';

import 'package:effect_emitter/effect_emitter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/core/attachments/attachments.dart';
import 'package:knit/core/ids/uuid_id_generator.dart';
import 'package:knit/features/collection/domain/card_share_repository.dart';
import 'package:knit/features/collection/domain/collection_failure.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/domain/link_launcher.dart';
import 'package:knit/features/collection/infra/sync_store_collection_read_repository.dart';
import 'package:knit/features/collection/infra/sync_store_collection_write_repository.dart';
import 'package:knit/features/collection/presentation/collection_effect.dart';
import 'package:knit/features/collection/presentation/collection_ui_effect.dart';
import 'package:knit/features/collection/presentation/collection_shell.dart';
import 'package:knit/features/collection_details/infra/sync_store_collection_details_write_repository.dart';
import 'package:knit/features/collection_details/presentation/collection_details_controller.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';
import 'package:knit/features/timeline/infra/sync_store_timeline_write_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';

/// Drives the real [CollectionShell] over real in-memory storage for the
/// delete-then-GC path: deleting an image card must reclaim its uniquely-owned
/// attachment record + blob, but a legacy shared record (one record reused by
/// two cards) must survive while a sibling still references it. The ports the
/// delete path never touches are [UnimplementedError] fakes.
class _UnusedImagePicker implements ImagePickerPort {
  @override
  Future<PickedImage?> pickImage({
    ImagePickerSource source = ImagePickerSource.gallery,
  }) => throw UnimplementedError();
}

class _UnusedAudioRecorder implements AudioRecorderPort {
  @override
  Future<bool> start() => throw UnimplementedError();
  @override
  Future<void> pause() => throw UnimplementedError();
  @override
  Future<void> resume() => throw UnimplementedError();
  @override
  Future<PickedAudio?> stop() => throw UnimplementedError();
  @override
  Future<void> cancel() => throw UnimplementedError();
}

class _UnusedFilePicker implements FilePickerPort {
  @override
  Future<PickedFile?> pickFile() => throw UnimplementedError();
}

class _UnusedShare implements CardShareRepository {
  @override
  Future<Result<void, CollectionFailure>> share(ShareableCard card) =>
      throw UnimplementedError();
}

class _UnusedLinkLauncher implements LinkLauncher {
  @override
  Future<Result<void, CollectionFailure>> open(String url) =>
      throw UnimplementedError();
}

class _FakeTimelineChannel implements TimelineChannelEmitter {
  int emits = 0;
  @override
  void emit(TimelineChannelEvent event) => emits++;
}

void main() {
  const ids = UuidIdGenerator();
  late AppGraph graph;
  late SyncStore store;
  late InMemoryAttachmentBlobStore blobs;
  late SyncStoreTimelineWriteRepository timelineWrite;
  late SyncStoreCollectionWriteRepository write;
  late SyncStoreAttachmentWriteRepository attachmentWrite;
  late CollectionShell shell;

  setUp(() async {
    graph = AppGraph();
    store = SyncStore.inMemory();
    await store.open();
    graph.bindStore(store);
    blobs = InMemoryAttachmentBlobStore();
    graph.bindBlobStore(blobs);
    timelineWrite = SyncStoreTimelineWriteRepository(graph: graph, ids: ids);
    write = SyncStoreCollectionWriteRepository(graph: graph, ids: ids);
    attachmentWrite = SyncStoreAttachmentWriteRepository(
      graph: graph,
      ids: ids,
    );
    shell = CollectionShell(
      readRepository: SyncStoreCollectionReadRepository(graph: graph),
      writeRepository: write,
      attachmentReadRepository: SyncStoreAttachmentReadRepository(graph: graph),
      attachmentWriteRepository: attachmentWrite,
      imageCache: AttachmentImageCache(
        attachmentReadRepository: SyncStoreAttachmentReadRepository(
          graph: graph,
        ),
      ),
      imagePicker: _UnusedImagePicker(),
      audioRecorder: _UnusedAudioRecorder(),
      filePicker: _UnusedFilePicker(),
      shareRepository: _UnusedShare(),
      linkLauncher: _UnusedLinkLauncher(),
      collectionDetails: CollectionDetailsController(
        writeRepository: SyncStoreCollectionDetailsWriteRepository(
          graph: graph,
        ),
        attachmentWriteRepository: attachmentWrite,
      ),
      effectEmitter: EffectEmitter<CollectionUiEffect>(),
      timelineChannel: _FakeTimelineChannel(),
      logger: Logger('test.collection'),
    );
  });

  PickedImage png(List<int> b) =>
      PickedImage(bytes: Uint8List.fromList(b), mime: 'image/png');

  test(
    'deleting a card reclaims its uniquely-owned attachment record + blob',
    () async {
      final colId = (await timelineWrite.createCollection('C')).getOrThrow();
      final attId = (await attachmentWrite.createFromPicked(
        png([1, 2, 3]),
      )).getOrThrow();
      final hash = await sha256Hex(Uint8List.fromList([1, 2, 3]));
      final cardId = (await write.addCard(
        collectionId: colId,
        kind: CardKind.image,
        position: 'a0',
        attachmentId: attId,
      )).getOrThrow();

      await shell.run(
        DeleteCardEffect(cardId, attachmentId: attId),
        dispatch: (_) {},
      );

      expect((await store.get(EntityType.attachment, attId))!.deleted, isTrue);
      expect(await blobs.exists(hash), isFalse);
    },
  );

  test(
    'deleting a card sharing a legacy attachment record keeps the sibling',
    () async {
      final colId = (await timelineWrite.createCollection('C')).getOrThrow();
      final attId = (await attachmentWrite.createFromPicked(
        png([1, 2, 3]),
      )).getOrThrow();
      final hash = await sha256Hex(Uint8List.fromList([1, 2, 3]));
      final cardA = (await write.addCard(
        collectionId: colId,
        kind: CardKind.image,
        position: 'a0',
        attachmentId: attId,
      )).getOrThrow();
      // Sibling card B reuses the SAME record (simulates a pre-fix shared record).
      await write.addCard(
        collectionId: colId,
        kind: CardKind.image,
        position: 'a1',
        attachmentId: attId,
      );

      await shell.run(
        DeleteCardEffect(cardA, attachmentId: attId),
        dispatch: (_) {},
      );

      // The guard skips GC because card B still references it → no orphan.
      expect((await store.get(EntityType.attachment, attId))!.deleted, isFalse);
      expect(await blobs.exists(hash), isTrue);
    },
  );

  test('deleting a text card touches no attachment', () async {
    final colId = (await timelineWrite.createCollection('C')).getOrThrow();
    final cardId = (await write.addCard(
      collectionId: colId,
      kind: CardKind.text,
      position: 'a0',
      text: 'note',
    )).getOrThrow();

    await shell.run(DeleteCardEffect(cardId), dispatch: (_) {});
    expect((await store.get(EntityType.card, cardId))!.deleted, isTrue);
  });
}
