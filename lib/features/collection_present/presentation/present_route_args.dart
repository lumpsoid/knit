/// Route-args carrier for presenting a collection (cross_feature.md §2). The
/// Collection page — or a presentation following a link (§4.9) — writes the
/// collection before navigating; the presentation's controller reads it when
/// it loads.
library;

/// Read side — what the presentation consumes on load.
abstract interface class PresentRouteArgs {
  /// The collection to present. Empty before any origin has written one.
  String get collectionId;

  /// The card whose slide to open at (a followed card link); null opens at
  /// the title slide.
  String? get focusCardId;

  /// The collections already presented below this one, bottom first; empty
  /// when it is presented straight from its Collection page.
  List<String> get presentedBelow;
}

/// Write side — what the Collection page (or a presentation) sets before
/// navigating.
abstract interface class PresentRouteArgsWriter {
  void open(
    String collectionId, {
    String? focusCardId,
    List<String> presentedBelow,
  });
}

/// The store implements both halves.
abstract interface class PresentRouteArgsStore
    implements PresentRouteArgs, PresentRouteArgsWriter {}

/// Plain in-memory carrier — a single most-recent target.
class InMemoryPresentRouteArgsStore implements PresentRouteArgsStore {
  String _collectionId = '';
  String? _focusCardId;
  List<String> _presentedBelow = const [];

  @override
  String get collectionId => _collectionId;

  @override
  String? get focusCardId => _focusCardId;

  @override
  List<String> get presentedBelow => _presentedBelow;

  @override
  void open(
    String collectionId, {
    String? focusCardId,
    List<String> presentedBelow = const [],
  }) {
    _collectionId = collectionId;
    _focusCardId = focusCardId;
    _presentedBelow = List.unmodifiable(presentedBelow);
  }
}
