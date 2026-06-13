import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:knit/core/fcis_flutter/fcis_flutter.dart';
import 'package:knit/features/sync_status/domain/sync_status_read_repository.dart';
import 'package:knit/features/sync_status/presentation/sync_status_action.dart';
import 'package:knit/features/sync_status/presentation/sync_status_controller.dart';
import 'package:knit/features/sync_status/presentation/sync_status_effect.dart';
import 'package:knit/features/sync_status/presentation/sync_status_loop.dart';
import 'package:knit/features/sync_status/presentation/sync_status_shell.dart';
import 'package:knit/features/sync_status/presentation/sync_status_state.dart';
import 'package:knit/features/sync_status/presentation/sync_status_updater.dart';

/// Composition root for the sync marker (fcis.md §6.8).
class SyncStatusModule {
  SyncStatusModule({
    required SyncStatusReadRepository readRepository,
    Logger? logger,
  }) {
    final stateHolder =
        ValueListenableStateHolder<SyncStatusState>(const SyncStatusState());
    final shell = SyncStatusShell(
      readRepository: readRepository,
      logger: logger ?? Logger('knit.sync_status'),
    );
    final loop = SyncStatusLoop(
      stateHolder: stateHolder,
      updater: const SyncStatusUpdater(),
      effectRunner:
          ShellEffectRunner<SyncStatusEffect, SyncStatusAction>(shell: shell),
    );
    _controller = SyncStatusController(stateHolder: stateHolder, sink: loop);
  }

  late final SyncStatusController _controller;

  SyncStatusController get controller => _controller;
}
