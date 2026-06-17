/// Per-feature failure family for the Collection Edit page (result.md §9.3). Each
/// variant carries the original [error] (and [stackTrace] when caught from an
/// exception) so the shell logs the real cause, not a re-typed summary.
sealed class CollectionEditFailure {
  const CollectionEditFailure(this.error, [this.stackTrace]);

  /// The underlying error — a caught exception, or a domain-condition message.
  final Object error;

  /// The stack trace from the caught exception, when there was one.
  final StackTrace? stackTrace;
}

/// A local write (edit the title/description, set/clear the cover image) failed
/// to persist.
class CollectionEditWriteFailure extends CollectionEditFailure {
  const CollectionEditWriteFailure(super.error, [super.stackTrace]);
}
