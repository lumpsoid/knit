import 'package:knit/sync/sync.dart';

/// The home timeline split into a **Pinned** section and the rest (§4.1).
///
/// Both sections keep the incoming order — the §8.6.3 `last_updated DESC`
/// recency sort — so pinning only lifts a collection into the top section; it
/// never reorders within one. Pinned ids that no longer match a live collection
/// (deleted, wiped) are simply ignored.
class TimelineSections {
  const TimelineSections._(this.pinned, this.others);

  factory TimelineSections.split(
    List<CollectionSummary> collections,
    Set<String> pinnedIds,
  ) {
    if (pinnedIds.isEmpty) return TimelineSections._(const [], collections);
    final pinned = <CollectionSummary>[];
    final others = <CollectionSummary>[];
    for (final c in collections) {
      (pinnedIds.contains(c.collectionId) ? pinned : others).add(c);
    }
    return TimelineSections._(pinned, others);
  }

  final List<CollectionSummary> pinned;
  final List<CollectionSummary> others;

  bool get hasPinned => pinned.isNotEmpty;
}
