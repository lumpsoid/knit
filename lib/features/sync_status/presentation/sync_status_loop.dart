import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/sync_status/presentation/sync_status_action.dart';
import 'package:knit/features/sync_status/presentation/sync_status_effect.dart';
import 'package:knit/features/sync_status/presentation/sync_status_state.dart';

/// The sync-marker FCIS loop (fcis.md §6.8) — super-params only, no logic.
class SyncStatusLoop
    extends FcisLoop<SyncStatusState, SyncStatusAction, SyncStatusEffect> {
  SyncStatusLoop({
    required super.stateHolder,
    required super.updater,
    required super.effectRunner,
  });
}
