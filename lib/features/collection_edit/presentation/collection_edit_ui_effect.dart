/// One-shot UI effects for the Collection Edit page (fcis.md §6.4), pushed by the
/// shell only.
sealed class CollectionEditUiEffect {
  const CollectionEditUiEffect();
}

/// The edit saved — the page closes itself (the carrier is the payload, so the
/// Collection screen resyncs from the projection on return).
class CollectionEditSavedUiEffect extends CollectionEditUiEffect {
  const CollectionEditSavedUiEffect();
}

/// A semantic, locale-independent message the shell can raise without reaching
/// for `BuildContext` — the View maps it to localized text (l10n).
enum CollectionEditMessage { saveFailed }

/// Show a transient message (e.g. a write failed) — a snackbar. Carries a
/// semantic [CollectionEditMessage] key, not display text; the View localizes it.
class CollectionEditShowMessageUiEffect extends CollectionEditUiEffect {
  const CollectionEditShowMessageUiEffect(this.message);
  final CollectionEditMessage message;
}
