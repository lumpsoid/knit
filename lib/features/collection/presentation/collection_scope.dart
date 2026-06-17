import 'package:knit/features/card_edit/presentation/card_edit_route_args.dart';
import 'package:knit/features/collection/presentation/audio_playback_controller.dart';
import 'package:knit/features/collection/presentation/collection_controller.dart';
import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_route_args.dart';
import 'package:knit/features/connections/presentation/connections_route_args.dart';

/// Composition cell for the Collection screen (fcis.md §4). Holds the lazily
/// built [CollectionController], the read side of the route-args carrier
/// (cross_feature.md §2) the page reads its target collection from, and the
/// write sides of the Connections carrier (§4.4) and the Card Edit carrier
/// (§4.3) the page hands off to.
abstract final class CollectionScope {
  static CollectionController? _controller;
  static CollectionController Function()? _factory;
  static AudioPlaybackController? _playbackController;
  static CollectionRouteArgs? _routeArgs;
  static ConnectionsRouteArgsWriter? _connectionsWriter;
  static CardEditRouteArgsWriter? _cardEditWriter;
  static CollectionEditRouteArgsWriter? _collectionEditWriter;

  static void setFactory(CollectionController Function() factory) =>
      _factory = factory;
  static void setPlaybackController(AudioPlaybackController controller) =>
      _playbackController = controller;
  static void setRouteArgs(CollectionRouteArgs args) => _routeArgs = args;
  static void setConnectionsRouteArgsWriter(
    ConnectionsRouteArgsWriter writer,
  ) => _connectionsWriter = writer;
  static void setCardEditRouteArgsWriter(CardEditRouteArgsWriter writer) =>
      _cardEditWriter = writer;
  static void setCollectionEditRouteArgsWriter(
    CollectionEditRouteArgsWriter writer,
  ) => _collectionEditWriter = writer;
  static void reset() => _controller = null;

  static CollectionController get controller {
    if (_controller != null) return _controller!;
    if (_factory == null) {
      throw StateError(
        'CollectionScope is not initialized.\n'
        'Call CollectionScope.setFactory() before accessing controller.',
      );
    }
    return _controller = _factory!();
  }

  /// The app-wide audio player shared by the mini-player bar and the now-playing
  /// card flip. A singleton (unlike the lazily-rebuilt [controller]) so a clip
  /// keeps its lifecycle across feed re-syncs; the page stops it on exit.
  static AudioPlaybackController get playbackController {
    final controller = _playbackController;
    if (controller == null) {
      throw StateError(
        'CollectionScope.playbackController is not initialized.\n'
        'Call CollectionScope.setPlaybackController() during composition.',
      );
    }
    return controller;
  }

  static CollectionRouteArgs get routeArgs {
    final args = _routeArgs;
    if (args == null) {
      throw StateError(
        'CollectionScope.routeArgs is not initialized.\n'
        'Call CollectionScope.setRouteArgs() during composition.',
      );
    }
    return args;
  }

  static ConnectionsRouteArgsWriter get connectionsRouteArgsWriter {
    final writer = _connectionsWriter;
    if (writer == null) {
      throw StateError(
        'CollectionScope.connectionsRouteArgsWriter is not initialized.\n'
        'Call CollectionScope.setConnectionsRouteArgsWriter() during '
        'composition.',
      );
    }
    return writer;
  }

  static CardEditRouteArgsWriter get cardEditRouteArgsWriter {
    final writer = _cardEditWriter;
    if (writer == null) {
      throw StateError(
        'CollectionScope.cardEditRouteArgsWriter is not initialized.\n'
        'Call CollectionScope.setCardEditRouteArgsWriter() during '
        'composition.',
      );
    }
    return writer;
  }

  static CollectionEditRouteArgsWriter get collectionEditRouteArgsWriter {
    final writer = _collectionEditWriter;
    if (writer == null) {
      throw StateError(
        'CollectionScope.collectionEditRouteArgsWriter is not initialized.\n'
        'Call CollectionScope.setCollectionEditRouteArgsWriter() during '
        'composition.',
      );
    }
    return writer;
  }
}
