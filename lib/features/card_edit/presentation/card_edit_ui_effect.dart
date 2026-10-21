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

/// A semantic, locale-independent message the shell can raise without reaching
/// for `BuildContext` — the View maps it to localized text (l10n).
enum CardEditMessage { saveFailed, imageNotSmaller }

/// Show a transient message (e.g. a write failed) — a snackbar. Carries a
/// semantic [CardEditMessage] key, not display text; the View localizes it.
class CardEditShowMessageUiEffect extends CardEditUiEffect {
  const CardEditShowMessageUiEffect(this.message);
  final CardEditMessage message;
}

/// The card's image was swapped for a smaller copy: say what it saved.
class CardEditImageOptimizedUiEffect extends CardEditUiEffect {
  const CardEditImageOptimizedUiEffect({
    required this.fromBytes,
    required this.toBytes,
  });
  final int fromBytes;
  final int toBytes;
}
