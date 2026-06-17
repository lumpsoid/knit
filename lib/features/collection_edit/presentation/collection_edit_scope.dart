import 'package:knit/features/collection_edit/presentation/collection_edit_controller.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_route_args.dart';

/// Composition cell for the Collection Edit page (fcis.md §4). Holds the lazily
/// built [CollectionEditController] and the read side of the route-args carrier
/// (cross_feature.md §2) the page reads its target collection from.
abstract final class CollectionEditScope {
  static CollectionEditController? _controller;
  static CollectionEditController Function()? _factory;
  static CollectionEditRouteArgs? _routeArgs;

  static void setFactory(CollectionEditController Function() factory) =>
      _factory = factory;
  static void setRouteArgs(CollectionEditRouteArgs args) => _routeArgs = args;
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
}
