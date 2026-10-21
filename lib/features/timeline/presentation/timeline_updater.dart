import 'package:knit/core/ownership/collection_ownership.dart';
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
      case CollectionsLoaded(
        :final collections,
        :final pinnedIds,
        :final importedOwners,
        :final localArchivedIds,
      ):
        // The covers load through the shared image cache (it skips the ones
        // it already holds).
        return (
          TimelineState(
            status: TimelineStatus.ready,
            collections: collections,
            pinnedIds: pinnedIds ?? state.pinnedIds,
            importedOwners: importedOwners,
            localArchivedIds: localArchivedIds ?? state.localArchivedIds,
          ),
          [ShowCoversEffect(_covers(collections))],
        );
      case TimelineLoadFailed():
        return (state.copyWith(status: TimelineStatus.failed), null);
      case CollectionTapped(:final collectionId):
        return (state, [OpenCollectionEffect(collectionId)]);
      case CreateCollectionRequested(:final title):
        final trimmed = title.trim();
        if (trimmed.isEmpty) return (state, null);
        return (state, [CreateCollectionEffect(trimmed)]);
      case CollectionCreated(:final collectionId):
        // Re-read the home feed so the new row is there on the way back; the
        // list stays as it is (no loading flash) under the opening page.
        return (
          state,
          [const LoadTimelineEffect(), OpenCollectionEffect(collectionId)],
        );
      case CollectionCreateFailed():
        // The shell surfaces a message; nothing changes in state.
        return (state, null);
      case DeleteCollectionRequested(:final collectionId):
        return (state, [DeleteCollectionEffect(collectionId)]);
      case CollectionDeleted(:final collectionId):
        // Re-read the home feed so the deleted row drops out, and drop its pin
        // so the device-local pin set doesn't accumulate dead ids.
        return (
          state.copyWith(status: TimelineStatus.loading),
          [
            const LoadTimelineEffect(),
            if (state.isPinned(collectionId))
              SetPinnedEffect(collectionId, pinned: false),
          ],
        );
      case CollectionDeleteFailed():
        // The shell surfaces a message; nothing changes in state.
        return (state, null);
      case PinToggled(:final collectionId, :final pinned):
        if (state.isPinned(collectionId) == pinned) return (state, null);
        return (state, [SetPinnedEffect(collectionId, pinned: pinned)]);
      case PinsChanged(:final pinnedIds):
        return (state.copyWith(pinnedIds: pinnedIds), null);
      case PinUpdateFailed():
        // The shell surfaces a message; nothing changes in state.
        return (state, null);
      case ArchiveToggled(:final collectionId, :final archived):
        if (state.isArchived(collectionId) == archived) return (state, null);
        return (
          state,
          [
            switch (ArchiveTarget.of(state.ownershipOf(collectionId))) {
              ArchiveTarget.signed => SetArchivedEffect(
                collectionId,
                archived: archived,
              ),
              ArchiveTarget.local => SetLocalArchivedEffect(
                collectionId,
                archived: archived,
              ),
            },
          ],
        );
      case CollectionArchiveChanged(:final collectionId, :final archived):
        // Re-read the home feed so the row moves to (or back from) the
        // Archive; archiving also drops the device-local pin (§3.4).
        return (
          state.copyWith(status: TimelineStatus.loading),
          [
            const LoadTimelineEffect(),
            if (archived && state.isPinned(collectionId))
              SetPinnedEffect(collectionId, pinned: false),
          ],
        );
      case ArchiveUpdateFailed():
        // The shell surfaces a message; nothing changes in state.
        return (state, null);
      case DeactivateFeature():
        return (state, const [ReleaseCoversEffect()]);
    }
  }

  /// The cover `attachment_id`s the feed shows (§7.4.1).
  static List<String> _covers(List<CollectionSummary> collections) => [
    for (final c in collections) ?c.coverAttachmentId,
  ];
}
