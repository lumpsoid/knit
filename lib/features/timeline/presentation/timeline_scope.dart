import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/timeline/presentation/timeline_controller.dart';

/// Cell for [TimelineController] (fcis.md §4) plus the write side of the
/// route-args carrier (cross_feature.md §2): the home screen writes the
/// collection to open before navigating to it.
abstract class TimelineScope {
  static TimelineController? _controller;
  static TimelineController Function()? _factory;
  static CollectionRouteArgsWriter? _routeArgsWriter;

  static void setController(TimelineController c) => _controller = c;
  static void setFactory(TimelineController Function() factory) =>
      _factory = factory;
  static void setRouteArgsWriter(CollectionRouteArgsWriter writer) =>
      _routeArgsWriter = writer;
  static void reset() => _controller = null;

  static CollectionRouteArgsWriter get routeArgsWriter {
    final writer = _routeArgsWriter;
    if (writer == null) {
      throw StateError(
        'TimelineScope.routeArgsWriter is not initialized.\n'
        'Call TimelineScope.setRouteArgsWriter() during composition.',
      );
    }
    return writer;
  }

  static TimelineController get controller {
    if (_controller != null) return _controller!;
    if (_factory == null) {
      throw StateError(
        'TimelineScope is not initialized.\n'
        'Call TimelineScope.setController() or TimelineScope.setFactory() '
        'before accessing TimelineScope.controller.',
      );
    }
    return _controller = _factory!();
  }
}
