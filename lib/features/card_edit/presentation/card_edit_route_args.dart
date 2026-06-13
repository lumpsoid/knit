/// Route-args carrier for the Card Edit page (cross_feature.md §2). The origin
/// screen (the Collection page) writes the card to edit *before* navigating; the
/// Card Edit page reads it on entry and dispatches [ViewAttached]. Navigation
/// itself carries no payload — the carrier is the payload — so neither feature
/// couples to the navigation system for its input.
library;

/// Read side — what the Card Edit page consumes on entry.
abstract interface class CardEditRouteArgs {
  /// The card to edit. Empty before any origin has written one.
  String get cardId;

  /// The card's current body text, used to seed the editor field.
  String get initialText;
}

/// Write side — what an origin screen (Collection) sets before navigating.
abstract interface class CardEditRouteArgsWriter {
  void open({required String cardId, required String initialText});
}

/// The store implements both halves.
abstract interface class CardEditRouteArgsStore
    implements CardEditRouteArgs, CardEditRouteArgsWriter {}

/// Plain in-memory carrier — a single most-recent target. The destination reads
/// it synchronously on entry, so no persistence is needed.
class InMemoryCardEditRouteArgsStore implements CardEditRouteArgsStore {
  String _cardId = '';
  String _initialText = '';

  @override
  String get cardId => _cardId;

  @override
  String get initialText => _initialText;

  @override
  void open({required String cardId, required String initialText}) {
    _cardId = cardId;
    _initialText = initialText;
  }
}
