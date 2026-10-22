import 'package:flutter/foundation.dart';
import 'package:knit/core/recents/domain/recent_targets.dart';
import 'package:knit/features/card_links/domain/card_links_models.dart';

/// The link picker's state (§4.4) — a [ChangeNotifier] the shared
/// [CardLinksController] owns and mutates, and the picker sheet listens to.
/// One picking session at a time: the [source] pick, the collections level,
/// the targets the source card already links to, and each drilled
/// collection's cards, loaded lazily and cached for the session.
class CardLinksState extends ChangeNotifier {
  LinkPick? _source;
  List<LinkTarget>? _collections;
  RecentTargets _recents = const RecentTargets();
  LinkedTargets _linked = const LinkedTargets();
  final Map<String, List<LinkTarget>> _cards = {};

  /// What the session picks; null before a picker has opened.
  LinkPick? get source => _source;

  /// The device's collections the [source] lists; null while loading.
  List<LinkTarget>? get collections {
    final collections = _collections;
    final source = _source;
    if (collections == null || source == null) return collections;
    return [
      for (final c in collections)
        if (source.lists(c)) c,
    ];
  }

  /// The "Recent" row: up to three collections recently linked to that the
  /// [source] may link to right now (never the card's own collection), most
  /// recent first. Empty ⇒ no row.
  List<LinkTarget> get recentCollections {
    final listed = collections;
    if (listed == null) return const [];
    return _recents.among([
      for (final c in listed)
        if (canLinkToCollection(c.id)) c,
    ], (c) => c.id);
  }

  /// The collection [id] among [collections], or null.
  LinkTarget? collection(String id) {
    for (final c in _collections ?? const <LinkTarget>[]) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Whether [collectionId]'s cards have loaded this session.
  bool hasCardsOf(String collectionId) => _cards.containsKey(collectionId);

  /// The cards of [collectionId] the [source] may link to; null while loading.
  List<LinkTarget>? cardsIn(String collectionId) {
    final cards = _cards[collectionId];
    final source = _source;
    if (cards == null || source == null) return cards;
    return [
      for (final card in cards)
        if (source.canLinkToCard(card.id)) card,
    ];
  }

  /// Whether the source card already links to [target] — its ✓ (§4.4).
  bool isLinked(LinkTarget target) => _linked.has(target);

  /// What tapping [target] means: unlink a ✓ one, link any other.
  LinkPickerChoice choose(LinkTarget target) => _linked.toggle(target);

  /// Whether the [source] may link to the collection [id] itself.
  bool canLinkToCollection(String id) =>
      _source?.canLinkToCollection(id) ?? true;

  /// Start a fresh session for [source]: a write since the last one may have
  /// changed the targets, so nothing carries over.
  void startPicking(LinkPick source) {
    _source = source;
    _collections = null;
    _recents = const RecentTargets();
    _linked = const LinkedTargets();
    _cards.clear();
    notifyListeners();
  }

  void showCollections(
    List<LinkTarget> collections, {
    RecentTargets recents = const RecentTargets(),
    LinkedTargets linked = const LinkedTargets(),
  }) {
    _collections = collections;
    _recents = recents;
    _linked = linked;
    notifyListeners();
  }

  void showCards(String collectionId, List<LinkTarget> cards) {
    _cards[collectionId] = cards;
    notifyListeners();
  }
}
