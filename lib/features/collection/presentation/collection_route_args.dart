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

  /// A card to scroll to and briefly highlight on entry (e.g. a search hit), or
  /// null to open the feed at its normal position (newest card at the bottom).
  String? get focusCardId;

  /// Opened from a home-screen widget's quick input: focus the composer, and
  /// leave the page once a card is sent.
  bool get quickInput;
}

/// Write side — what an origin screen (Timeline) sets before navigating.
abstract interface class CollectionRouteArgsWriter {
  /// Target [collectionId]; [focusCardId] optionally names a card in it to
  /// reveal, and [quickInput] opens it for one quick card. Each call replaces
  /// the previous target, focus and quick input included.
  void open(String collectionId, {String? focusCardId, bool quickInput});
}

/// The store implements both halves.
abstract interface class CollectionRouteArgsStore
    implements CollectionRouteArgs, CollectionRouteArgsWriter {}

/// Plain in-memory carrier — a single most-recent target. The destination
/// reads it synchronously on entry, so no persistence is needed.
class InMemoryCollectionRouteArgsStore implements CollectionRouteArgsStore {
  String _collectionId = '';
  String? _focusCardId;
  bool _quickInput = false;

  @override
  String get collectionId => _collectionId;

  @override
  String? get focusCardId => _focusCardId;

  @override
  bool get quickInput => _quickInput;

  @override
  void open(
    String collectionId, {
    String? focusCardId,
    bool quickInput = false,
  }) {
    _collectionId = collectionId;
    _focusCardId = focusCardId;
    _quickInput = quickInput;
  }
}
