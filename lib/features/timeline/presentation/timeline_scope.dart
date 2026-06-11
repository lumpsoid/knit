import 'package:knit/features/timeline/presentation/timeline_controller.dart';

/// Cell for [TimelineController] (fcis.md §4). The Scope holds nothing else.
abstract class TimelineScope {
  static TimelineController? _controller;
  static TimelineController Function()? _factory;

  static void setController(TimelineController c) => _controller = c;
  static void setFactory(TimelineController Function() factory) =>
      _factory = factory;
  static void reset() => _controller = null;

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
