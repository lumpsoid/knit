/// One-shot UI effects for the Collection Media page (fcis.md §6.4), pushed by
/// the shell only.
sealed class CollectionMediaUiEffect {
  const CollectionMediaUiEffect();
}

/// A semantic, locale-independent message the shell can raise without reaching
/// for `BuildContext` — the View maps it to localized text (l10n).
enum CollectionMediaMessage { linkOpenFailed }

/// Show a transient message (a snackbar).
class CollectionMediaShowMessageUiEffect extends CollectionMediaUiEffect {
  const CollectionMediaShowMessageUiEffect(this.message);
  final CollectionMediaMessage message;
}
