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
    this.hasError = false,
  });

  final OnboardStep step;
  final String nickname;

  /// Populated on the reveal step (§5).
  final IdentityCard? identity;

  /// Whether the last Generate failed — drives the explain-step error banner.
  /// The cause is logged in the shell, not surfaced as text here.
  final bool hasError;

  bool get canContinueFromNickname => nickname.trim().isNotEmpty;

  OnboardState copyWith({
    OnboardStep? step,
    String? nickname,
    IdentityCard? identity,
    bool? hasError,
  }) => OnboardState(
    step: step ?? this.step,
    nickname: nickname ?? this.nickname,
    identity: identity ?? this.identity,
    hasError: hasError ?? this.hasError,
  );
}
