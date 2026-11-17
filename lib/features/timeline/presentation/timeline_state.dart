import 'package:flutter/foundation.dart';
import 'package:knit/core/ownership/collection_ownership.dart';
import 'package:knit/features/timeline/domain/timeline_order.dart';
import 'package:knit/features/timeline/domain/timeline_sections.dart';
import 'package:knit/sync/sync.dart';

enum TimelineStatus { loading, ready, failed }

@immutable
class TimelineState {
  const TimelineState({
    this.status = TimelineStatus.loading,
    this.collections = const [],
    this.pinnedIds = const {},
    this.importedOwners = const {},
    this.localArchivedIds = const {},
    this.hubs = const {},
    this.order = const TimelineOrder(),
    this.reordering = false,
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

  /// The imported, read-only collections (docs/collection_share.md): their
  /// creator's `nickname#fingerprint`, by collection id.
  final Map<String, String> importedOwners;

  /// Imported collections archived on this device only (never synced).
  final Set<String> localArchivedIds;

  /// The hubs over each collection (§8.6.4): the live collections linking to
  /// it, shown as the row's "in:" line. Absent ⇒ none.
  final Map<String, List<CollectionHub>> hubs;

  /// The user's manual Home order (device-local, §4.1); empty is the recency
  /// order.
  final TimelineOrder order;

  /// Whether Home is in drag-to-reorder mode.
  final bool reordering;

  /// The hubs over [collectionId], in hub order; empty when none.
  List<CollectionHub> hubsOf(String collectionId) =>
      hubs[collectionId] ?? const [];

  bool get isEmpty => collections.isEmpty;

  /// The feed split into the Pinned section and the rest (§4.1).
  TimelineSections get sections => TimelineSections.split(
    collections,
    pinnedIds,
    localArchivedIds: localArchivedIds,
    order: order,
  );

  bool isPinned(String collectionId) => pinnedIds.contains(collectionId);

  bool isArchived(String collectionId) => collections.any(
    (c) =>
        c.collectionId == collectionId &&
        TimelineSections.isArchived(c, localArchivedIds),
  );

  /// Whose [collectionId] is.
  CollectionOwnership ownershipOf(String collectionId) =>
      importedOwners.containsKey(collectionId)
      ? CollectionOwnership.imported
      : CollectionOwnership.own;

  TimelineState copyWith({
    TimelineStatus? status,
    List<CollectionSummary>? collections,
    Set<String>? pinnedIds,
    Map<String, String>? importedOwners,
    Set<String>? localArchivedIds,
    Map<String, List<CollectionHub>>? hubs,
    TimelineOrder? order,
    bool? reordering,
  }) => TimelineState(
    status: status ?? this.status,
    collections: collections ?? this.collections,
    pinnedIds: pinnedIds ?? this.pinnedIds,
    importedOwners: importedOwners ?? this.importedOwners,
    localArchivedIds: localArchivedIds ?? this.localArchivedIds,
    hubs: hubs ?? this.hubs,
    order: order ?? this.order,
    reordering: reordering ?? this.reordering,
  );
}
