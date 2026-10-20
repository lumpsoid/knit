import 'package:flutter/foundation.dart';
import 'package:knit/features/timeline/domain/timeline_sections.dart';
import 'package:knit/sync/sync.dart';

enum TimelineStatus { loading, ready, failed }

@immutable
class TimelineState {
  const TimelineState({
    this.status = TimelineStatus.loading,
    this.collections = const [],
    this.pinnedIds = const {},
  });

  final TimelineStatus status;
  final List<CollectionSummary> collections;

  /// Decoded bytes of collection cover images, keyed by `attachment_id`.
  /// Content-addressed, so an id's bytes are immutable — cached here to avoid
  /// reloading on every feed refresh. Absent ⇒ loading or missing, which
  /// renders the lettered-avatar placeholder fallback.

  /// Ids of the collections pinned on this device (device-local, never synced).
  /// May hold stale ids of deleted collections — [sections] ignores them.
  final Set<String> pinnedIds;

  bool get isEmpty => collections.isEmpty;

  /// The feed split into the Pinned section and the rest (§4.1).
  TimelineSections get sections =>
      TimelineSections.split(collections, pinnedIds);

  bool isPinned(String collectionId) => pinnedIds.contains(collectionId);

  bool isArchived(String collectionId) =>
      collections.any((c) => c.collectionId == collectionId && c.archived);

  TimelineState copyWith({
    TimelineStatus? status,
    List<CollectionSummary>? collections,
    Set<String>? pinnedIds,
  }) => TimelineState(
    status: status ?? this.status,
    collections: collections ?? this.collections,
    pinnedIds: pinnedIds ?? this.pinnedIds,
  );
}
