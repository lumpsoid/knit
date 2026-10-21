import 'dart:typed_data';

import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';
import 'package:knit/core/files/domain/domain.dart';
import 'package:knit/features/backup/domain/backup_export_repository.dart';
import 'package:knit/features/backup/domain/backup_failure.dart';
import 'package:knit/features/backup/domain/backup_import_repository.dart';
import 'package:knit/features/backup/domain/backup_models.dart';
import 'package:knit/features/settings/domain/identity_reset_confirmation.dart';
import 'package:knit/features/settings/domain/settings_identity_read_repository.dart';
import 'package:knit/features/settings/domain/settings_identity_reset_repository.dart';
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
/// The data-management seam (§4 Data subpage): export builds the bundle (data +
/// passphrase-sealed keypair) and delivers it (share or save-to-file); import
/// picks a bundle and merges it, or — when it belongs to another identity —
/// holds it until the user confirms replacing this device; wipe deletes the
/// data; reset deletes the data and the keypair. Each ends by dispatching
/// [DataActionFinished] so the busy spinner clears.
class SettingsShell extends Shell<SettingsEffect, SettingsAction> {
  SettingsShell({
    required SettingsReadRepository readRepository,
    required SettingsWriteRepository writeRepository,
    required SettingsWipeRepository wipeRepository,
    required SettingsIdentityReadRepository identityReadRepository,
    required SettingsIdentityResetRepository identityResetRepository,
    required BackupExportRepository backupExportRepository,
    required BackupImportRepository backupImportRepository,
    required FileDeliveryPort backupDeliveryPort,
    required FileSavePort backupSavePort,
    required FileSourcePort backupSourcePort,
    required EffectEmitter<SettingsUiEffect> effectEmitter,
    required TimelineChannelEmitter timelineChannel,
    required Logger logger,
  }) : _read = readRepository,
       _write = writeRepository,
       _wipe = wipeRepository,
       _identityRead = identityReadRepository,
       _identityReset = identityResetRepository,
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
  final SettingsIdentityReadRepository _identityRead;
  final SettingsIdentityResetRepository _identityReset;
  final BackupExportRepository _export;
  final BackupImportRepository _import;
  final FileDeliveryPort _delivery;
  final FileSavePort _save;
  final FileSourcePort _source;
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
            _log.severe(
              'Preferences load failed',
              failure.error,
              failure.stackTrace,
            );
            dispatch(const PreferencesLoadFailed());
          },
        );
      case SavePreferencesEffect(:final preferences):
        final result = await _write.save(preferences);
        result.onTap((saved) => dispatch(PreferencesSaved(saved)), (failure) {
          // The optimistic state already reflects the choice; only the
          // persisted copy was lost, so we log rather than alarm the user.
          _log.severe(
            'Preferences save failed',
            failure.error,
            failure.stackTrace,
          );
          dispatch(const PreferencesSaveFailed());
        });
      case RunExportEffect(:final destination, :final passphrase):
        await _runExport(destination, passphrase, dispatch);
      case RunReplaceDeviceEffect(:final bundle, :final passphrase):
        await _runReplaceDevice(bundle, passphrase, dispatch);
      case RunResetIdentityEffect():
        await _runResetIdentity(dispatch);
      case RunDataActionEffect(:final action):
        switch (action) {
          case DataAction.importData:
            await _runImport(dispatch);
          case DataAction.wipeData:
            await _runWipe(dispatch);
          case DataAction.resetIdentity:
            await _askResetConfirmation(dispatch);
          case DataAction.exportData:
            // Export runs via RunExportEffect (it needs a passphrase first).
            dispatch(const DataActionFinished());
        }
    }
  }

  /// Build the backup bundle, then deliver it to [destination]. Always clears the
  /// spinner via [DataActionFinished], whatever the outcome.
  Future<void> _runExport(
    BackupDestination destination,
    String passphrase,
    void Function(SettingsAction) dispatch,
  ) async {
    final exported = await _export.exportAll(passphrase);
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
        _effectEmitter.push(
          const SettingsBackupFailedUiEffect(DataAction.exportData),
        );
    }
    dispatch(const DataActionFinished());
  }

  Future<void> _deliverShare(OutgoingFile archive) async {
    final shared = await _delivery.share(archive);
    switch (shared) {
      case Ok():
        _effectEmitter.push(
          const SettingsBackupExportedUiEffect(BackupDestination.share),
        );
      case Failure(:final error):
        _log.severe('Backup share failed', error.error, error.stackTrace);
        _effectEmitter.push(
          const SettingsBackupFailedUiEffect(DataAction.exportData),
        );
    }
  }

  Future<void> _deliverSave(OutgoingFile archive) async {
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
        _effectEmitter.push(
          const SettingsBackupFailedUiEffect(DataAction.exportData),
        );
    }
  }

  /// Pick a bundle and plan its restore: this identity's own bundle (or an old
  /// one without a keypair) merges at once; another identity's is held while
  /// the user confirms replacing the device. A cancelled pick is silent.
  /// Always clears the spinner via [DataActionFinished].
  Future<void> _runImport(void Function(SettingsAction) dispatch) async {
    final picked = await _source.pick(extensions: const ['zip']);
    switch (picked) {
      case Ok(value: final bytes):
        if (bytes != null) await _planRestore(bytes, dispatch);
      case Failure(:final error):
        _log.severe('Backup pick failed', error.error, error.stackTrace);
        _importFailed();
    }
    dispatch(const DataActionFinished());
  }

  Future<void> _planRestore(
    Uint8List bytes,
    void Function(SettingsAction) dispatch,
  ) async {
    final planned = await _import.plan(bytes);
    switch (planned) {
      case Ok(value: RestorePlan(:final bundle, :final kind)):
        switch (kind) {
          case RestoreKind.merge:
            await _runMerge(bundle);
          case RestoreKind.replaceDevice:
            dispatch(RestoreAwaitingPassphrase(bundle));
            _effectEmitter.push(
              SettingsConfirmReplaceUiEffect(createdAtMs: bundle.createdAtMs),
            );
          case RestoreKind.missingIdentity:
            // Unreachable here — Settings only opens with an identity.
            _log.warning('Restore planned without a device identity');
            _importFailed();
        }
      case Failure(:final error):
        _log.severe('Backup read failed', error.error, error.stackTrace);
        _importFailed();
    }
  }

  Future<void> _runMerge(BackupBundle bundle) async {
    final restored = await _import.merge(bundle);
    switch (restored) {
      case Ok(value: final summary):
        // A restore changed the graph — nudge the Timeline (mounted under
        // Settings) to re-read the home feed (cross_feature.md §3).
        _timelineChannel.emit(const RefreshChannelEvent());
        _effectEmitter.push(SettingsBackupImportedUiEffect(summary));
      case Failure(:final error):
        _log.severe('Backup import failed', error.error, error.stackTrace);
        _importFailed();
    }
  }

  /// Erase this device and restore [bundle] onto it. A wrong passphrase keeps
  /// the bundle held and asks again; anything else settles the restore.
  Future<void> _runReplaceDevice(
    BackupBundle bundle,
    String passphrase,
    void Function(SettingsAction) dispatch,
  ) async {
    final restored = await _import.replaceDevice(bundle, passphrase);
    switch (restored) {
      case Ok(value: final summary):
        dispatch(const RestoreSettled());
        _timelineChannel.emit(const RefreshChannelEvent());
        _effectEmitter.push(SettingsDeviceReplacedUiEffect(summary));
      case Failure(error: BackupWrongPassphraseFailure()):
        _effectEmitter.push(
          SettingsConfirmReplaceUiEffect(
            createdAtMs: bundle.createdAtMs,
            wrongPassphrase: true,
          ),
        );
      case Failure(:final error):
        _log.severe('Device replace failed', error.error, error.stackTrace);
        dispatch(const RestoreSettled());
        // The device may now be partly erased — refresh what's left.
        _timelineChannel.emit(const RefreshChannelEvent());
        _importFailed();
    }
    dispatch(const DataActionFinished());
  }

  void _importFailed() => _effectEmitter.push(
    const SettingsBackupFailedUiEffect(DataAction.importData),
  );

  /// Read the nickname the user must type to confirm the reset.
  Future<void> _askResetConfirmation(
    void Function(SettingsAction) dispatch,
  ) async {
    final nickname = await _identityRead.nickname();
    switch (nickname) {
      case Ok(:final value):
        _effectEmitter.push(
          SettingsConfirmResetUiEffect(IdentityResetConfirmation(value)),
        );
      case Failure(:final error):
        _log.severe('Identity read failed', error.error, error.stackTrace);
        _effectEmitter.push(const SettingsResetFailedUiEffect());
    }
    dispatch(const DataActionFinished());
  }

  /// Erase the data and the keypair (the UI already confirmed it).
  Future<void> _runResetIdentity(void Function(SettingsAction) dispatch) async {
    final result = await _identityReset.reset();
    _timelineChannel.emit(const RefreshChannelEvent());
    switch (result) {
      case Ok():
        _effectEmitter.push(const SettingsIdentityResetUiEffect());
      case Failure(:final error):
        _log.severe('Reset identity failed', error.error, error.stackTrace);
        _effectEmitter.push(const SettingsResetFailedUiEffect());
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
