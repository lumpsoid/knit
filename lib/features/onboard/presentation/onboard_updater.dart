import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/onboard/presentation/onboard_action.dart';
import 'package:knit/features/onboard/presentation/onboard_effect.dart';
import 'package:knit/features/onboard/presentation/onboard_state.dart';

/// Pure reducer for the onboarding ceremony (fcis.md §6.1/§6.5). Drives the
/// step machine; the keypair generation + profile write is a single effect.
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
      case DeactivateFeature():
        return (state, null);

      case GetStartedTapped():
        return (state.copyWith(step: OnboardStep.nickname), null);

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
          OnboardState(
            step: OnboardStep.generating,
            nickname: state.nickname,
          ),
          [CreateIdentityEffect(state.nickname.trim())],
        );

      case IdentityCreated(:final card):
        return (
          state.copyWith(step: OnboardStep.reveal, identity: card),
          null,
        );

      case IdentityCreationFailed(:final message):
        return (
          OnboardState(
            step: OnboardStep.explainIdentity,
            nickname: state.nickname,
            errorMessage: message,
          ),
          null,
        );

      case EnterAppTapped():
        return (state, const [EnterAppEffect()]);
    }
  }

  OnboardState _back(OnboardState state) => switch (state.step) {
        OnboardStep.nickname => state.copyWith(step: OnboardStep.welcome),
        OnboardStep.explainIdentity =>
          state.copyWith(step: OnboardStep.nickname),
        _ => state,
      };
}
