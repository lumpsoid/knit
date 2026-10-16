import 'package:knit/core/attachments/presentation/attachment_image_cache_state.dart';
import 'package:knit/features/card_edit/presentation/card_edit_controller.dart';
import 'package:knit/features/card_links/presentation/card_links_controller.dart';
import 'package:knit/features/card_edit/presentation/card_edit_route_args.dart';

/// Composition cell for the Card Edit page (fcis.md §4). Holds the lazily built
/// [CardEditController] and the read side of the route-args carrier
/// (cross_feature.md §2) the page reads its target card from, the shared image
/// cache the attachment preview reads from, and the shared card links the page
/// opens the link picker over.
abstract final class CardEditScope {
  static CardEditController? _controller;
  static CardEditController Function()? _factory;
  static CardEditRouteArgs? _routeArgs;
  static AttachmentImageCacheState? _images;
  static CardLinksController? _cardLinks;

  static void setFactory(CardEditController Function() factory) =>
      _factory = factory;
  static void setRouteArgs(CardEditRouteArgs args) => _routeArgs = args;
  static void setImages(AttachmentImageCacheState images) => _images = images;
  static void setCardLinks(CardLinksController links) => _cardLinks = links;
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

  /// The shared card links — the page opens the link picker over them.
  static CardLinksController get cardLinks {
    final links = _cardLinks;
    if (links == null) {
      throw StateError(
        'CardEditScope.cardLinks is not initialized.\n'
        'Call CardEditScope.setCardLinks() during composition.',
      );
    }
    return links;
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
