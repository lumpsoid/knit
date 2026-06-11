/// Async-work descriptors for Onboard (fcis.md §6.4).
sealed class OnboardEffect {
  const OnboardEffect();
}

/// Provision the identity + publish the profile for [nickname].
class CreateIdentityEffect extends OnboardEffect {
  const CreateIdentityEffect(this.nickname);
  final String nickname;
}

/// Leave onboarding for the timeline (shell pushes the navigate UiEffect).
class EnterAppEffect extends OnboardEffect {
  const EnterAppEffect();
}
