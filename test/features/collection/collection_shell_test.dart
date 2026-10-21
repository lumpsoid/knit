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
import 'package:knit/features/collection/infra/sync_store_card_move_read_repository.dart';
import 'package:knit/features/collection/infra/sync_store_collection_read_repository.dart';
import 'package:knit/features/collection/infra/sync_store_collection_write_repository.dart';
import 'package:knit/features/collection/presentation/collection_action.dart';
import 'package:knit/features/collection/presentation/collection_effect.dart';
import 'package:knit/features/collection/presentation/collection_ui_effect.dart';
import 'package:knit/features/collection/presentation/collection_shell.dart';
import 'package:knit/features/card_links/infra/sync_store_card_links_write_repository.dart';
import 'package:knit/features/card_links/infra/sync_store_link_targets_read_repository.dart';
import 'package:knit/features/card_links/presentation/card_links_controller.dart';
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
  late List<CollectionUiEffect> uiEffects;
  late _FakeTimelineChannel timelineChannel;

  setUp(() async {
    uiEffects = [];
    timelineChannel = _FakeTimelineChannel();
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
      moveReadRepository: SyncStoreCardMoveReadRepository(graph: graph),
      attachmentReadRepository: SyncStoreAttachmentReadRepository(graph: graph),
      attachmentWriteRepository: attachmentWrite,
      imageCache: AttachmentImageCache(
        attachmentReadRepository: SyncStoreAttachmentReadRepository(
          graph: graph,
        ),
      ),
      shareRepository: _UnusedShare(),
      linkLauncher: _UnusedLinkLauncher(),
      collectionDetails: CollectionDetailsController(
        writeRepository: SyncStoreCollectionDetailsWriteRepository(
          graph: graph,
        ),
        attachmentWriteRepository: attachmentWrite,
      ),
      cardLinks: CardLinksController(
        readRepository: SyncStoreLinkTargetsReadRepository(graph: graph),
        writeRepository: SyncStoreCardLinksWriteRepository(
          graph: graph,
          ids: ids,
        ),
      ),
      effectEmitter: EffectEmitter<CollectionUiEffect>()..attach(uiEffects.add),
      timelineChannel: timelineChannel,
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

  test(
    'deleting selected cards deletes them all and reclaims attachments',
    () async {
      final colId = (await timelineWrite.createCollection('C')).getOrThrow();
      final attId = (await attachmentWrite.createFromPicked(
        png([4, 5, 6]),
      )).getOrThrow();
      final hash = await sha256Hex(Uint8List.fromList([4, 5, 6]));
      final image = (await write.addCard(
        collectionId: colId,
        kind: CardKind.image,
        position: 'a0',
        attachmentId: attId,
      )).getOrThrow();
      final text = (await write.addCard(
        collectionId: colId,
        kind: CardKind.text,
        position: 'a1',
        text: 'note',
      )).getOrThrow();
      final actions = <CollectionAction>[];

      await shell.run(
        DeleteCardsEffect([image, text], attachmentIds: [attId]),
        dispatch: actions.add,
      );

      expect(actions.single, isA<ReloadRequested>());
      expect((await store.get(EntityType.card, image))!.deleted, isTrue);
      expect((await store.get(EntityType.card, text))!.deleted, isTrue);
      expect((await store.get(EntityType.attachment, attId))!.deleted, isTrue);
      expect(await blobs.exists(hash), isFalse);
    },
  );

  group('move selected cards to another collection', () {
    test(
      'targets list every live collection; the tail is the last card',
      () async {
        final src = (await timelineWrite.createCollection('Src')).getOrThrow();
        final dst = (await timelineWrite.createCollection('Dst')).getOrThrow();
        await write.addCard(
          collectionId: dst,
          kind: CardKind.text,
          position: 'a3',
          text: 'last',
        );

        final actions = <CollectionAction>[];
        await shell.run(const LoadMoveTargetsEffect(), dispatch: actions.add);
        final loaded = actions.single as MoveTargetsLoaded;
        expect(
          loaded.targets.map((t) => t.collectionId),
          containsAll([src, dst]),
        );

        actions.clear();
        final target = MoveTarget(collectionId: dst, title: 'Dst');
        await shell.run(
          LoadMoveTargetTailEffect(target),
          dispatch: actions.add,
        );
        final tail = actions.single as MoveTargetTailLoaded;
        expect(tail.lastPosition, 'a3');
      },
    );

    test('moving writes the cards, refreshes, and reports the move', () async {
      final src = (await timelineWrite.createCollection('Src')).getOrThrow();
      final dst = (await timelineWrite.createCollection('Dst')).getOrThrow();
      final a = (await write.addCard(
        collectionId: src,
        kind: CardKind.text,
        position: 'a0',
        text: 'a',
      )).getOrThrow();
      final b = (await write.addCard(
        collectionId: src,
        kind: CardKind.text,
        position: 'a1',
        text: 'b',
      )).getOrThrow();

      final actions = <CollectionAction>[];
      await shell.run(
        MoveCardsEffect(
          target: MoveTarget(collectionId: dst, title: 'Dst'),
          positions: {a: 'a0', b: 'a1'},
        ),
        dispatch: actions.add,
      );

      expect((await store.feed(dst)).map((s) => s.id), [a, b]);
      expect(await store.feed(src), isEmpty);
      expect(actions.single, isA<ReloadRequested>());
      expect(timelineChannel.emits, 1);
      final moved = uiEffects.single as CollectionCardsMovedUiEffect;
      expect(moved.count, 2);
      expect(moved.targetCollectionId, dst);
      expect(moved.targetTitle, 'Dst');
    });

    test('a new target is created and delivered with no tail', () async {
      final actions = <CollectionAction>[];
      await shell.run(
        const CreateMoveTargetEffect('Fresh'),
        dispatch: actions.add,
      );
      final tail = actions.single as MoveTargetTailLoaded;
      expect(tail.target.title, 'Fresh');
      expect(tail.lastPosition, isNull);
      final created = await store.get(
        EntityType.collection,
        tail.target.collectionId,
      );
      expect(created?.content['title'], 'Fresh');
      expect(timelineChannel.emits, 1);
    });

    test('a failed move surfaces a message and resyncs', () async {
      final dst = (await timelineWrite.createCollection('Dst')).getOrThrow();
      final actions = <CollectionAction>[];
      await shell.run(
        MoveCardsEffect(
          target: MoveTarget(collectionId: dst, title: 'Dst'),
          positions: const {'missing': 'a0'},
        ),
        dispatch: actions.add,
      );
      expect(actions.single, isA<ReloadRequested>());
      expect(
        (uiEffects.single as CollectionShowMessageUiEffect).message,
        CollectionMessage.saveFailed,
      );
    });
  });

  group('quick input', () {
    test('a saved quick card asks the page to close, then resyncs', () async {
      final col = (await timelineWrite.createCollection('Inbox')).getOrThrow();
      final actions = <CollectionAction>[];
      await shell.run(
        AddCardEffect(
          collectionId: col,
          kind: CardKind.link,
          position: 'a0',
          text: 'https://x.y',
          closesQuickInput: true,
        ),
        dispatch: actions.add,
      );
      expect(uiEffects.single, isA<CollectionQuickInputSentUiEffect>());
      expect(actions.single, isA<ReloadRequested>());
    });

    test('an ordinary send leaves the page open', () async {
      final col = (await timelineWrite.createCollection('Inbox')).getOrThrow();
      await shell.run(
        AddCardEffect(
          collectionId: col,
          kind: CardKind.text,
          position: 'a0',
          text: 'hi',
        ),
        dispatch: (_) {},
      );
      expect(uiEffects, isEmpty);
    });
  });

  test(
    'settling writes the cards, refreshes, and reads back settled',
    () async {
      final col = (await timelineWrite.createCollection('Steps')).getOrThrow();
      final a = (await write.addCard(
        collectionId: col,
        kind: CardKind.text,
        position: 'a0',
        text: 'a',
      )).getOrThrow();

      final actions = <CollectionAction>[];
      await shell.run(
        SettleCardsEffect([a], settled: true),
        dispatch: actions.add,
      );

      expect(actions.single, isA<ReloadRequested>());
      expect(timelineChannel.emits, 1);
      final data = (await SyncStoreCollectionReadRepository(
        graph: graph,
      ).loadCollection(col)).getOrThrow();
      expect(data.cards.single.settled, isTrue);

      actions.clear();
      await shell.run(
        SettleCardsEffect([a], settled: false),
        dispatch: actions.add,
      );
      final after = (await SyncStoreCollectionReadRepository(
        graph: graph,
      ).loadCollection(col)).getOrThrow();
      expect(after.cards.single.settled, isFalse);
    },
  );

  test('emphasizing writes the cards and clears their settle', () async {
    final col = (await timelineWrite.createCollection('Steps')).getOrThrow();
    final a = (await write.addCard(
      collectionId: col,
      kind: CardKind.text,
      position: 'a0',
      text: 'a',
    )).getOrThrow();
    await shell.run(SettleCardsEffect([a], settled: true), dispatch: (_) {});

    final actions = <CollectionAction>[];
    await shell.run(
      EmphasizeCardsEffect([a], emphasized: true),
      dispatch: actions.add,
    );

    expect(actions.single, isA<ReloadRequested>());
    final data = (await SyncStoreCollectionReadRepository(
      graph: graph,
    ).loadCollection(col)).getOrThrow();
    expect(data.cards.single.emphasized, isTrue);
    expect(data.cards.single.settled, isFalse);
  });
}
