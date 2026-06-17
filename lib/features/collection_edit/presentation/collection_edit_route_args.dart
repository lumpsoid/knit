/// Route-args carrier for the Collection Edit page (cross_feature.md §2). The
/// origin screen (the Collection page) writes the collection to edit *before*
/// navigating; the Collection Edit page reads it on entry and dispatches
/// `ViewAttached`. Navigation itself carries no payload — the carrier is the
/// payload — so neither feature couples to the navigation system for its input.
library;

/// Read side — what the Collection Edit page consumes on entry.
abstract interface class CollectionEditRouteArgs {
  /// The collection to edit. Empty before any origin has written one.
  String get collectionId;

  /// The collection's current title, used to seed the title field.
  String get initialTitle;

  /// The collection's current description (spec §3.1), or null. Seeds the
  /// description field.
  String? get initialDescription;

  /// The collection's current cover image id (`cover_attachment_id`, §7.4.1), or
  /// null. Seeds the cover section without a second read.
  String? get initialCoverAttachmentId;
}

/// Write side — what an origin screen (Collection) sets before navigating.
abstract interface class CollectionEditRouteArgsWriter {
  void open({
    required String collectionId,
    required String initialTitle,
    String? initialDescription,
    String? initialCoverAttachmentId,
  });
}

/// The store implements both halves.
abstract interface class CollectionEditRouteArgsStore
    implements CollectionEditRouteArgs, CollectionEditRouteArgsWriter {}

/// Plain in-memory carrier — a single most-recent target. The destination reads
/// it synchronously on entry, so no persistence is needed.
class InMemoryCollectionEditRouteArgsStore
    implements CollectionEditRouteArgsStore {
  String _collectionId = '';
  String _initialTitle = '';
  String? _initialDescription;
  String? _initialCoverAttachmentId;

  @override
  String get collectionId => _collectionId;

  @override
  String get initialTitle => _initialTitle;

  @override
  String? get initialDescription => _initialDescription;

  @override
  String? get initialCoverAttachmentId => _initialCoverAttachmentId;

  @override
  void open({
    required String collectionId,
    required String initialTitle,
    String? initialDescription,
    String? initialCoverAttachmentId,
  }) {
    _collectionId = collectionId;
    _initialTitle = initialTitle;
    _initialDescription = initialDescription;
    _initialCoverAttachmentId = initialCoverAttachmentId;
  }
}
