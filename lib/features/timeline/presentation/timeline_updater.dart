import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/timeline/presentation/timeline_action.dart';
import 'package:knit/features/timeline/presentation/timeline_effect.dart';
import 'package:knit/features/timeline/presentation/timeline_state.dart';

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
        return (
          TimelineState(
            status: TimelineStatus.ready,
            collections: collections,
          ),
          null,
        );
      case TimelineLoadFailed(:final message):
        return (
          state.copyWith(
            status: TimelineStatus.failed,
            errorMessage: message,
          ),
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
}
