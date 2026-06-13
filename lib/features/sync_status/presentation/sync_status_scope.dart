import 'package:knit/features/sync_status/presentation/sync_status_controller.dart';

/// Cell for [SyncStatusController] (fcis.md §4). An app-wide singleton: the
/// marker widget embedded in each page's app bar resolves it lazily and
/// refreshes it on mount.
abstract class SyncStatusScope {
  static SyncStatusController? _controller;
  static SyncStatusController Function()? _factory;

  static void setController(SyncStatusController c) => _controller = c;
  static void setFactory(SyncStatusController Function() factory) =>
      _factory = factory;
  static void reset() => _controller = null;

  static SyncStatusController get controller {
    if (_controller != null) return _controller!;
    if (_factory == null) {
      throw StateError(
        'SyncStatusScope is not initialized.\n'
        'Call SyncStatusScope.setController() or SyncStatusScope.setFactory() '
        'before accessing SyncStatusScope.controller.',
      );
    }
    return _controller = _factory!();
  }
}
