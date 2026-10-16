import 'package:knit/core/attachments/presentation/attachment_image_cache_state.dart';
import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/collection_details/presentation/collection_details_state.dart';
import 'package:knit/features/search/presentation/search_controller.dart';
import 'package:knit/features/timeline/presentation/timeline_controller.dart';

/// Cell for [TimelineController] (fcis.md §4) plus the write side of the
/// route-args carrier (cross_feature.md §2): the home screen writes the
/// collection to open before navigating to it. Also holds the factory for the
/// Search page the app bar opens (one fresh [SearchController] per page), and
/// the shared collection details the rows read titles and covers from.
abstract class TimelineScope {
  static TimelineController? _controller;
  static TimelineController Function()? _factory;
  static CollectionRouteArgsWriter? _routeArgsWriter;
  static SearchController Function()? _searchFactory;
  static CollectionDetailsState? _collectionDetails;
  static AttachmentImageCacheState? _images;

  static void setController(TimelineController c) => _controller = c;
  static void setFactory(TimelineController Function() factory) =>
      _factory = factory;
  static void setRouteArgsWriter(CollectionRouteArgsWriter writer) =>
      _routeArgsWriter = writer;
  static void setSearchFactory(SearchController Function() factory) =>
      _searchFactory = factory;
  static void setCollectionDetails(CollectionDetailsState details) =>
      _collectionDetails = details;
  static void setImages(AttachmentImageCacheState images) => _images = images;
  static void reset() => _controller = null;

  /// The shared decoded images (read-only here): the rows' covers.
  static AttachmentImageCacheState get images {
    final images = _images;
    if (images == null) {
      throw StateError(
        'TimelineScope.images is not initialized.\n'
        'Call TimelineScope.setImages() during composition.',
      );
    }
    return images;
  }

  /// The shared collection headers (read-only here): a row's title and cover.
  static CollectionDetailsState get collectionDetails {
    final details = _collectionDetails;
    if (details == null) {
      throw StateError(
        'TimelineScope.collectionDetails is not initialized.\n'
        'Call TimelineScope.setCollectionDetails() during composition.',
      );
    }
    return details;
  }

  /// A new controller for one Search page; the page disposes it.
  static SearchController createSearch() {
    final factory = _searchFactory;
    if (factory == null) {
      throw StateError(
        'TimelineScope search is not initialized.\n'
        'Call TimelineScope.setSearchFactory() during composition.',
      );
    }
    return factory();
  }

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
