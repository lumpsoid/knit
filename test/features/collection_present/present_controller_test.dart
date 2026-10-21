import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/attachments/presentation/attachment_image_cache.dart';
import 'package:knit/features/audio_playback/presentation/audio_playback_controller.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection_present/domain/present_failure.dart';
import 'package:knit/features/collection_present/domain/present_models.dart';
import 'package:knit/features/collection_present/infra/in_memory_present_progress_repository.dart';
import 'package:knit/features/collection_present/presentation/present_controller.dart';
import 'package:knit/features/collection_present/presentation/present_route_args.dart';
import 'package:knit/features/collection_present/presentation/present_state.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/features/connections/presentation/connections_route_args.dart';
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
        PresentLink(kind: PresentLinkKind.card, id: 'museum', label: 'museum'),
        PresentLink(
          kind: PresentLinkKind.collection,
          id: 'other',
          label: 'Museums',
        ),
      ],
    ),
    _card('square', CardKind.image, attachmentId: 'square-att'),
    _card('market', CardKind.audio, attachmentId: 'market-att'),
    _card('museum', CardKind.image, attachmentId: 'museum-att'),
  ],
);

void main() {
  late InMemoryPresentProgressRepository progress;
  late FakeAttachments attachments;
  late SilentPlayer player;
  late FakeLauncher launcher;
  late FakeAwake awake;
  late InMemoryConnectionsRouteArgsStore connections;

  PresentController controllerWith(Result<PresentSource, PresentFailure> read) {
    final routeArgs = InMemoryPresentRouteArgsStore()..open('col');
    return PresentController(
      routeArgs: routeArgs,
      readRepository: FakePresentRead(read),
      progressReadRepository: progress,
      progressWriteRepository: progress,
      imageCache: AttachmentImageCache(attachmentReadRepository: attachments),
      playback: AudioPlaybackController(
        player: player,
        attachmentRead: attachments,
      ),
      linkLauncher: launcher,
      connectionsRouteArgs: connections,
      screenAwake: awake,
      logger: Logger('test.present'),
    );
  }

  setUp(() {
    progress = InMemoryPresentProgressRepository();
    attachments = FakeAttachments();
    player = SilentPlayer();
    launcher = FakeLauncher();
    awake = FakeAwake();
    connections = InMemoryConnectionsRouteArgsStore();
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

  test('a link to a card on another slide jumps to it', () async {
    final c = controllerWith(Ok(_source));
    await c.load();
    final links = (c.state.deck!.slides[1] as CardSlide).notes.single.links;

    expect(c.openLink(links[0]), 3);
    expect(connections.entityId, isEmpty);
  });

  test('any other link goes to the Connections carrier', () async {
    final c = controllerWith(Ok(_source));
    await c.load();
    final links = (c.state.deck!.slides[1] as CardSlide).notes.single.links;

    expect(c.openLink(links[1]), isNull);
    expect(connections.entityKind, ConnectedEntityKind.collection);
    expect(connections.entityId, 'other');
    expect(connections.entityTitle, 'Museums');
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
