/// Per-feature failure family for Onboard (result.md §9.3 — never a global
/// `AppFailure`).
sealed class OnboardFailure {
  const OnboardFailure();
}

/// Identity provisioning or the profile write failed.
class IdentityCreationFailure extends OnboardFailure {
  const IdentityCreationFailure(this.cause);
  final String cause;
}
