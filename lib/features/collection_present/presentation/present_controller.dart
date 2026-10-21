import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:knit/core/attachments/presentation/attachment_image_cache.dart';
import 'package:knit/core/attachments/presentation/attachment_image_cache_state.dart';
import 'package:knit/features/audio_playback/presentation/audio_playback_controller.dart';
import 'package:knit/features/collection/domain/link_launcher.dart';
import 'package:knit/features/collection_present/domain/present_models.dart';
import 'package:knit/features/collection_present/domain/present_progress_repository.dart';
import 'package:knit/features/collection_present/domain/present_read_repository.dart';
import 'package:knit/features/collection_present/domain/screen_awake_port.dart';
import 'package:knit/features/collection_present/domain/slide_planner.dart';
import 'package:knit/features/collection_present/presentation/present_route_args.dart';
import 'package:knit/features/collection_present/presentation/present_state.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/features/connections/presentation/connections_route_args.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';

/// The presentation page's input object (§4.9): loads the collection named by
/// the [PresentRouteArgs] carrier, plans it into slides through the pure
/// [SlidePlanner], and follows the viewer through them — remembering the slide
/// on the device, loading the images near it and keeping the screen on. One per
/// page instance; the page disposes it.
class PresentController {
  PresentController({
    required PresentRouteArgs routeArgs,
    required PresentReadRepository readRepository,
    required PresentProgressReadRepository progressReadRepository,
    required PresentProgressWriteRepository progressWriteRepository,
    required AttachmentImageCache imageCache,
    required AudioPlaybackController playback,
    required LinkLauncher linkLauncher,
    required ConnectionsRouteArgsWriter connectionsRouteArgs,
    required ScreenAwakePort screenAwake,
    SlidePlanner planner = const SlidePlanner(),
    Logger? logger,
  }) : _routeArgs = routeArgs,
       _read = readRepository,
       _progressRead = progressReadRepository,
       _progressWrite = progressWriteRepository,
       _imageCache = imageCache,
       _playback = playback,
       _linkLauncher = linkLauncher,
       _connectionsRouteArgs = connectionsRouteArgs,
       _screenAwake = screenAwake,
       _planner = planner,
       _log = logger ?? Logger('knit.present');

  final PresentRouteArgs _routeArgs;
  final PresentReadRepository _read;
  final PresentProgressReadRepository _progressRead;
  final PresentProgressWriteRepository _progressWrite;
  final AttachmentImageCache _imageCache;
  final AudioPlaybackController _playback;
  final LinkLauncher _linkLauncher;
  final ConnectionsRouteArgsWriter _connectionsRouteArgs;
  final ScreenAwakePort _screenAwake;
  final SlidePlanner _planner;
  final Logger _log;

  final PresentState state = PresentState();

  /// How many slides either side of the current one keep their images loaded.
  static const int _imageReach = 1;

  late final String _collectionId = _routeArgs.collectionId;

  /// The decoded slide images, as they load.
  AttachmentImageCacheState get images => _imageCache.state;

  /// The shared player, so an audio chip shows what's playing.
  ValueListenable<PlaybackSnapshot> get playback => _playback.snapshot;

  /// Read and plan the collection, and offer the slide it was left on.
  Future<void> load() async {
    unawaited(_keepScreenOn(true));
    final PresentSource source;
    switch (await _read.loadSource(_collectionId)) {
      case Ok(:final value):
        source = value;
      case Failure(:final error):
        _log.severe('present load failed', error.error, error.stackTrace);
        state.showFailure();
        return;
    }
    final deck = _planner.plan(source);
    final anchor = (await _progressRead.loadAnchor(_collectionId)).fold(
      (anchor) => anchor,
      (failure) {
        _log.warning('present progress read failed', failure.error);
        return null;
      },
    );
    state.showDeck(deck, resumeIndex: deck.resumeIndex(anchor));
    _showImagesNear(0);
  }

  /// The viewer moved to slide [index]: remember it and load nearby images.
  void pageChanged(int index) {
    final deck = state.deck;
    if (deck == null) return;
    state.moveTo(index);
    _showImagesNear(index);
    unawaited(_saveAnchor(deck.anchorOf(index)));
  }

  void toggleOverlay() => state.toggleOverlay();

  /// Follow a "See also" chip: a card in this presentation answers with its
  /// slide to jump to; anything else is handed to the Connections carrier
  /// (null — the page then opens Connections).
  int? openLink(PresentLink link) {
    if (link.kind == PresentLinkKind.card) {
      final index = state.deck?.indexOfCard(link.id);
      if (index != null) return index;
    }
    _connectionsRouteArgs.open(
      kind: switch (link.kind) {
        PresentLinkKind.card => ConnectedEntityKind.card,
        PresentLinkKind.collection => ConnectedEntityKind.collection,
      },
      id: link.id,
      title: link.label,
    );
    return null;
  }

  /// Open a link card's URL in the browser; false when it couldn't be opened.
  Future<bool> openUrl(String url) async =>
      (await _linkLauncher.open(url)).fold((_) => true, (failure) {
        _log.warning('present link open failed', failure);
        return false;
      });

  /// Play, pause or replay an audio card.
  Future<void> toggleAudio(PresentCard card) async {
    final attachmentId = card.attachmentId;
    if (attachmentId != null) await _playback.toggle(card.id, attachmentId);
  }

  void _showImagesNear(int index) {
    final slides = state.deck?.slides ?? const <Slide>[];
    final from = (index - _imageReach).clamp(0, slides.length);
    final to = (index + _imageReach + 1).clamp(0, slides.length);
    unawaited(
      _imageCache.show(this, [
        for (final slide in slides.sublist(from, to))
          ...switch (slide) {
            TitleSlide(:final coverAttachmentId) => [?coverAttachmentId],
            CardSlide(:final images) => [
              for (final c in images) ?c.attachmentId,
            ],
          },
      ]),
    );
  }

  Future<void> _saveAnchor(String? anchor) async {
    final result = await _progressWrite.saveAnchor(_collectionId, anchor);
    result.onFailure(
      (failure) => _log.warning('present progress save failed', failure.error),
    );
  }

  Future<void> _keepScreenOn(bool enabled) async {
    try {
      await _screenAwake.keepOn(enabled: enabled);
    } catch (e, st) {
      _log.warning('screen awake toggle failed', e, st);
    }
  }

  void dispose() {
    _imageCache.release(this);
    unawaited(_playback.close());
    unawaited(_keepScreenOn(false));
    state.dispose();
  }
}
