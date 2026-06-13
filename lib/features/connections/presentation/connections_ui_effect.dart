/// One-shot UI effects for the Connections view (fcis.md §6.4), pushed by the
/// shell only.
sealed class ConnectionsUiEffect {
  const ConnectionsUiEffect();
}

/// A semantic, locale-independent message the shell can raise without reaching
/// for `BuildContext` — the View maps it to localized text (l10n).
enum ConnectionsMessage { clearFailed }

/// Show a transient message (e.g. a clear failed) — a snackbar. Carries a
/// semantic [ConnectionsMessage] key, not display text; the View localizes it.
class ConnectionsShowMessageUiEffect extends ConnectionsUiEffect {
  const ConnectionsShowMessageUiEffect(this.message);
  final ConnectionsMessage message;
}
