import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/sync_status/presentation/sync_status_indicator.dart';
import 'package:knit/features/sync_status/presentation/sync_status_state.dart';

void main() {
  test('zero pending reads as all saved, calm icon', () {
    final view = syncStatusPresentation(
      const SyncStatusState(phase: SyncStatusPhase.ready),
    );
    expect(view.icon, Icons.cloud_done_outlined);
    expect(view.tooltip, 'All changes saved');
  });

  test('one pending change reads in the singular, never alarming', () {
    final view = syncStatusPresentation(
      const SyncStatusState(phase: SyncStatusPhase.ready, pendingCount: 1),
    );
    expect(view.icon, Icons.save_outlined);
    expect(view.tooltip, '1 change saved on this device — not yet shared');
  });

  test('many pending changes read in the plural', () {
    final view = syncStatusPresentation(
      const SyncStatusState(phase: SyncStatusPhase.ready, pendingCount: 4),
    );
    expect(view.tooltip, '4 changes saved on this device — not yet shared');
  });

  test('loading reuses the last known count (no flicker)', () {
    final view = syncStatusPresentation(
      const SyncStatusState(phase: SyncStatusPhase.loading, pendingCount: 2),
    );
    expect(view.icon, Icons.save_outlined);
    expect(view.tooltip, contains('2 changes'));
  });

  test('failure is unobtrusive, not an alarm', () {
    final view = syncStatusPresentation(
      const SyncStatusState(phase: SyncStatusPhase.failed),
    );
    expect(view.icon, Icons.cloud_off_outlined);
    expect(view.tooltip, 'Sync status unavailable');
  });
}
