import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/sync_status/presentation/sync_status_action.dart';
import 'package:knit/features/sync_status/presentation/sync_status_effect.dart';
import 'package:knit/features/sync_status/presentation/sync_status_state.dart';

/// Pure reducer for the sync marker (fcis.md §6.1).
class SyncStatusUpdater
    implements Updater<SyncStatusState, SyncStatusAction, SyncStatusEffect> {
  const SyncStatusUpdater();

  @override
  (SyncStatusState, List<SyncStatusEffect>?) update(
    SyncStatusState state,
    SyncStatusAction action,
  ) {
    switch (action) {
      case ViewAttached():
      case RefreshRequested():
        // Keep the last known count while refreshing (the view reuses it, so
        // the marker doesn't flicker on every page mount).
        return (
          state.copyWith(phase: SyncStatusPhase.loading),
          const [LoadPendingCountEffect()],
        );
      case PendingCountLoaded(:final count):
        return (
          SyncStatusState(phase: SyncStatusPhase.ready, pendingCount: count),
          null,
        );
      case PendingCountFailed():
        return (
          state.copyWith(phase: SyncStatusPhase.failed),
          null,
        );
    }
  }
}
