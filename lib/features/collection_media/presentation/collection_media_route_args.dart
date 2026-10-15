/// Route-args carrier for the Collection Media page (cross_feature.md §2). The
/// origin screen (the Collection Edit page) writes the collection whose media to
/// show *before* navigating; the Collection Media page reads it on entry and
/// dispatches `ViewAttached`. Navigation itself carries no payload.
library;

/// Read side — what the Collection Media page consumes on entry.
abstract interface class CollectionMediaRouteArgs {
  /// The collection whose media to show. Empty before any origin has written one.
  String get collectionId;

  /// The collection's title, shown in the app bar.
  String get title;
}

/// Write side — what an origin screen (Collection Edit) sets before navigating.
abstract interface class CollectionMediaRouteArgsWriter {
  void open({required String collectionId, required String title});
}

/// The store implements both halves.
abstract interface class CollectionMediaRouteArgsStore
    implements CollectionMediaRouteArgs, CollectionMediaRouteArgsWriter {}

/// Plain in-memory carrier — a single most-recent target. The destination reads
/// it synchronously on entry, so no persistence is needed.
class InMemoryCollectionMediaRouteArgsStore
    implements CollectionMediaRouteArgsStore {
  String _collectionId = '';
  String _title = '';

  @override
  String get collectionId => _collectionId;

  @override
  String get title => _title;

  @override
  void open({required String collectionId, required String title}) {
    _collectionId = collectionId;
    _title = title;
  }
}
