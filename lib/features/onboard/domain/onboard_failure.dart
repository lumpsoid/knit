/// Per-feature failure family for Onboard (result.md §9.3 — never a global
/// `AppFailure`). Carries the original [error] (and [stackTrace] when caught
/// from an exception) so the shell logs the real cause, not a re-typed summary.
sealed class OnboardFailure {
  const OnboardFailure(this.error, [this.stackTrace]);

  /// The underlying error — a caught exception, or a domain-condition message.
  final Object error;

  /// The stack trace from the caught exception, when there was one.
  final StackTrace? stackTrace;
}

/// Identity provisioning or the profile write failed.
class IdentityCreationFailure extends OnboardFailure {
  const IdentityCreationFailure(super.error, [super.stackTrace]);
}
