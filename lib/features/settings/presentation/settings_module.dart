import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:knit/core/fcis_flutter/fcis_flutter.dart';
import 'package:knit/features/backup/domain/backup_delivery_port.dart';
import 'package:knit/features/backup/domain/backup_export_repository.dart';
import 'package:knit/features/backup/domain/backup_import_repository.dart';
import 'package:knit/features/backup/domain/backup_save_port.dart';
import 'package:knit/features/backup/domain/backup_source_port.dart';
import 'package:knit/features/settings/domain/settings_read_repository.dart';
import 'package:knit/features/settings/domain/settings_wipe_repository.dart';
import 'package:knit/features/settings/domain/settings_write_repository.dart';
import 'package:knit/features/settings/presentation/settings_action.dart';
import 'package:knit/features/settings/presentation/settings_controller.dart';
import 'package:knit/features/settings/presentation/settings_effect.dart';
import 'package:knit/features/settings/presentation/settings_loop.dart';
import 'package:knit/features/settings/presentation/settings_shell.dart';
import 'package:knit/features/settings/presentation/settings_state.dart';
import 'package:knit/features/settings/presentation/settings_ui_effect.dart';
import 'package:knit/features/settings/presentation/settings_updater.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';

/// Composition root for Settings (fcis.md §6.8).
class SettingsModule {
  SettingsModule({
    required SettingsReadRepository readRepository,
    required SettingsWriteRepository writeRepository,
    required SettingsWipeRepository wipeRepository,
    required BackupExportRepository backupExportRepository,
    required BackupImportRepository backupImportRepository,
    required BackupDeliveryPort backupDeliveryPort,
    required BackupSavePort backupSavePort,
    required BackupSourcePort backupSourcePort,
    required TimelineChannelEmitter timelineChannel,
    Logger? logger,
  }) {
    final stateHolder =
        ValueListenableStateHolder<SettingsState>(const SettingsState());
    final effectEmitter = EffectEmitter<SettingsUiEffect>();
    final shell = SettingsShell(
      readRepository: readRepository,
      writeRepository: writeRepository,
      wipeRepository: wipeRepository,
      backupExportRepository: backupExportRepository,
      backupImportRepository: backupImportRepository,
      backupDeliveryPort: backupDeliveryPort,
      backupSavePort: backupSavePort,
      backupSourcePort: backupSourcePort,
      effectEmitter: effectEmitter,
      timelineChannel: timelineChannel,
      logger: logger ?? Logger('knit.settings'),
    );
    final loop = SettingsLoop(
      stateHolder: stateHolder,
      updater: const SettingsUpdater(),
      effectRunner:
          ShellEffectRunner<SettingsEffect, SettingsAction>(shell: shell),
    );
    _controller = SettingsController(
      stateHolder: stateHolder,
      effectEmitter: effectEmitter,
      sink: loop,
    );
  }

  late final SettingsController _controller;

  SettingsController get controller => _controller;
}
