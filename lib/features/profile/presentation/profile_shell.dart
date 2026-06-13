import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:knit/features/profile/domain/profile_read_repository.dart';
import 'package:knit/features/profile/domain/profile_write_repository.dart';
import 'package:knit/features/profile/presentation/profile_action.dart';
import 'package:knit/features/profile/presentation/profile_effect.dart';
import 'package:knit/features/profile/presentation/profile_ui_effect.dart';

/// Imperative shell for the Profile screen (fcis.md §6.6). Unwraps the read/
/// write Results at the seam (result.md §9.3) into success/failure Actions, and
/// pushes the rename-failed message UiEffect; the updater never sees a Result.
class ProfileShell extends Shell<ProfileEffect, ProfileAction> {
  ProfileShell({
    required ProfileReadRepository readRepository,
    required ProfileWriteRepository writeRepository,
    required EffectEmitter<ProfileUiEffect> effectEmitter,
    required Logger logger,
  })  : _read = readRepository,
        _write = writeRepository,
        _effectEmitter = effectEmitter,
        _log = logger;

  final ProfileReadRepository _read;
  final ProfileWriteRepository _write;
  final EffectEmitter<ProfileUiEffect> _effectEmitter;
  final Logger _log;

  @override
  Future<void> run(
    ProfileEffect effect, {
    required void Function(ProfileAction) dispatch,
  }) async {
    switch (effect) {
      case LoadProfileEffect():
        final result = await _read.load();
        result.onTap(
          (profile) => dispatch(ProfileLoaded(profile)),
          (failure) {
            _log.severe(
                'Profile load failed', failure.error, failure.stackTrace);
            dispatch(const ProfileLoadFailed());
          },
        );
      case RenameProfileEffect(:final nickname):
        final result = await _write.rename(nickname);
        result.onTap(
          (profile) => dispatch(RenameSucceeded(profile)),
          (failure) {
            _log.severe('Profile rename failed', failure.error,
                failure.stackTrace);
            _effectEmitter
                .push(const ProfileShowMessageUiEffect(ProfileMessage.renameFailed));
            dispatch(const RenameFailed());
          },
        );
    }
  }
}
