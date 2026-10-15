/// Per-feature failure family for the Collection Media overview (result.md
/// §9.3). Each variant carries the original [error] (and [stackTrace] when caught
/// from an exception) so the shell logs the real cause.
sealed class CollectionMediaFailure {
  const CollectionMediaFailure(this.error, [this.stackTrace]);

  /// The underlying error — a caught exception, or a domain-condition message.
  final Object error;

  /// The stack trace from the caught exception, when there was one.
  final StackTrace? stackTrace;
}

/// Reading the collection's media cards from the projection failed.
class CollectionMediaLoadFailure extends CollectionMediaFailure {
  const CollectionMediaLoadFailure(super.error, [super.stackTrace]);
}
