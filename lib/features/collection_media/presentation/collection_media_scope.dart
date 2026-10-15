import 'package:knit/features/card_edit/presentation/card_edit_route_args.dart';
import 'package:knit/features/collection/presentation/audio_playback_controller.dart';
import 'package:knit/features/collection_media/presentation/collection_media_controller.dart';
import 'package:knit/features/collection_media/presentation/collection_media_route_args.dart';

/// Composition cell for the Collection Media page (fcis.md §4). Holds the lazily
/// built [CollectionMediaController], the read side of its route-args carrier
/// (cross_feature.md §2), the write side of the Card Edit carrier (a long-press
/// opens the item's card), and the app-wide audio player the Collection feed
/// shares — so a clip started here keeps playing in the feed's bar.
abstract final class CollectionMediaScope {
  static CollectionMediaController? _controller;
  static CollectionMediaController Function()? _factory;
  static CollectionMediaRouteArgs? _routeArgs;
  static CardEditRouteArgsWriter? _cardEditWriter;
  static AudioPlaybackController? _playbackController;

  static void setFactory(CollectionMediaController Function() factory) =>
      _factory = factory;
  static void setRouteArgs(CollectionMediaRouteArgs args) => _routeArgs = args;
  static void setCardEditRouteArgsWriter(CardEditRouteArgsWriter writer) =>
      _cardEditWriter = writer;
  static void setPlaybackController(AudioPlaybackController controller) =>
      _playbackController = controller;
  static void reset() => _controller = null;

  static CollectionMediaController get controller {
    if (_controller != null) return _controller!;
    if (_factory == null) {
      throw StateError(
        'CollectionMediaScope is not initialized.\n'
        'Call CollectionMediaScope.setFactory() before accessing controller.',
      );
    }
    return _controller = _factory!();
  }

  static CollectionMediaRouteArgs get routeArgs {
    final args = _routeArgs;
    if (args == null) {
      throw StateError(
        'CollectionMediaScope.routeArgs is not initialized.\n'
        'Call CollectionMediaScope.setRouteArgs() during composition.',
      );
    }
    return args;
  }

  static CardEditRouteArgsWriter get cardEditRouteArgsWriter {
    final writer = _cardEditWriter;
    if (writer == null) {
      throw StateError(
        'CollectionMediaScope.cardEditRouteArgsWriter is not initialized.\n'
        'Call CollectionMediaScope.setCardEditRouteArgsWriter() during '
        'composition.',
      );
    }
    return writer;
  }

  static AudioPlaybackController get playbackController {
    final controller = _playbackController;
    if (controller == null) {
      throw StateError(
        'CollectionMediaScope.playbackController is not initialized.\n'
        'Call CollectionMediaScope.setPlaybackController() during composition.',
      );
    }
    return controller;
  }
}
