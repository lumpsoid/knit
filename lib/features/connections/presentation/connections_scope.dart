import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/connections/presentation/connections_controller.dart';
import 'package:knit/features/connections/presentation/connections_route_args.dart';

/// Composition cell for the Connections view (fcis.md §4). Provides a
/// page-scoped [ConnectionsController] (built fresh per page via [create], owned
/// and disposed by the page — so two stacked Connections pages never share
/// state), the read side of the route-args carrier (cross_feature.md §2) the
/// page reads its focused entity from, and the write side of the Collection
/// carrier (§4.2) the page hands off to when opening a connected item inside its
/// collection.
abstract final class ConnectionsScope {
  static ConnectionsController Function()? _factory;
  static ConnectionsRouteArgs? _routeArgs;
  static CollectionRouteArgsWriter? _collectionWriter;

  static void setFactory(ConnectionsController Function() factory) =>
      _factory = factory;
  static void setRouteArgs(ConnectionsRouteArgs args) => _routeArgs = args;
  static void setCollectionRouteArgsWriter(CollectionRouteArgsWriter writer) =>
      _collectionWriter = writer;

  /// Build a controller for one page instance. Not cached — the page owns the
  /// returned controller and calls `dispose()` on exit (fcis.md §4).
  static ConnectionsController create() {
    final factory = _factory;
    if (factory == null) {
      throw StateError(
        'ConnectionsScope is not initialized.\n'
        'Call ConnectionsScope.setFactory() before create().',
      );
    }
    return factory();
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

  static CollectionRouteArgsWriter get collectionRouteArgsWriter {
    final writer = _collectionWriter;
    if (writer == null) {
      throw StateError(
        'ConnectionsScope.collectionRouteArgsWriter is not initialized.\n'
        'Call ConnectionsScope.setCollectionRouteArgsWriter() during '
        'composition.',
      );
    }
    return writer;
  }
}
