import 'package:flutter/foundation.dart';
import 'package:knit/features/onboard/domain/identity_card.dart';

/// The onboarding ceremony's steps: a welcome, then a nickname, then the
/// identity explanation + Generate, the generating moment, and the reveal.
enum OnboardStep { welcome, nickname, explainIdentity, generating, reveal }

@immutable
class OnboardState {
  const OnboardState({
    this.step = OnboardStep.welcome,
    this.nickname = '',
    this.identity,
    this.errorMessage,
  });

  final OnboardStep step;
  final String nickname;

  /// Populated on the reveal step (§5).
  final IdentityCard? identity;

  /// Surfaced on the explain step after a failed Generate.
  final String? errorMessage;

  bool get canContinueFromNickname => nickname.trim().isNotEmpty;

  OnboardState copyWith({
    OnboardStep? step,
    String? nickname,
    IdentityCard? identity,
    String? errorMessage,
  }) =>
      OnboardState(
        step: step ?? this.step,
        nickname: nickname ?? this.nickname,
        identity: identity ?? this.identity,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}
