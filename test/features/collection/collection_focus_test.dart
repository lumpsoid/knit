import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/core/attachments/attachments.dart';
import 'package:knit/core/ids/uuid_id_generator.dart';
import 'package:knit/core/ordering/fractional_index.dart';
import 'package:knit/features/collection/domain/card_share_repository.dart';
import 'package:knit/features/collection/domain/collection_failure.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/domain/link_launcher.dart';
import 'package:knit/features/collection/infra/sync_store_card_move_read_repository.dart';
import 'package:knit/features/collection/infra/sync_store_collection_read_repository.dart';
import 'package:knit/features/collection/infra/sync_store_collection_write_repository.dart';
import 'package:knit/features/audio_playback/presentation/audio_playback_controller.dart';
import 'package:knit/features/collection/presentation/collection_controller.dart';
import 'package:knit/features/collection/presentation/collection_page.dart';
import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/collection/presentation/collection_scope.dart';
import 'package:knit/features/collection/presentation/widgets/title_morph.dart';
import 'package:knit/features/card_links/infra/sync_store_card_links_write_repository.dart';
import 'package:knit/features/card_links/infra/sync_store_link_targets_read_repository.dart';
import 'package:knit/features/card_links/presentation/card_links_controller.dart';
import 'package:knit/features/collection_details/infra/sync_store_collection_details_write_repository.dart';
import 'package:knit/features/collection_details/presentation/collection_details_controller.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';
import 'package:knit/features/timeline/infra/sync_store_timeline_write_repository.dart';
import 'package:knit/l10n/app_localizations.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// Opening a collection with a focus card (a search hit) must scroll that card
/// into view, even when it sits far above the newest card the feed starts at.
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
  Future<void> cancel() async {}
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

class _NoopTimelineChannel implements TimelineChannelEmitter {
  @override
  void emit(TimelineChannelEvent event) {}
}

class _SilentPlayer implements AudioPlayerPort {
  @override
  Stream<PlaybackProgress> get progress => const Stream.empty();
  @override
  Stream<PlaybackPhase> get phases => const Stream.empty();
  @override
  Future<void> play(Uint8List bytes, {required String mime}) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  const cardCount = 60;
  late List<String> cardIds;
  late InMemoryCollectionRouteArgsStore routeArgs;
  late AppGraph graph;

  Future<void> seed(WidgetTester tester) async {
    graph = AppGraph();
    const ids = UuidIdGenerator();
    await tester.runAsync(() async {
      final store = SyncStore.inMemory();
      await store.open();
      graph.bindStore(store);
      final colId = (await SyncStoreTimelineWriteRepository(
        graph: graph,
        ids: ids,
      ).createCollection('Long')).getOrThrow();
      final write = SyncStoreCollectionWriteRepository(graph: graph, ids: ids);
      cardIds = [];
      var position = FractionalIndex.first();
      for (var i = 0; i < cardCount; i++) {
        cardIds.add(
          (await write.addCard(
            collectionId: colId,
            kind: CardKind.text,
            position: position,
            text: 'card $i',
          )).getOrThrow(),
        );
        position = FractionalIndex.keyAfter(position);
      }
      routeArgs = InMemoryCollectionRouteArgsStore();
      routeArgs.open(colId, focusCardId: cardIds[2]);
    });

    CollectionScope.setRouteArgs(routeArgs);
    CollectionScope.setCollectionRouteArgsWriter(routeArgs);
    final details = CollectionDetailsController(
      writeRepository: SyncStoreCollectionDetailsWriteRepository(graph: graph),
      attachmentWriteRepository: SyncStoreAttachmentWriteRepository(
        graph: graph,
        ids: ids,
      ),
    );
    CollectionScope.setCollectionDetails(details.state);
    final images = AttachmentImageCache(
      attachmentReadRepository: SyncStoreAttachmentReadRepository(graph: graph),
    );
    CollectionScope.setImages(images.state);
    CollectionScope.setPlaybackController(
      AudioPlaybackController(
        player: _SilentPlayer(),
        attachmentRead: SyncStoreAttachmentReadRepository(graph: graph),
      ),
    );
    CollectionScope.setFactory(
      () => CollectionController(
        readRepository: SyncStoreCollectionReadRepository(graph: graph),
        writeRepository: SyncStoreCollectionWriteRepository(
          graph: graph,
          ids: ids,
        ),
        moveReadRepository: SyncStoreCardMoveReadRepository(graph: graph),
        attachmentReadRepository: SyncStoreAttachmentReadRepository(
          graph: graph,
        ),
        attachmentWriteRepository: SyncStoreAttachmentWriteRepository(
          graph: graph,
          ids: ids,
        ),
        imageCache: images,
        imagePicker: _UnusedImagePicker(),
        audioRecorder: _UnusedAudioRecorder(),
        filePicker: _UnusedFilePicker(),
        shareRepository: _UnusedShare(),
        linkLauncher: _UnusedLinkLauncher(),
        collectionDetails: details,
        cardLinks: CardLinksController(
          readRepository: SyncStoreLinkTargetsReadRepository(graph: graph),
          writeRepository: SyncStoreCardLinksWriteRepository(
            graph: graph,
            ids: ids,
          ),
        ),
        timelineChannel: _NoopTimelineChannel(),
      ),
    );
  }

  /// Let in-memory reads/writes resolve and the UI settle.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: CollectionPage(),
      ),
    );
    // Let the in-memory load resolve, then the reveal scroll + highlight run.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('scrolls an old focused card into view', (tester) async {
    await seed(tester);
    await pumpPage(tester);

    final focused = find.text('card 2');
    expect(focused, findsOneWidget);
    final viewport = tester.getRect(find.byType(CustomScrollView));
    expect(viewport.overlaps(tester.getRect(focused)), isTrue);
    // The newest card the feed normally opens on is scrolled away.
    expect(find.text('card ${cardCount - 1}'), findsNothing);

    // Let the highlight timer run out before the test ends.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('without a focus card the feed opens on the newest card', (
    tester,
  ) async {
    await seed(tester);
    routeArgs.open(routeArgs.collectionId);
    await pumpPage(tester);

    expect(find.text('card ${cardCount - 1}'), findsOneWidget);
    expect(find.text('card 2'), findsNothing);
  });

  testWidgets('scrolling up pages older cards in, down to the oldest', (
    tester,
  ) async {
    await seed(tester);
    routeArgs.open(routeArgs.collectionId);
    await pumpPage(tester);
    // The first page is only the newest cards: the oldest isn't built at all.
    expect(find.text('card 0', skipOffstage: false), findsNothing);

    for (var i = 0; i < 30 && find.text('card 0').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 600));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }
    expect(find.text('card 0'), findsOneWidget);
  });

  testWidgets('the collection name flies into the app bar as it scrolls away', (
    tester,
  ) async {
    await seed(tester);
    routeArgs.open(routeArgs.collectionId);
    await pumpPage(tester);
    double? progress() => tester
        .widget<TitleMorphFlight>(find.byType(TitleMorphFlight))
        .link
        .progress;

    // Opened on the newest cards: the title card isn't built, so the name is
    // docked in the app bar (its slot is there for semantics and taps).
    expect(progress(), 1);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Long')),
      findsOneWidget,
    );

    // Back at the top, the name sits whole in the title card.
    for (var i = 0; i < 30 && progress()! > 0; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 600));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }
    expect(progress(), 0);
    expect(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.text('Long'),
      ),
      findsOneWidget,
    );

    // Edging the card under the bar puts the name mid-flight, in step with
    // the finger.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CustomScrollView)),
    );
    await gesture.moveBy(const Offset(0, -kTouchSlop - 1));
    for (var i = 0; i < 40 && progress()! == 0; i++) {
      await gesture.moveBy(const Offset(0, -4));
      await tester.pump();
    }
    expect(progress(), inExclusiveRange(0, 1));
    await gesture.up();
    await tester.pumpAndSettle();

    // Scrolling the title card away docks it in the bar.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(progress(), 1);
  });

  testWidgets('long-press selects cards and moves them to another collection', (
    tester,
  ) async {
    await seed(tester);
    routeArgs.open(routeArgs.collectionId);
    final targetId = (await tester.runAsync(
      () => SyncStoreTimelineWriteRepository(
        graph: graph,
        ids: const UuidIdGenerator(),
      ).createCollection('Target'),
    ))!.getOrThrow();
    await pumpPage(tester);

    final newest = 'card ${cardCount - 1}';
    final second = 'card ${cardCount - 2}';
    await tester.longPress(find.text(newest));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    // While selecting, a tap toggles instead of opening the actions sheet.
    await tester.tap(find.text(second));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Move to collection'));
    await settle(tester);
    // The picker lists other collections only — not this one.
    expect(find.text('Long'), findsNothing);
    await tester.tap(find.text('Target'));
    await settle(tester);

    expect(find.text(newest), findsNothing);
    expect(find.text(second), findsNothing);
    expect(find.text('Moved 2 cards to “Target”'), findsOneWidget);
    final moved = await tester.runAsync(() => graph.store.feed(targetId));
    expect(moved!.map((s) => s.content['text']), [
      second,
      newest,
    ], reason: 'feed order is kept');
  });

  testWidgets('system back leaves selection mode first', (tester) async {
    await seed(tester);
    routeArgs.open(routeArgs.collectionId);
    await pumpPage(tester);

    await tester.longPress(find.text('card ${cardCount - 1}'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsNothing);
    expect(find.byType(CollectionPage), findsOneWidget);
  });
}
