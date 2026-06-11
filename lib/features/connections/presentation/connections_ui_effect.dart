/// One-shot UI effects for the Connections view (fcis.md §6.4), pushed by the
/// shell only.
sealed class ConnectionsUiEffect {
  const ConnectionsUiEffect();
}

/// Show a transient message (e.g. a clear failed) — a snackbar.
class ConnectionsShowMessageUiEffect extends ConnectionsUiEffect {
  const ConnectionsShowMessageUiEffect(this.message);
  final String message;
}
