import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';
import 'package:knit/features/backup/domain/backup_delivery_port.dart';
import 'package:knit/features/backup/domain/backup_export_repository.dart';
import 'package:knit/features/backup/domain/backup_import_repository.dart';
import 'package:knit/features/backup/domain/backup_models.dart';
import 'package:knit/features/backup/domain/backup_save_port.dart';
import 'package:knit/features/backup/domain/backup_source_port.dart';
import 'package:knit/features/settings/domain/settings_read_repository.dart';
import 'package:knit/features/settings/domain/settings_wipe_repository.dart';
import 'package:knit/features/settings/domain/settings_write_repository.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';
import 'package:knit/features/settings/presentation/settings_action.dart';
import 'package:knit/features/settings/presentation/settings_effect.dart';
import 'package:knit/features/settings/presentation/settings_ui_effect.dart';

/// Imperative shell for Settings (fcis.md §6.6). Unwraps the read/write Results
/// at the seam (result.md §9.3) into success/failure Actions / UiEffects; the
/// updater never sees a Result.
///
/// The data-management seam (§4 Data subpage): export builds the bundle and
/// delivers it (share or save-to-file), import picks + restores it, and wipe
/// deletes every collection/card/link on the device; all three end by
/// dispatching [DataActionFinished] so the busy spinner clears. The
/// identity export/reset actions are still placeholders.
class SettingsShell extends Shell<SettingsEffect, SettingsAction> {
  SettingsShell({
    required SettingsReadRepository readRepository,
    required SettingsWriteRepository writeRepository,
    required SettingsWipeRepository wipeRepository,
    required BackupExportRepository backupExportRepository,
    required BackupImportRepository backupImportRepository,
    required BackupDeliveryPort backupDeliveryPort,
    required BackupSavePort backupSavePort,
    required BackupSourcePort backupSourcePort,
    required EffectEmitter<SettingsUiEffect> effectEmitter,
    required TimelineChannelEmitter timelineChannel,
    required Logger logger,
  })  : _read = readRepository,
        _write = writeRepository,
        _wipe = wipeRepository,
        _export = backupExportRepository,
        _import = backupImportRepository,
        _delivery = backupDeliveryPort,
        _save = backupSavePort,
        _source = backupSourcePort,
        _effectEmitter = effectEmitter,
        _timelineChannel = timelineChannel,
        _log = logger;

  final SettingsReadRepository _read;
  final SettingsWriteRepository _write;
  final SettingsWipeRepository _wipe;
  final BackupExportRepository _export;
  final BackupImportRepository _import;
  final BackupDeliveryPort _delivery;
  final BackupSavePort _save;
  final BackupSourcePort _source;
  final EffectEmitter<SettingsUiEffect> _effectEmitter;
  final TimelineChannelEmitter _timelineChannel;
  final Logger _log;

  @override
  Future<void> run(
    SettingsEffect effect, {
    required void Function(SettingsAction) dispatch,
  }) async {
    switch (effect) {
      case LoadPreferencesEffect():
        final result = await _read.load();
        result.onTap(
          (preferences) => dispatch(PreferencesLoaded(preferences)),
          (failure) {
            _log.severe('Preferences load failed', failure.error,
                failure.stackTrace);
            dispatch(const PreferencesLoadFailed());
          },
        );
      case SavePreferencesEffect(:final preferences):
        final result = await _write.save(preferences);
        result.onTap(
          (saved) => dispatch(PreferencesSaved(saved)),
          (failure) {
            // The optimistic state already reflects the choice; only the
            // persisted copy was lost, so we log rather than alarm the user.
            _log.severe('Preferences save failed', failure.error,
                failure.stackTrace);
            dispatch(const PreferencesSaveFailed());
          },
        );
      case RunExportEffect(:final destination):
        await _runExport(destination, dispatch);
      case RunDataActionEffect(:final action):
        switch (action) {
          case DataAction.importData:
            await _runImport(dispatch);
          case DataAction.wipeData:
            await _runWipe(dispatch);
          case DataAction.exportData:
          case DataAction.exportIdentity:
          case DataAction.resetIdentity:
            // Export is handled via RunExportEffect; the rest are placeholders.
            _effectEmitter.push(SettingsComingSoonUiEffect(action));
        }
    }
  }

  /// Build the backup bundle, then deliver it to [destination]. Always clears the
  /// spinner via [DataActionFinished], whatever the outcome.
  Future<void> _runExport(
    BackupDestination destination,
    void Function(SettingsAction) dispatch,
  ) async {
    final exported = await _export.exportAll();
    switch (exported) {
      case Ok(value: final archive):
        switch (destination) {
          case BackupDestination.share:
            await _deliverShare(archive);
          case BackupDestination.saveFile:
            await _deliverSave(archive);
        }
      case Failure(:final error):
        _log.severe('Backup export failed', error.error, error.stackTrace);
        _effectEmitter
            .push(const SettingsBackupFailedUiEffect(DataAction.exportData));
    }
    dispatch(const DataActionFinished());
  }

  Future<void> _deliverShare(BackupArchive archive) async {
    final shared = await _delivery.share(archive);
    switch (shared) {
      case Ok():
        _effectEmitter.push(
          const SettingsBackupExportedUiEffect(BackupDestination.share),
        );
      case Failure(:final error):
        _log.severe('Backup share failed', error.error, error.stackTrace);
        _effectEmitter
            .push(const SettingsBackupFailedUiEffect(DataAction.exportData));
    }
  }

  Future<void> _deliverSave(BackupArchive archive) async {
    final result = await _save.save(archive);
    switch (result) {
      case Ok(value: final didSave):
        if (didSave) {
          _effectEmitter.push(
            const SettingsBackupExportedUiEffect(BackupDestination.saveFile),
          );
        }
        // A cancelled save dialog is silent — no error, no confirmation.
      case Failure(:final error):
        _log.severe('Backup save failed', error.error, error.stackTrace);
        _effectEmitter
            .push(const SettingsBackupFailedUiEffect(DataAction.exportData));
    }
  }

  /// Pick a bundle, then replay it through the store. A cancelled pick is silent.
  /// Always clears the spinner via [DataActionFinished].
  Future<void> _runImport(void Function(SettingsAction) dispatch) async {
    final picked = await _source.pickArchive();
    switch (picked) {
      case Ok(value: final bytes):
        if (bytes != null) {
          final restored = await _import.importArchive(bytes);
          switch (restored) {
            case Ok(value: final summary):
              // A restore changed the graph — nudge the Timeline (mounted under
              // Settings) to re-read the home feed (cross_feature.md §3).
              _timelineChannel.emit(const RefreshChannelEvent());
              _effectEmitter.push(SettingsBackupImportedUiEffect(summary));
            case Failure(:final error):
              _log.severe(
                  'Backup import failed', error.error, error.stackTrace);
              _effectEmitter.push(
                const SettingsBackupFailedUiEffect(DataAction.importData),
              );
          }
        }
      case Failure(:final error):
        _log.severe('Backup pick failed', error.error, error.stackTrace);
        _effectEmitter
            .push(const SettingsBackupFailedUiEffect(DataAction.importData));
    }
    dispatch(const DataActionFinished());
  }

  /// Delete every collection/card/link on the device (the UI already confirmed
  /// the danger action). Always clears the spinner via [DataActionFinished].
  Future<void> _runWipe(void Function(SettingsAction) dispatch) async {
    final result = await _wipe.wipe();
    switch (result) {
      case Ok():
        // The graph is now empty — nudge the Timeline to re-read so it doesn't
        // keep showing the wiped collections (cross_feature.md §3).
        _timelineChannel.emit(const RefreshChannelEvent());
        _effectEmitter.push(const SettingsDataWipedUiEffect());
      case Failure(:final error):
        _log.severe('Wipe data failed', error.error, error.stackTrace);
        _effectEmitter.push(const SettingsWipeFailedUiEffect());
    }
    dispatch(const DataActionFinished());
  }
}
