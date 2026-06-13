/// Per-feature failure family for the Profile screen (result.md §9.3). Carries
/// the original [error] (and [stackTrace] when caught from an exception) so the
/// shell logs the real cause, not a re-typed summary.
sealed class ProfileFailure {
  const ProfileFailure(this.error, [this.stackTrace]);

  /// The underlying error — a caught exception, or a domain-condition message.
  final Object error;

  /// The stack trace from the caught exception, when there was one.
  final StackTrace? stackTrace;
}

/// Reading the device's `profile` record (§7.4.7) failed — or it is missing.
class ProfileLoadFailure extends ProfileFailure {
  const ProfileLoadFailure(super.error, [super.stackTrace]);
}

/// Renaming (a signed `profile` edit, §6.8) failed.
class ProfileRenameFailure extends ProfileFailure {
  const ProfileRenameFailure(super.error, [super.stackTrace]);
}
