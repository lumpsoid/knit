/// Per-feature failure family for the Collection screen (result.md §9.3). Each
/// variant carries the original [error] (and [stackTrace] when caught from an
/// exception) so the shell logs the real cause, not a re-typed summary.
sealed class CollectionFailure {
  const CollectionFailure(this.error, [this.stackTrace]);

  /// The underlying error — a caught exception, or a domain-condition message.
  final Object error;

  /// The stack trace from the caught exception, when there was one.
  final StackTrace? stackTrace;
}

/// Reading the collection header + feed from the projection failed.
class CollectionLoadFailure extends CollectionFailure {
  const CollectionLoadFailure(super.error, [super.stackTrace]);
}

/// A local write (create/edit/delete/reorder/link) failed to persist.
class CollectionWriteFailure extends CollectionFailure {
  const CollectionWriteFailure(super.error, [super.stackTrace]);
}

/// Handing a card to the platform share sheet (§4.2) failed — e.g. no share
/// target on the platform, or the share channel threw.
class CollectionShareFailure extends CollectionFailure {
  const CollectionShareFailure(super.error, [super.stackTrace]);
}
