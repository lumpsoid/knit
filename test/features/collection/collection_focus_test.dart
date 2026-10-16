import 'dart:async';
import 'dart:typed_data';

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
import 'package:knit/features/collection/infra/sync_store_collection_read_repository.dart';
import 'package:knit/features/collection/infra/sync_store_collection_write_repository.dart';
import 'package:knit/features/collection/presentation/audio_playback_controller.dart';
import 'package:knit/features/collection/presentation/collection_controller.dart';
import 'package:knit/features/collection/presentation/collection_page.dart';
import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/collection/presentation/collection_scope.dart';
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

  Future<void> seed(WidgetTester tester) async {
    final graph = AppGraph();
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
        attachmentReadRepository: SyncStoreAttachmentReadRepository(
          graph: graph,
        ),
        attachmentWriteRepository: SyncStoreAttachmentWriteRepository(
          graph: graph,
          ids: ids,
        ),
        imagePicker: _UnusedImagePicker(),
        audioRecorder: _UnusedAudioRecorder(),
        filePicker: _UnusedFilePicker(),
        shareRepository: _UnusedShare(),
        linkLauncher: _UnusedLinkLauncher(),
        timelineChannel: _NoopTimelineChannel(),
      ),
    );
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
}
