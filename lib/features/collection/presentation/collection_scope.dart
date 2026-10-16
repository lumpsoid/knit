import 'package:knit/core/attachments/presentation/attachment_image_cache_state.dart';
import 'package:knit/features/card_edit/presentation/card_edit_route_args.dart';
import 'package:knit/features/card_links/presentation/card_links_controller.dart';
import 'package:knit/features/audio_playback/presentation/audio_playback_controller.dart';
import 'package:knit/features/collection/presentation/collection_controller.dart';
import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/collection_details/presentation/collection_details_state.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_route_args.dart';
import 'package:knit/features/connections/presentation/connections_route_args.dart';

/// Composition cell for the Collection screen (fcis.md §4). Provides a
/// page-scoped [CollectionController] (built fresh per page via [create], owned
/// and disposed by the page — so two stacked Collection pages never share
/// state), the read side of the route-args carrier (cross_feature.md §2) the
/// page reads its target collection from, and the write sides of the
/// Connections carrier (§4.4) and the Card Edit carrier (§4.3) the page hands
/// off to, plus its own carrier's write side (to open a move's target). The carriers, the audio player, the shared collection details (the
/// header the title card shows), the shared image cache and the shared card
/// links (the link picker) are app-wide singletons.
abstract final class CollectionScope {
  static CollectionController Function()? _factory;
  static AudioPlaybackController? _playbackController;
  static CollectionRouteArgs? _routeArgs;
  static CollectionRouteArgsWriter? _collectionWriter;
  static ConnectionsRouteArgsWriter? _connectionsWriter;
  static CardEditRouteArgsWriter? _cardEditWriter;
  static CollectionEditRouteArgsWriter? _collectionEditWriter;
  static CollectionDetailsState? _collectionDetails;
  static AttachmentImageCacheState? _images;
  static CardLinksController? _cardLinks;

  static void setFactory(CollectionController Function() factory) =>
      _factory = factory;
  static void setPlaybackController(AudioPlaybackController controller) =>
      _playbackController = controller;
  static void setRouteArgs(CollectionRouteArgs args) => _routeArgs = args;
  static void setCollectionRouteArgsWriter(CollectionRouteArgsWriter writer) =>
      _collectionWriter = writer;
  static void setCollectionDetails(CollectionDetailsState details) =>
      _collectionDetails = details;
  static void setImages(AttachmentImageCacheState images) => _images = images;
  static void setCardLinks(CardLinksController links) => _cardLinks = links;
  static void setConnectionsRouteArgsWriter(
    ConnectionsRouteArgsWriter writer,
  ) => _connectionsWriter = writer;
  static void setCardEditRouteArgsWriter(CardEditRouteArgsWriter writer) =>
      _cardEditWriter = writer;
  static void setCollectionEditRouteArgsWriter(
    CollectionEditRouteArgsWriter writer,
  ) => _collectionEditWriter = writer;

  /// Build a controller for one page instance. Not cached — the page owns the
  /// returned controller and calls `dispose()` on exit (fcis.md §4).
  static CollectionController create() {
    final factory = _factory;
    if (factory == null) {
      throw StateError(
        'CollectionScope is not initialized.\n'
        'Call CollectionScope.setFactory() before create().',
      );
    }
    return factory();
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

  /// The shared collection headers (read-only here) — the title card's title,
  /// description and cover.
  static CollectionDetailsState get collectionDetails {
    final details = _collectionDetails;
    if (details == null) {
      throw StateError(
        'CollectionScope.collectionDetails is not initialized.\n'
        'Call CollectionScope.setCollectionDetails() during composition.',
      );
    }
    return details;
  }

  /// The shared decoded images (read-only here) — card thumbnails and cover.
  static AttachmentImageCacheState get images {
    final images = _images;
    if (images == null) {
      throw StateError(
        'CollectionScope.images is not initialized.\n'
        'Call CollectionScope.setImages() during composition.',
      );
    }
    return images;
  }

  /// The shared card links — the page opens the link picker over them.
  static CardLinksController get cardLinks {
    final links = _cardLinks;
    if (links == null) {
      throw StateError(
        'CollectionScope.cardLinks is not initialized.\n'
        'Call CollectionScope.setCardLinks() during composition.',
      );
    }
    return links;
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

  /// The write side of this page's own carrier — used to open the collection
  /// the selected cards were just moved into.
  static CollectionRouteArgsWriter get collectionRouteArgsWriter {
    final writer = _collectionWriter;
    if (writer == null) {
      throw StateError(
        'CollectionScope.collectionRouteArgsWriter is not initialized.\n'
        'Call CollectionScope.setCollectionRouteArgsWriter() during '
        'composition.',
      );
    }
    return writer;
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
