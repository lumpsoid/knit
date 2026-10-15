import 'package:flutter/foundation.dart';

/// Lifecycle of the sync marker's count read (fcis.md §6.1).
enum SyncStatusPhase { loading, ready, failed }

@immutable
class SyncStatusState {
  const SyncStatusState({
    this.phase = SyncStatusPhase.loading,
    this.pendingCount = 0,
  });

  final SyncStatusPhase phase;

  /// Local ops not yet acked by a relay (§6.6). Relay-less today, so this only
  /// grows; the view reads it calmly ("saved on this device").
  final int pendingCount;

  SyncStatusState copyWith({SyncStatusPhase? phase, int? pendingCount}) =>
      SyncStatusState(
        phase: phase ?? this.phase,
        pendingCount: pendingCount ?? this.pendingCount,
      );
}
