import 'package:knit/features/connections/presentation/connections_controller.dart';
import 'package:knit/features/connections/presentation/connections_route_args.dart';

/// Composition cell for the Connections view (fcis.md §4). Holds the lazily
/// built [ConnectionsController] and the read side of the route-args carrier
/// (cross_feature.md §2) the page reads its focused entity from.
abstract final class ConnectionsScope {
  static ConnectionsController? _controller;
  static ConnectionsController Function()? _factory;
  static ConnectionsRouteArgs? _routeArgs;

  static void setFactory(ConnectionsController Function() factory) =>
      _factory = factory;
  static void setRouteArgs(ConnectionsRouteArgs args) => _routeArgs = args;
  static void reset() => _controller = null;

  static ConnectionsController get controller {
    if (_controller != null) return _controller!;
    if (_factory == null) {
      throw StateError(
        'ConnectionsScope is not initialized.\n'
        'Call ConnectionsScope.setFactory() before accessing controller.',
      );
    }
    return _controller = _factory!();
  }

  static ConnectionsRouteArgs get routeArgs {
    final args = _routeArgs;
    if (args == null) {
      throw StateError(
        'ConnectionsScope.routeArgs is not initialized.\n'
        'Call ConnectionsScope.setRouteArgs() during composition.',
      );
    }
    return args;
  }
}
