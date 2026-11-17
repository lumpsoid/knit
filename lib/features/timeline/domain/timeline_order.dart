import 'package:knit/sync/sync.dart';

/// The user's manual order of collections on Home (§4.1): device-local,
/// like pins — never synced or signed. Empty means the §8.6.3 recency order.
class TimelineOrder {
  const TimelineOrder([this.ids = const []]);

  /// Collection ids in the user's order, across the Pinned and the rest.
  final List<String> ids;

  /// Whether the user has arranged Home; false keeps the recency order.
  bool get isManual => ids.isNotEmpty;

  /// [section] (a Home section in its incoming recency order) arranged by this
  /// order: the collections not listed come first, in their incoming order,
  /// then the listed ones by their index in [ids]. Ids that match no collection
  /// are ignored. Always a new list.
  List<CollectionSummary> arrange(List<CollectionSummary> section) {
    final rank = {for (var i = 0; i < ids.length; i++) ids[i]: i};
    final unlisted = [
      for (final c in section)
        if (!rank.containsKey(c.collectionId)) c,
    ];
    final listed = [
      for (final c in section)
        if (rank.containsKey(c.collectionId)) c,
    ]..sort((a, b) => rank[a.collectionId]!.compareTo(rank[b.collectionId]!));
    return [...unlisted, ...listed];
  }

  /// This order after a drag inside [arrangedSection] (a section already
  /// arranged by this order) from [oldIndex] to [newIndex], both section-local
  /// with `onReorderItem` semantics (`newIndex` is the final slot). The
  /// section's ids take the new order and come first; every id not in the
  /// section keeps its relative order after them, so other sections stay put.
  TimelineOrder movedWithin(
    List<CollectionSummary> arrangedSection,
    int oldIndex,
    int newIndex,
  ) {
    final moved = [for (final c in arrangedSection) c.collectionId];
    final inSection = moved.toSet();
    final item = moved.removeAt(oldIndex);
    moved.insert(newIndex, item);
    return TimelineOrder([
      ...moved,
      for (final id in ids)
        if (!inSection.contains(id)) id,
    ]);
  }
}
