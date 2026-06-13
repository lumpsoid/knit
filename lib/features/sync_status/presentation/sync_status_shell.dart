import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:knit/features/sync_status/domain/sync_status_read_repository.dart';
import 'package:knit/features/sync_status/presentation/sync_status_action.dart';
import 'package:knit/features/sync_status/presentation/sync_status_effect.dart';

/// Imperative shell for the sync marker (fcis.md §6.6). Unwraps the read Result
/// at the seam (result.md §9.3) into a success/failure Action. No UiEffects —
/// the marker only updates state.
class SyncStatusShell extends Shell<SyncStatusEffect, SyncStatusAction> {
  SyncStatusShell({
    required SyncStatusReadRepository readRepository,
    required Logger logger,
  })  : _read = readRepository,
        _log = logger;

  final SyncStatusReadRepository _read;
  final Logger _log;

  @override
  Future<void> run(
    SyncStatusEffect effect, {
    required void Function(SyncStatusAction) dispatch,
  }) async {
    switch (effect) {
      case LoadPendingCountEffect():
        final result = await _read.pendingCount();
        result.onTap(
          (count) => dispatch(PendingCountLoaded(count)),
          (failure) {
            _log.severe(
                'Pending count read failed', failure.error, failure.stackTrace);
            dispatch(const PendingCountFailed());
          },
        );
    }
  }
}
