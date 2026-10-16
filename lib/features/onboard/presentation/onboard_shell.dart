import 'dart:typed_data';

import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';
import 'package:knit/features/backup/domain/backup_failure.dart';
import 'package:knit/features/backup/domain/backup_import_repository.dart';
import 'package:knit/features/backup/domain/backup_models.dart';
import 'package:knit/features/backup/domain/backup_source_port.dart';
import 'package:knit/features/onboard/domain/onboard_identity_read_repository.dart';
import 'package:knit/features/onboard/domain/onboard_repository.dart';
import 'package:knit/features/onboard/presentation/onboard_action.dart';
import 'package:knit/features/onboard/presentation/onboard_effect.dart';
import 'package:knit/features/onboard/presentation/onboard_state.dart';
import 'package:knit/features/onboard/presentation/onboard_ui_effect.dart';

/// Imperative shell for Onboard (fcis.md §6.6). Unwraps the [OnboardRepository]
/// Result at the seam (result.md §9.3) — dispatching a success or failure
/// Action, never propagating the Result into the updater — and pushes the
/// enter-app UiEffect. A restore from backup picks a bundle, plans it, then
/// replaces the (empty) device with it and reads back the identity it brought.
class OnboardShell extends Shell<OnboardEffect, OnboardAction> {
  OnboardShell({
    required OnboardRepository repository,
    required OnboardIdentityReadRepository identityReadRepository,
    required BackupSourcePort backupSourcePort,
    required BackupImportRepository backupImportRepository,
    required EffectEmitter<OnboardUiEffect> effectEmitter,
    required Logger logger,
  }) : _repository = repository,
       _identityRead = identityReadRepository,
       _source = backupSourcePort,
       _import = backupImportRepository,
       _effectEmitter = effectEmitter,
       _log = logger;

  final OnboardRepository _repository;
  final OnboardIdentityReadRepository _identityRead;
  final BackupSourcePort _source;
  final BackupImportRepository _import;
  final EffectEmitter<OnboardUiEffect> _effectEmitter;
  final Logger _log;

  @override
  Future<void> run(
    OnboardEffect effect, {
    required void Function(OnboardAction) dispatch,
  }) async {
    switch (effect) {
      case CreateIdentityEffect(:final nickname):
        final result = await _repository.createIdentity(nickname);
        result.onTap((card) => dispatch(IdentityCreated(card)), (failure) {
          _log.severe(
            'Identity creation failed',
            failure.error,
            failure.stackTrace,
          );
          dispatch(const IdentityCreationFailed());
        });
      case EnterAppEffect():
        _effectEmitter.push(const OnboardEnterAppUiEffect());
      case PickBackupEffect():
        await _pickBackup(dispatch);
      case RestoreBackupEffect(:final bundle, :final passphrase):
        await _restore(bundle, passphrase, dispatch);
    }
  }

  Future<void> _pickBackup(void Function(OnboardAction) dispatch) async {
    final picked = await _source.pickArchive();
    final Uint8List bytes;
    switch (picked) {
      case Ok(value: null):
        dispatch(const RestorePickCancelled());
        return;
      case Ok(:final value?):
        bytes = value;
      case Failure(:final error):
        _log.severe('Backup pick failed', error.error, error.stackTrace);
        dispatch(const RestoreRejected(OnboardRestoreError.failed));
        return;
    }

    final planned = await _import.plan(bytes);
    switch (planned) {
      case Ok(value: RestorePlan(:final bundle, :final kind)):
        dispatch(switch (kind) {
          RestoreKind.replaceDevice => RestorePicked(bundle),
          // No identity here and none in the bundle — nothing to restore.
          RestoreKind.merge || RestoreKind.missingIdentity =>
            const RestoreRejected(OnboardRestoreError.noIdentity),
        });
      case Failure(error: BackupCorruptArchiveFailure()):
        dispatch(const RestoreRejected(OnboardRestoreError.unreadable));
      case Failure(:final error):
        _log.severe('Backup read failed', error.error, error.stackTrace);
        dispatch(const RestoreRejected(OnboardRestoreError.failed));
    }
  }

  Future<void> _restore(
    BackupBundle bundle,
    String passphrase,
    void Function(OnboardAction) dispatch,
  ) async {
    final restored = await _import.replaceDevice(bundle, passphrase);
    switch (restored) {
      case Ok():
        final card = await _identityRead.current();
        card.onTap((card) => dispatch(IdentityRestored(card)), (failure) {
          _log.severe(
            'Restored identity read failed',
            failure.error,
            failure.stackTrace,
          );
          dispatch(const RestoreRejected(OnboardRestoreError.failed));
        });
      case Failure(error: BackupWrongPassphraseFailure()):
        dispatch(const RestorePassphraseRejected());
      case Failure(error: BackupMissingIdentityFailure()):
        dispatch(const RestoreRejected(OnboardRestoreError.noIdentity));
      case Failure(:final error):
        _log.severe('Backup restore failed', error.error, error.stackTrace);
        dispatch(const RestoreRejected(OnboardRestoreError.failed));
    }
  }
}
