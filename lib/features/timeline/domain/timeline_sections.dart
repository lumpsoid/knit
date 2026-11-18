import 'dart:math';

import 'package:knit/features/timeline/domain/timeline_order.dart';
import 'package:knit/sync/sync.dart';

/// The home timeline split into a **Pinned** section, the rest, and the
/// archived collections set aside for the Archive page (§4.1/§3.4).
///
/// Sections keep the incoming order — the §8.6.3 `last_updated DESC` recency
/// sort — unless a manual [TimelineOrder] arranges the Pinned section and the
/// rest, each within itself. The archive is never reordered. Pinning only lifts
/// a collection into the top section. Archived wins over pinned: an archived
/// collection never shows on Home. Pinned ids that no longer match a live
/// collection (deleted, wiped) are simply ignored. An imported collection counts
/// as archived when it carries the device-local flag ([localArchivedIds]).
class TimelineSections {
  const TimelineSections._(this.pinned, this.others, this.archived, this.order);

  factory TimelineSections.split(
    List<CollectionSummary> collections,
    Set<String> pinnedIds, {
    Set<String> localArchivedIds = const {},
    required TimelineOrder order,
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
    return TimelineSections._(
      order.arrange(pinned),
      order.arrange(others),
      archived,
      order,
    );
  }

  /// Whether [c] is archived: signed (`archived_at`) or, for an imported
  /// collection, device-local.
  static bool isArchived(CollectionSummary c, Set<String> localArchivedIds) =>
      c.archived || localArchivedIds.contains(c.collectionId);

  /// The Pinned section, arranged by [order].
  final List<CollectionSummary> pinned;

  /// The rest of Home, arranged by [order].
  final List<CollectionSummary> others;

  /// Archived collections (§3.4), listed on the Archive page, not on Home.
  final List<CollectionSummary> archived;

  /// The manual order that arranged [pinned] and [others].
  final TimelineOrder order;

  bool get hasPinned => pinned.isNotEmpty;
  bool get hasArchived => archived.isNotEmpty;

  /// Whether Home has no rows of its own (everything is archived, or nothing
  /// exists yet).
  bool get homeIsEmpty => pinned.isEmpty && others.isEmpty;

  /// The order after a reorder-mode drag over the flat `[...pinned, ...others]`
  /// list, from [oldIndex] to [newIndex] (`onReorderItem` semantics). The drag
  /// stays in its section: [newIndex] is clamped into it, so it never crosses
  /// the Pinned/rest boundary. Null when the drag moves nothing, or [oldIndex]
  /// is out of range.
  TimelineOrder? moved(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= pinned.length + others.length) return null;
    final inPinned = oldIndex < pinned.length;
    final section = inPinned ? pinned : others;
    final start = inPinned ? 0 : pinned.length;
    final localOld = oldIndex - start;
    final localNew = max(0, min(newIndex - start, section.length - 1));
    if (localOld == localNew) return null;
    return order.movedWithin(section, localOld, localNew);
  }
}
