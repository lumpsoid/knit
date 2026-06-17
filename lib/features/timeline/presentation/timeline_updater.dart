import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/timeline/presentation/timeline_action.dart';
import 'package:knit/features/timeline/presentation/timeline_effect.dart';
import 'package:knit/features/timeline/presentation/timeline_state.dart';
import 'package:knit/sync/sync.dart';

/// Pure reducer for Timeline (fcis.md §6.1).
class TimelineUpdater
    implements Updater<TimelineState, TimelineAction, TimelineEffect> {
  const TimelineUpdater();

  @override
  (TimelineState, List<TimelineEffect>?) update(
    TimelineState state,
    TimelineAction action,
  ) {
    switch (action) {
      case ViewAttached():
      case RefreshRequested():
        return (
          state.copyWith(status: TimelineStatus.loading),
          const [LoadTimelineEffect()],
        );
      case CollectionsLoaded(:final collections):
        // Preserve the decoded-cover cache across refreshes (ids are immutable),
        // and load any cover whose bytes we don't already hold.
        final toLoad = _uncachedCovers(collections, state.coverBytes);
        return (
          TimelineState(
            status: TimelineStatus.ready,
            collections: collections,
            coverBytes: state.coverBytes,
          ),
          toLoad.isEmpty
              ? null
              : [for (final id in toLoad) LoadCoverBytesEffect(id)],
        );
      case CoverBytesLoaded(:final attachmentId, :final bytes):
        // Cache only on success; a miss leaves the placeholder in place.
        if (bytes == null) return (state, null);
        return (
          state.copyWith(
            coverBytes: {...state.coverBytes, attachmentId: bytes},
          ),
          null,
        );
      case TimelineLoadFailed():
        return (
          state.copyWith(status: TimelineStatus.failed),
          null,
        );
      case CollectionTapped(:final collectionId):
        return (state, [OpenCollectionEffect(collectionId)]);
      case CreateCollectionRequested(:final title):
        final trimmed = title.trim();
        if (trimmed.isEmpty) return (state, null);
        return (state, [CreateCollectionEffect(trimmed)]);
      case CollectionCreated(:final collectionId):
        return (state, [OpenCollectionEffect(collectionId)]);
      case CollectionCreateFailed():
        // The shell surfaces a message; nothing changes in state.
        return (state, null);
      case DeleteCollectionRequested(:final collectionId):
        return (state, [DeleteCollectionEffect(collectionId)]);
      case CollectionDeleted():
        // Re-read the home feed so the deleted row drops out.
        return (
          state.copyWith(status: TimelineStatus.loading),
          const [LoadTimelineEffect()],
        );
      case CollectionDeleteFailed():
        // The shell surfaces a message; nothing changes in state.
        return (state, null);
      case DeactivateFeature():
        return (state, null);
    }
  }

  /// Distinct cover `attachment_id`s whose bytes aren't cached yet (§7.4.1).
  static List<String> _uncachedCovers(
    List<CollectionSummary> collections,
    Map<String, Object?> cache,
  ) {
    final ids = <String>{};
    for (final c in collections) {
      final id = c.coverAttachmentId;
      if (id != null && !cache.containsKey(id)) ids.add(id);
    }
    return ids.toList(growable: false);
  }
}
