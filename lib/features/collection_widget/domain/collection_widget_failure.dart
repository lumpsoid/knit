/// Per-feature failure family for the collection widget (result.md §9.3).
/// Carries the original [error] (and [stackTrace] when caught) so the
/// controller logs the real cause.
sealed class CollectionWidgetFailure {
  const CollectionWidgetFailure(this.error, [this.stackTrace]);

  final Object error;
  final StackTrace? stackTrace;
}

/// Reading the collections from the store failed.
class CollectionWidgetLoadFailure extends CollectionWidgetFailure {
  const CollectionWidgetLoadFailure(super.error, [super.stackTrace]);
}

/// Talking to the platform widget host failed.
class CollectionWidgetHostFailure extends CollectionWidgetFailure {
  const CollectionWidgetHostFailure(super.error, [super.stackTrace]);
}
