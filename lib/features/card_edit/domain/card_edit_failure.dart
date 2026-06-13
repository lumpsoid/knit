/// Per-feature failure family for the Card Edit page (result.md §9.3). Each
/// variant carries the original [error] (and [stackTrace] when caught from an
/// exception) so the shell logs the real cause, not a re-typed summary.
sealed class CardEditFailure {
  const CardEditFailure(this.error, [this.stackTrace]);

  /// The underlying error — a caught exception, or a domain-condition message.
  final Object error;

  /// The stack trace from the caught exception, when there was one.
  final StackTrace? stackTrace;
}

/// A local write (edit card content, add/remove a link, set/clear the image)
/// failed to persist.
class CardEditWriteFailure extends CardEditFailure {
  const CardEditWriteFailure(super.error, [super.stackTrace]);
}

/// A read failed (loading the card's links or the link-target tree).
class CardEditReadFailure extends CardEditFailure {
  const CardEditReadFailure(super.error, [super.stackTrace]);
}
