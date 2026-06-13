import 'package:fcis_core/fcis_core.dart';
import 'package:flutter/foundation.dart';
import 'package:knit/features/sync_status/presentation/sync_status_action.dart';
import 'package:knit/features/sync_status/presentation/sync_status_state.dart';

/// Thin controller (fcis.md §6.8). The sync marker emits no one-shot UI effects
/// (no navigation/snackbars), so — unlike the other features — it carries no
/// EffectEmitter: it exposes only read-only state plus an intent sink.
class SyncStatusController {
  SyncStatusController({
    required this.stateHolder,
    required ActionSink<SyncStatusAction> sink,
  }) : _sink = sink;

  final ValueListenable<SyncStatusState> stateHolder;
  final ActionSink<SyncStatusAction> _sink;

  void dispatch(SyncStatusAction action) => _sink.dispatch(action);
}
