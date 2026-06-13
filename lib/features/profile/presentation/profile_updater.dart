import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/profile/presentation/profile_action.dart';
import 'package:knit/features/profile/presentation/profile_effect.dart';
import 'package:knit/features/profile/presentation/profile_state.dart';

/// Pure reducer for the Profile screen (fcis.md §6.1). No business `if`s — the
/// rename validation lives in the View (non-empty) and the identity shape is
/// decided by the domain.
class ProfileUpdater
    implements Updater<ProfileState, ProfileAction, ProfileEffect> {
  const ProfileUpdater();

  @override
  (ProfileState, List<ProfileEffect>?) update(
    ProfileState state,
    ProfileAction action,
  ) {
    switch (action) {
      case ViewAttached():
      case RefreshRequested():
        // Keep the last known identity while refreshing so the view doesn't
        // flicker on retry.
        return (
          state.copyWith(phase: ProfilePhase.loading),
          const [LoadProfileEffect()],
        );
      case ProfileLoaded(:final profile):
        return (
          state.copyWith(
            phase: ProfilePhase.ready,
            profile: profile,
            isSaving: false,
          ),
          null,
        );
      case ProfileLoadFailed():
        return (state.copyWith(phase: ProfilePhase.failed), null);
      case RenameRequested(:final nickname):
        return (
          state.copyWith(isSaving: true),
          [RenameProfileEffect(nickname)],
        );
      case RenameSucceeded(:final profile):
        return (
          state.copyWith(
            phase: ProfilePhase.ready,
            profile: profile,
            isSaving: false,
          ),
          null,
        );
      case RenameFailed():
        return (state.copyWith(isSaving: false), null);
      case DeactivateFeature():
        return (state.copyWith(isSaving: false), null);
    }
  }
}
