/// Route-args carrier for presenting a collection (cross_feature.md §2). The
/// Collection page writes the collection before navigating; the presentation's
/// controller reads it when it loads.
library;

/// Read side — what the presentation consumes on load.
abstract interface class PresentRouteArgs {
  /// The collection to present. Empty before any origin has written one.
  String get collectionId;
}

/// Write side — what the Collection page sets before navigating.
abstract interface class PresentRouteArgsWriter {
  void open(String collectionId);
}

/// The store implements both halves.
abstract interface class PresentRouteArgsStore
    implements PresentRouteArgs, PresentRouteArgsWriter {}

/// Plain in-memory carrier — a single most-recent target.
class InMemoryPresentRouteArgsStore implements PresentRouteArgsStore {
  String _collectionId = '';

  @override
  String get collectionId => _collectionId;

  @override
  void open(String collectionId) => _collectionId = collectionId;
}
