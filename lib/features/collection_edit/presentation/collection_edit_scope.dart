import 'package:knit/features/collection_details/presentation/collection_details_state.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_controller.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_route_args.dart';
import 'package:knit/features/collection_media/presentation/collection_media_route_args.dart';

/// Composition cell for the Collection Edit page (fcis.md §4). Holds the lazily
/// built [CollectionEditController] and the read side of the route-args carrier
/// (cross_feature.md §2) the page reads its target collection from, plus the
/// write side of the Media page's carrier (the summary row hands off to it), and
/// the shared collection details the page reads the header from.
abstract final class CollectionEditScope {
  static CollectionEditController? _controller;
  static CollectionEditController Function()? _factory;
  static CollectionEditRouteArgs? _routeArgs;
  static CollectionMediaRouteArgsWriter? _mediaWriter;
  static CollectionDetailsState? _collectionDetails;

  static void setFactory(CollectionEditController Function() factory) =>
      _factory = factory;
  static void setRouteArgs(CollectionEditRouteArgs args) => _routeArgs = args;
  static void setMediaRouteArgsWriter(CollectionMediaRouteArgsWriter writer) =>
      _mediaWriter = writer;
  static void setCollectionDetails(CollectionDetailsState details) =>
      _collectionDetails = details;
  static void reset() => _controller = null;

  static CollectionEditController get controller {
    if (_controller != null) return _controller!;
    if (_factory == null) {
      throw StateError(
        'CollectionEditScope is not initialized.\n'
        'Call CollectionEditScope.setFactory() before accessing controller.',
      );
    }
    return _controller = _factory!();
  }

  static CollectionEditRouteArgs get routeArgs {
    final args = _routeArgs;
    if (args == null) {
      throw StateError(
        'CollectionEditScope.routeArgs is not initialized.\n'
        'Call CollectionEditScope.setRouteArgs() during composition.',
      );
    }
    return args;
  }

  static CollectionMediaRouteArgsWriter get mediaRouteArgsWriter {
    final writer = _mediaWriter;
    if (writer == null) {
      throw StateError(
        'CollectionEditScope.mediaRouteArgsWriter is not initialized.\n'
        'Call CollectionEditScope.setMediaRouteArgsWriter() during '
        'composition.',
      );
    }
    return writer;
  }

  /// The shared collection headers (read-only here): the page seeds its fields
  /// and shows the cover from them.
  static CollectionDetailsState get collectionDetails {
    final details = _collectionDetails;
    if (details == null) {
      throw StateError(
        'CollectionEditScope.collectionDetails is not initialized.\n'
        'Call CollectionEditScope.setCollectionDetails() during composition.',
      );
    }
    return details;
  }
}
