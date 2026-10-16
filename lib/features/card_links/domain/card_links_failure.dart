/// Failure family for the shared card links (result.md §9.3). Carries the
/// original [error] (and [stackTrace] when caught from an exception) so the
/// caller logs the real cause, not a re-typed summary.
sealed class CardLinksFailure {
  const CardLinksFailure(this.error, [this.stackTrace]);

  /// The underlying error — a caught exception, or a domain-condition message.
  final Object error;

  /// The stack trace from the caught exception, when there was one.
  final StackTrace? stackTrace;
}

/// Reading the link targets from the projection failed.
class CardLinksReadFailure extends CardLinksFailure {
  const CardLinksReadFailure(super.error, [super.stackTrace]);
}

/// A link write (add / remove) failed to persist.
class CardLinksWriteFailure extends CardLinksFailure {
  const CardLinksWriteFailure(super.error, [super.stackTrace]);
}
