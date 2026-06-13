/// One-shot UI effects the shell pushes for the Profile View (fcis.md §6.4).
sealed class ProfileUiEffect {
  const ProfileUiEffect();
}

/// A semantic, locale-independent message — the View maps it to localized text
/// (l10n) without the shell touching `BuildContext`.
enum ProfileMessage { renameFailed }

/// Show a transient message (e.g. rename failed) — a snackbar.
class ProfileShowMessageUiEffect extends ProfileUiEffect {
  const ProfileShowMessageUiEffect(this.message);
  final ProfileMessage message;
}
