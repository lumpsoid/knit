/// One-shot UI effects for the Collection screen (fcis.md §6.4), pushed by the
/// shell only.
sealed class CollectionUiEffect {
  const CollectionUiEffect();
}

/// A semantic, locale-independent message the shell can raise without reaching
/// for `BuildContext` — the View maps it to localized text (l10n).
enum CollectionMessage { saveFailed, micPermissionDenied }

/// Show a transient message (e.g. a write failed) — a snackbar. Carries a
/// semantic [CollectionMessage] key, not display text; the View localizes it.
class CollectionShowMessageUiEffect extends CollectionUiEffect {
  const CollectionShowMessageUiEffect(this.message);
  final CollectionMessage message;
}
