import 'package:flutter/foundation.dart';
import 'package:knit/features/backup/domain/backup_models.dart';
import 'package:knit/features/onboard/domain/identity_card.dart';

/// The onboarding ceremony's steps: a welcome, then a nickname, then the
/// identity explanation + Generate, the generating moment, and the reveal. The
/// welcome also offers a restore from backup: the passphrase step, the
/// restoring moment, then the same reveal.
enum OnboardStep {
  welcome,
  nickname,
  explainIdentity,
  generating,
  restorePassphrase,
  restoring,
  reveal,
}

/// Why a restore from backup didn't go through.
enum OnboardRestoreError { unreadable, noIdentity, wrongPassphrase, failed }

@immutable
class OnboardState {
  const OnboardState({
    this.step = OnboardStep.welcome,
    this.nickname = '',
    this.identity,
    this.hasError = false,
    this.restoreBundle,
    this.restoreError,
    this.restored = false,
  });

  final OnboardStep step;
  final String nickname;

  /// Populated on the reveal step (§5).
  final IdentityCard? identity;

  /// Whether the last Generate failed — drives the explain-step error banner.
  /// The cause is logged in the shell, not surfaced as text here.
  final bool hasError;

  /// The picked backup, held while the user enters its passphrase.
  final BackupBundle? restoreBundle;

  /// Why the last restore attempt failed (shown on the welcome or passphrase
  /// step); null when there's nothing to report.
  final OnboardRestoreError? restoreError;

  /// Whether the revealed identity came from a backup (a "welcome back").
  final bool restored;

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
    restoreBundle: restoreBundle,
    restoreError: restoreError,
    restored: restored,
  );
}
