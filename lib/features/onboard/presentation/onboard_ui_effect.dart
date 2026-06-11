/// One-shot UI effects the shell pushes for the Onboard View (fcis.md §6.4).
sealed class OnboardUiEffect {
  const OnboardUiEffect();
}

/// Replace onboarding with the timeline.
class OnboardEnterAppUiEffect extends OnboardUiEffect {
  const OnboardEnterAppUiEffect();
}
