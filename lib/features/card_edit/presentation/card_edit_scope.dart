import 'package:knit/core/attachments/presentation/attachment_image_cache_state.dart';
import 'package:knit/features/card_edit/presentation/card_edit_controller.dart';
import 'package:knit/features/card_edit/presentation/card_edit_route_args.dart';

/// Composition cell for the Card Edit page (fcis.md §4). Holds the lazily built
/// [CardEditController] and the read side of the route-args carrier
/// (cross_feature.md §2) the page reads its target card from, and the shared
/// image cache the attachment preview reads from.
abstract final class CardEditScope {
  static CardEditController? _controller;
  static CardEditController Function()? _factory;
  static CardEditRouteArgs? _routeArgs;
  static AttachmentImageCacheState? _images;

  static void setFactory(CardEditController Function() factory) =>
      _factory = factory;
  static void setRouteArgs(CardEditRouteArgs args) => _routeArgs = args;
  static void setImages(AttachmentImageCacheState images) => _images = images;
  static void reset() => _controller = null;

  /// The shared decoded images (read-only here): an image attachment's preview.
  static AttachmentImageCacheState get images {
    final images = _images;
    if (images == null) {
      throw StateError(
        'CardEditScope.images is not initialized.\n'
        'Call CardEditScope.setImages() during composition.',
      );
    }
    return images;
  }

  static CardEditController get controller {
    if (_controller != null) return _controller!;
    if (_factory == null) {
      throw StateError(
        'CardEditScope is not initialized.\n'
        'Call CardEditScope.setFactory() before accessing controller.',
      );
    }
    return _controller = _factory!();
  }

  static CardEditRouteArgs get routeArgs {
    final args = _routeArgs;
    if (args == null) {
      throw StateError(
        'CardEditScope.routeArgs is not initialized.\n'
        'Call CardEditScope.setRouteArgs() during composition.',
      );
    }
    return args;
  }
}
