/// Route-args carrier for the Collection Edit page (cross_feature.md §2). The
/// origin screen (the Collection page) writes the collection to edit *before*
/// navigating; the Collection Edit page reads it on entry and dispatches
/// `ViewAttached`. Navigation itself carries no payload — the carrier is the
/// payload — so neither feature couples to the navigation system for its input.
/// The header itself (title, description, cover) comes from the shared
/// collection details, not the carrier.
library;

/// Read side — what the Collection Edit page consumes on entry.
abstract interface class CollectionEditRouteArgs {
  /// The collection to edit. Empty before any origin has written one.
  String get collectionId;
}

/// Write side — what an origin screen (Collection) sets before navigating.
abstract interface class CollectionEditRouteArgsWriter {
  void open({required String collectionId});
}

/// The store implements both halves.
abstract interface class CollectionEditRouteArgsStore
    implements CollectionEditRouteArgs, CollectionEditRouteArgsWriter {}

/// Plain in-memory carrier — a single most-recent target. The destination reads
/// it synchronously on entry, so no persistence is needed.
class InMemoryCollectionEditRouteArgsStore
    implements CollectionEditRouteArgsStore {
  String _collectionId = '';

  @override
  String get collectionId => _collectionId;

  @override
  void open({required String collectionId}) => _collectionId = collectionId;
}
