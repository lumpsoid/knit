/// Per-feature failure family for presenting a collection (result.md §9.3).
/// Carries the original [error] (and [stackTrace] when caught) so the
/// controller logs the real cause.
sealed class PresentFailure {
  const PresentFailure(this.error, [this.stackTrace]);

  final Object error;
  final StackTrace? stackTrace;
}

/// Reading the collection to present failed (or it is gone).
class PresentLoadFailure extends PresentFailure {
  const PresentLoadFailure(super.error, [super.stackTrace]);
}

/// Reading or saving the remembered slide failed.
class PresentProgressFailure extends PresentFailure {
  const PresentProgressFailure(super.error, [super.stackTrace]);
}
