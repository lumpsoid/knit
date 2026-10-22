import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/attachments/presentation/attachment_image_cache.dart';
import 'package:knit/features/audio_playback/presentation/audio_playback_controller.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection_present/domain/present_failure.dart';
import 'package:knit/features/collection_present/domain/present_follow.dart';
import 'package:knit/features/collection_present/domain/present_models.dart';
import 'package:knit/features/collection_present/domain/present_read_repository.dart';
import 'package:knit/features/collection_present/infra/in_memory_present_progress_repository.dart';
import 'package:knit/features/collection_present/infra/shared_screen_awake.dart';
import 'package:knit/features/collection_present/presentation/present_controller.dart';
import 'package:knit/features/collection_present/presentation/present_route_args.dart';
import 'package:knit/features/collection_present/presentation/present_state.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';

import 'present_fakes.dart';

PresentCard _card(
  String id,
  CardKind kind, {
  String? attachmentId,
  List<PresentLink> links = const [],
}) => PresentCard(id: id, kind: kind, attachmentId: attachmentId, links: links);

/// Title, then [gate + built], [square + market], [museum].
final _source = PresentSource(
  collectionId: 'col',
  title: 'Old town',
  coverAttachmentId: 'cover-att',
  cards: [
    _card('gate', CardKind.image, attachmentId: 'gate-att'),
    _card(
      'built',
      CardKind.text,
      links: const [
        PresentLink(
          kind: PresentLinkKind.card,
          id: 'museum',
          label: 'museum',
          collectionId: 'col',
        ),
        PresentLink(
          kind: PresentLinkKind.collection,
          id: 'other',
          label: 'Museums',
          collectionId: 'other',
        ),
      ],
    ),
    _card('square', CardKind.image, attachmentId: 'square-att'),
    _card('market', CardKind.audio, attachmentId: 'market-att'),
    _card('museum', CardKind.image, attachmentId: 'museum-att'),
  ],
);

/// Title, then [m1], [m2 + back] — `back` links to the first collection and
/// to one of its cards.
final _other = PresentSource(
  collectionId: 'other',
  title: 'Museums',
  cards: [
    _card('m1', CardKind.text),
    _card('m2', CardKind.image, attachmentId: 'm2-att'),
    _card(
      'back',
      CardKind.text,
      links: const [
        PresentLink(
          kind: PresentLinkKind.collection,
          id: 'col',
          label: 'Old town',
          collectionId: 'col',
        ),
        PresentLink(
          kind: PresentLinkKind.card,
          id: 'square',
          label: 'square',
          collectionId: 'col',
        ),
      ],
    ),
  ],
);

const _toOther = PresentLink(
  kind: PresentLinkKind.collection,
  id: 'other',
  label: 'Museums',
  collectionId: 'other',
);

const _toM2 = PresentLink(
  kind: PresentLinkKind.card,
  id: 'm2',
  label: 'm2',
  collectionId: 'other',
);

void main() {
  late InMemoryPresentProgressRepository progress;
  late FakeAttachments attachments;
  late SilentPlayer player;
  late FakeLauncher launcher;
  late FakeAwake awake;
  late InMemoryPresentRouteArgsStore carrier;

  PresentController controllerOver(PresentReadRepository read) =>
      PresentController(
        routeArgs: carrier,
        routeArgsWriter: carrier,
        createOnTop: () => controllerOver(read),
        readRepository: read,
        progressReadRepository: progress,
        progressWriteRepository: progress,
        imageCache: AttachmentImageCache(attachmentReadRepository: attachments),
        playback: AudioPlaybackController(
          player: player,
          attachmentRead: attachments,
        ),
        linkLauncher: launcher,
        screenAwake: awake,
        logger: Logger('test.present'),
      );

  PresentController controllerWith(Result<PresentSource, PresentFailure> read) {
    carrier.open('col');
    return controllerOver(FakePresentRead(read));
  }

  /// Presents 'col' over both sources, loaded.
  Future<PresentController> presentCol() async {
    carrier.open('col');
    final c = controllerOver(
      FakePresentSources({'col': _source, 'other': _other}),
    );
    await c.load();
    return c;
  }

  setUp(() {
    progress = InMemoryPresentProgressRepository();
    attachments = FakeAttachments();
    player = SilentPlayer();
    launcher = FakeLauncher();
    awake = FakeAwake();
    carrier = InMemoryPresentRouteArgsStore();
  });

  test('load plans the slides, keeps the screen on and loads the first '
      'images', () async {
    final c = controllerWith(Ok(_source));
    expect(c.state.status, PresentStatus.loading);
    await c.load();
    await pumpEventQueue();

    expect(c.state.status, PresentStatus.ready);
    expect(c.state.deck!.length, 4);
    expect(c.state.index, 0);
    expect(c.state.resumeIndex, isNull);
    expect(awake.calls, [true]);
    // The title slide and the one after it.
    expect(attachments.reads, unorderedEquals(['cover-att', 'gate-att']));
    expect(c.images.of('gate-att'), isNotNull);
  });

  test('a failed read shows the failure', () async {
    final c = controllerWith(const Failure(PresentLoadFailure('gone')));
    await c.load();
    expect(c.state.status, PresentStatus.failed);
  });

  test('offers the slide it was left on until the viewer moves', () async {
    await progress.saveAnchor('col', 'square');
    final c = controllerWith(Ok(_source));
    await c.load();
    expect(c.state.resumeIndex, 2);

    c.pageChanged(2);
    expect(c.state.resumeIndex, isNull);
    expect(c.state.overlayVisible, isFalse);
  });

  test('a slide that no longer exists offers nothing', () async {
    await progress.saveAnchor('col', 'deleted-card');
    final c = controllerWith(Ok(_source));
    await c.load();
    expect(c.state.resumeIndex, isNull);
  });

  test('turning a slide remembers it; the title slide forgets', () async {
    final c = controllerWith(Ok(_source));
    await c.load();

    c.pageChanged(3);
    await pumpEventQueue();
    expect(progress.anchors['col'], 'museum');
    expect(attachments.reads, contains('museum-att'));

    c.pageChanged(0);
    await pumpEventQueue();
    expect(progress.anchors.containsKey('col'), isFalse);
  });

  group('following links', () {
    test('a card in this collection turns the deck to its slide', () async {
      final c = await presentCol();
      final links = (c.state.deck!.slides[1] as CardSlide).notes.single.links;

      expect(c.followLink(links[0]), const JumpToSlide(3));
      expect(carrier.collectionId, 'col');
    });

    test('another collection is presented on top, over this stack', () async {
      final c = await presentCol();

      expect(c.followLink(_toOther), const PresentOnTop('other'));
      expect(carrier.collectionId, 'other');
      expect(carrier.focusCardId, isNull);
      expect(carrier.presentedBelow, ['col']);

      final top = c.presentOnTop();
      await top.load();
      expect(top.state.deck!.slides[0], isA<TitleSlide>());
      expect(top.state.index, 0);
    });

    test("a card elsewhere opens its collection at the card's slide", () async {
      final c = await presentCol();

      expect(
        c.followLink(_toM2),
        const PresentOnTop('other', focusCardId: 'm2'),
      );
      final top = c.presentOnTop();
      await top.load();
      expect(top.state.index, 2);
    });

    test(
      'a collection further down is gone back to, not pushed again',
      () async {
        final c = await presentCol();
        c.followLink(_toOther);
        final top = c.presentOnTop();
        await top.load();
        final links = (top.state.deck!.slides[2] as CardSlide).notes.last.links;

        final toCol = top.followLink(links[0]);
        expect(toCol, const ReturnToPresentation('col'));
        final toSquare = top.followLink(links[1]);
        expect(
          toSquare,
          const ReturnToPresentation('col', focusCardId: 'square'),
        );
        // Nothing new was written for a presentation on top.
        expect(carrier.collectionId, 'other');

        // The one below stays on its slide, or turns to the card's.
        c.pageChanged(1);
        expect(c.returnedTo(toCol as ReturnToPresentation), 1);
        expect(c.returnedTo(toSquare as ReturnToPresentation), 2);
        // A presentation that isn't the target passes it on.
        expect(top.returnedTo(toCol), isNull);
      },
    );

    test(
      'opening at a linked slide leaves the remembered slide alone',
      () async {
        await progress.saveAnchor('other', 'm1');
        final c = await presentCol();
        c.followLink(_toM2);
        final top = c.presentOnTop();
        await top.load();
        await pumpEventQueue();

        expect(top.state.index, 2);
        expect(top.state.resumeIndex, isNull);
        expect(progress.anchors['other'], 'm1');

        // The viewer's own turns count as usual.
        top.pageChanged(0);
        await pumpEventQueue();
        expect(progress.anchors.containsKey('other'), isFalse);
        top.pageChanged(2);
        await pumpEventQueue();
        expect(progress.anchors['other'], 'm2');
      },
    );

    test('closing the top presentation keeps the screen on below', () async {
      final shared = SharedScreenAwake(awake);
      carrier.open('col');
      final read = FakePresentSources({'col': _source, 'other': _other});
      PresentController create() => PresentController(
        routeArgs: carrier,
        routeArgsWriter: carrier,
        createOnTop: create,
        readRepository: read,
        progressReadRepository: progress,
        progressWriteRepository: progress,
        imageCache: AttachmentImageCache(attachmentReadRepository: attachments),
        playback: AudioPlaybackController(
          player: player,
          attachmentRead: attachments,
        ),
        linkLauncher: launcher,
        screenAwake: shared,
      );
      final c = create();
      await c.load();
      c.followLink(_toOther);
      final top = c.presentOnTop();
      await top.load();

      top.dispose();
      await pumpEventQueue();
      expect(awake.calls, [true]);
      c.dispose();
      await pumpEventQueue();
      expect(awake.calls, [true, false]);
    });
  });

  test('openUrl reports whether the browser opened', () async {
    final c = controllerWith(Ok(_source));
    expect(await c.openUrl('https://example.com'), isTrue);
    launcher.succeeds = false;
    expect(await c.openUrl('nope'), isFalse);
    expect(launcher.opened, ['https://example.com', 'nope']);
  });

  test('an audio card plays through the shared player', () async {
    final c = controllerWith(Ok(_source));
    await c.load();
    final audio = (c.state.deck!.slides[2] as CardSlide).notes.single;
    await c.toggleAudio(audio);
    expect(c.playback.value.cardId, 'market');
    expect(player.calls, ['play']);
  });

  test('dispose lets the screen sleep and stops playback', () async {
    final c = controllerWith(Ok(_source));
    await c.load();
    c.dispose();
    await pumpEventQueue();
    expect(awake.calls, [true, false]);
    expect(player.calls, contains('stop'));
  });
}
