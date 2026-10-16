import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/share_capture/domain/shared_item.dart';
import 'package:knit/features/share_capture/presentation/incoming_share_controller.dart';
import 'package:knit/features/share_capture/presentation/share_capture_controller.dart';

/// Composition seam for share capture (§4.7): `main` wires the app-wide
/// [IncomingShareController], the per-share capture controller factory, and
/// the Collection carrier the "Open" snackbar action writes.
class ShareCaptureScope {
  const ShareCaptureScope._();

  static IncomingShareController? _incoming;
  static ShareCaptureController Function(List<SharedItem> items)? _factory;
  static CollectionRouteArgsWriter? _collectionRouteArgs;

  static void setIncoming(IncomingShareController incoming) =>
      _incoming = incoming;
  static void setFactory(
    ShareCaptureController Function(List<SharedItem> items) factory,
  ) => _factory = factory;
  static void setCollectionRouteArgsWriter(CollectionRouteArgsWriter writer) =>
      _collectionRouteArgs = writer;

  /// The app-wide receiver, or null when share capture isn't wired (tests
  /// that pump a page on its own) — the gate then does nothing.
  static IncomingShareController? get incoming => _incoming;

  static ShareCaptureController create(List<SharedItem> items) {
    final factory = _factory;
    if (factory == null) {
      throw StateError(
        'ShareCaptureScope has no factory. '
        'Call ShareCaptureScope.setFactory() during composition.',
      );
    }
    return factory(items);
  }

  static CollectionRouteArgsWriter get collectionRouteArgs {
    final writer = _collectionRouteArgs;
    if (writer == null) {
      throw StateError(
        'ShareCaptureScope has no Collection route-args writer. '
        'Call ShareCaptureScope.setCollectionRouteArgsWriter() during '
        'composition.',
      );
    }
    return writer;
  }
}
