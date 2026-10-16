import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/onboard/presentation/onboard_action.dart';
import 'package:knit/features/onboard/presentation/onboard_effect.dart';
import 'package:knit/features/onboard/presentation/onboard_state.dart';

/// Pure reducer for the onboarding ceremony (fcis.md §6.1/§6.5). Drives the
/// step machine; the keypair generation + profile write is a single effect, as
/// are picking a backup and restoring it.
class OnboardUpdater
    implements Updater<OnboardState, OnboardAction, OnboardEffect> {
  const OnboardUpdater();

  @override
  (OnboardState, List<OnboardEffect>?) update(
    OnboardState state,
    OnboardAction action,
  ) {
    switch (action) {
      case ViewAttached():
        // Each mount is a fresh ceremony — after "Reset identity" the cached
        // controller may still hold the last run's reveal.
        return (const OnboardState(), null);
      case DeactivateFeature():
        return (state, null);

      case GetStartedTapped():
        // Leaving the welcome drops any restore error shown there.
        return (
          OnboardState(step: OnboardStep.nickname, nickname: state.nickname),
          null,
        );

      case NicknameChanged(:final value):
        return (state.copyWith(nickname: value), null);

      case NicknameSubmitted():
        if (!state.canContinueFromNickname) return (state, null);
        return (state.copyWith(step: OnboardStep.explainIdentity), null);

      case BackTapped():
        return (_back(state), null);

      case GenerateIdentityTapped():
        // Fresh state clears any prior error and shows the generating moment.
        return (
          OnboardState(step: OnboardStep.generating, nickname: state.nickname),
          [CreateIdentityEffect(state.nickname.trim())],
        );

      case IdentityCreated(:final card):
        return (state.copyWith(step: OnboardStep.reveal, identity: card), null);

      case IdentityCreationFailed():
        return (
          OnboardState(
            step: OnboardStep.explainIdentity,
            nickname: state.nickname,
            hasError: true,
          ),
          null,
        );

      case EnterAppTapped():
        return (state, const [EnterAppEffect()]);

      case RestoreTapped():
        return (const OnboardState(), const [PickBackupEffect()]);

      case RestorePickCancelled():
        return (state, null);

      case RestorePicked(:final bundle):
        return (
          OnboardState(
            step: OnboardStep.restorePassphrase,
            restoreBundle: bundle,
          ),
          null,
        );

      case RestoreRejected(:final error):
        return (OnboardState(restoreError: error), null);

      case RestorePassphraseSubmitted(:final passphrase):
        final bundle = state.restoreBundle;
        if (bundle == null || passphrase.isEmpty) return (state, null);
        return (
          OnboardState(step: OnboardStep.restoring, restoreBundle: bundle),
          [RestoreBackupEffect(bundle, passphrase)],
        );

      case RestorePassphraseRejected():
        return (
          OnboardState(
            step: OnboardStep.restorePassphrase,
            restoreBundle: state.restoreBundle,
            restoreError: OnboardRestoreError.wrongPassphrase,
          ),
          null,
        );

      case IdentityRestored(:final card):
        return (
          OnboardState(
            step: OnboardStep.reveal,
            nickname: card.nickname,
            identity: card,
            restored: true,
          ),
          null,
        );
    }
  }

  OnboardState _back(OnboardState state) => switch (state.step) {
    OnboardStep.nickname => state.copyWith(step: OnboardStep.welcome),
    OnboardStep.explainIdentity => state.copyWith(step: OnboardStep.nickname),
    OnboardStep.restorePassphrase => const OnboardState(),
    _ => state,
  };
}
