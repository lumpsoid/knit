import 'package:knit/sync/sync.dart';

/// The home timeline split into a **Pinned** section, the rest, and the
/// archived collections set aside for the Archive page (§4.1/§3.4).
///
/// Every section keeps the incoming order — the §8.6.3 `last_updated DESC`
/// recency sort — so pinning only lifts a collection into the top section; it
/// never reorders within one. Archived wins over pinned: an archived collection
/// never shows on Home. Pinned ids that no longer match a live collection
/// (deleted, wiped) are simply ignored. An imported collection counts as
/// archived when it carries the device-local flag ([localArchivedIds]).
class TimelineSections {
  const TimelineSections._(this.pinned, this.others, this.archived);

  factory TimelineSections.split(
    List<CollectionSummary> collections,
    Set<String> pinnedIds, {
    Set<String> localArchivedIds = const {},
  }) {
    final pinned = <CollectionSummary>[];
    final others = <CollectionSummary>[];
    final archived = <CollectionSummary>[];
    for (final c in collections) {
      if (isArchived(c, localArchivedIds)) {
        archived.add(c);
      } else if (pinnedIds.contains(c.collectionId)) {
        pinned.add(c);
      } else {
        others.add(c);
      }
    }
    return TimelineSections._(pinned, others, archived);
  }

  /// Whether [c] is archived: signed (`archived_at`) or, for an imported
  /// collection, device-local.
  static bool isArchived(CollectionSummary c, Set<String> localArchivedIds) =>
      c.archived || localArchivedIds.contains(c.collectionId);

  final List<CollectionSummary> pinned;
  final List<CollectionSummary> others;

  /// Archived collections (§3.4), listed on the Archive page, not on Home.
  final List<CollectionSummary> archived;

  bool get hasPinned => pinned.isNotEmpty;
  bool get hasArchived => archived.isNotEmpty;

  /// Whether Home has no rows of its own (everything is archived, or nothing
  /// exists yet).
  bool get homeIsEmpty => pinned.isEmpty && others.isEmpty;
}
