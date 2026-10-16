/// What the user types to confirm "Reset identity": their nickname, so the
/// irreversible step can't happen by a stray tap. A device without a nickname
/// falls back to [fallbackWord].
class IdentityResetConfirmation {
  const IdentityResetConfirmation(this.nickname);

  static const String fallbackWord = 'reset';

  final String nickname;

  /// The exact text the user must type.
  String get word => nickname.trim().isEmpty ? fallbackWord : nickname.trim();

  bool accepts(String typed) => typed.trim() == word;
}
