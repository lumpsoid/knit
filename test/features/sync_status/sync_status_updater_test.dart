import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/sync_status/presentation/sync_status_action.dart';
import 'package:knit/features/sync_status/presentation/sync_status_effect.dart';
import 'package:knit/features/sync_status/presentation/sync_status_state.dart';
import 'package:knit/features/sync_status/presentation/sync_status_updater.dart';

void main() {
  const updater = SyncStatusUpdater();

  test('ViewAttached requests a count read', () {
    final (next, effects) = updater.update(
      const SyncStatusState(),
      const ViewAttached(),
    );
    expect(next.phase, SyncStatusPhase.loading);
    expect(effects, const [LoadPendingCountEffect()]);
  });

  test('RefreshRequested keeps the last known count while loading', () {
    const prior = SyncStatusState(
      phase: SyncStatusPhase.ready,
      pendingCount: 3,
    );
    final (next, effects) = updater.update(prior, const RefreshRequested());
    expect(next.phase, SyncStatusPhase.loading);
    expect(next.pendingCount, 3); // reused — the view won't flicker
    expect(effects, const [LoadPendingCountEffect()]);
  });

  test('PendingCountLoaded becomes ready with the count', () {
    final (next, effects) = updater.update(
      const SyncStatusState(phase: SyncStatusPhase.loading),
      const PendingCountLoaded(5),
    );
    expect(next.phase, SyncStatusPhase.ready);
    expect(next.pendingCount, 5);
    expect(effects, isNull);
  });

  test('PendingCountFailed marks the marker failed without effects', () {
    final (next, effects) = updater.update(
      const SyncStatusState(phase: SyncStatusPhase.loading),
      const PendingCountFailed(),
    );
    expect(next.phase, SyncStatusPhase.failed);
    expect(effects, isNull);
  });
}
