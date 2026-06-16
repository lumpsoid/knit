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
    expect(view.label, SyncStatusLabel.allSaved);
  });

  test('one pending change reads as pending, carrying its count', () {
    final view = syncStatusPresentation(
      const SyncStatusState(phase: SyncStatusPhase.ready, pendingCount: 1),
    );
    expect(view.icon, Icons.cloud_upload_outlined);
    expect(view.label, SyncStatusLabel.pending);
    expect(view.pendingCount, 1);
  });

  test('many pending changes carry their count for the localized plural', () {
    final view = syncStatusPresentation(
      const SyncStatusState(phase: SyncStatusPhase.ready, pendingCount: 4),
    );
    expect(view.label, SyncStatusLabel.pending);
    expect(view.pendingCount, 4);
  });

  test('loading reuses the last known count (no flicker)', () {
    final view = syncStatusPresentation(
      const SyncStatusState(phase: SyncStatusPhase.loading, pendingCount: 2),
    );
    expect(view.icon, Icons.cloud_upload_outlined);
    expect(view.label, SyncStatusLabel.pending);
    expect(view.pendingCount, 2);
  });

  test('failure is unobtrusive, not an alarm', () {
    final view = syncStatusPresentation(
      const SyncStatusState(phase: SyncStatusPhase.failed),
    );
    expect(view.icon, Icons.cloud_off_outlined);
    expect(view.label, SyncStatusLabel.unavailable);
  });
}
