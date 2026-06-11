/// One-shot UI effects for the Collection screen (fcis.md §6.4), pushed by the
/// shell only.
sealed class CollectionUiEffect {
  const CollectionUiEffect();
}

/// Show a transient message (e.g. a write failed) — a snackbar.
class CollectionShowMessageUiEffect extends CollectionUiEffect {
  const CollectionShowMessageUiEffect(this.message);
  final String message;
}
