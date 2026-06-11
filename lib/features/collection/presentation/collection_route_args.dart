/// Route-args carrier for the Collection screen (cross_feature.md §2). The
/// Timeline (origin) writes the collection to open *before* navigating; the
/// Collection page (destination) reads it on entry and dispatches
/// [ViewAttached]. Navigation itself carries no payload — the carrier is the
/// payload — so neither feature couples to the navigation system for its input.
library;

/// Read side — what the Collection page consumes on entry.
abstract interface class CollectionRouteArgs {
  /// The collection to open. Empty before any origin has written one.
  String get collectionId;
}

/// Write side — what an origin screen (Timeline) sets before navigating.
abstract interface class CollectionRouteArgsWriter {
  void open(String collectionId);
}

/// The store implements both halves.
abstract interface class CollectionRouteArgsStore
    implements CollectionRouteArgs, CollectionRouteArgsWriter {}

/// Plain in-memory carrier — a single most-recent target. The destination
/// reads it synchronously on entry, so no persistence is needed.
class InMemoryCollectionRouteArgsStore implements CollectionRouteArgsStore {
  String _collectionId = '';

  @override
  String get collectionId => _collectionId;

  @override
  void open(String collectionId) => _collectionId = collectionId;
}
