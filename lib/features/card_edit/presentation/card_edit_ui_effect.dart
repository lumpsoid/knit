/// One-shot UI effects for the Card Edit page (fcis.md §6.4), pushed by the
/// shell only.
sealed class CardEditUiEffect {
  const CardEditUiEffect();
}

/// The edit saved — the page closes itself (the carrier is the payload, so the
/// Collection screen resyncs from the projection on return).
class CardEditSavedUiEffect extends CardEditUiEffect {
  const CardEditSavedUiEffect();
}

/// Show a transient message (e.g. a write failed) — a snackbar.
class CardEditShowMessageUiEffect extends CardEditUiEffect {
  const CardEditShowMessageUiEffect(this.message);
  final String message;
}
