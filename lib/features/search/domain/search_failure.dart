/// Per-feature failure family for Search (result.md §9.3). Carries the original
/// [error] (and [stackTrace] when caught) so the controller logs the real cause.
sealed class SearchFailure {
  const SearchFailure(this.error, [this.stackTrace]);

  final Object error;
  final StackTrace? stackTrace;
}

/// Reading the searchable documents from the projection failed.
class SearchLoadFailure extends SearchFailure {
  const SearchLoadFailure(super.error, [super.stackTrace]);
}
