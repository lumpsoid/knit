/// Failure family for the shared collection details (result.md §9.3). Carries
/// the original [error] (and [stackTrace] when caught from an exception) so the
/// caller logs the real cause, not a re-typed summary.
sealed class CollectionDetailsFailure {
  const CollectionDetailsFailure(this.error, [this.stackTrace]);

  /// The underlying error — a caught exception, or a domain-condition message.
  final Object error;

  /// The stack trace from the caught exception, when there was one.
  final StackTrace? stackTrace;
}

/// A local write (edit the title/description, set/clear the cover image) failed
/// to persist.
class CollectionDetailsWriteFailure extends CollectionDetailsFailure {
  const CollectionDetailsWriteFailure(super.error, [super.stackTrace]);
}
