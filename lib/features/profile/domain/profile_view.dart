import 'package:flutter/foundation.dart';

/// The device's own identity, surfaced on the Profile screen (spec §5/§7.4.7):
/// the nickname carried on the signed `profile` record, plus the derived
/// fingerprint and the full public key (the real identity). Display-only.
@immutable
class ProfileView {
  const ProfileView({
    required this.nickname,
    required this.publicKeyHex,
    required this.fingerprint,
  });

  /// The free display label the user chose; editable here (§5 — "you can change
  /// it anytime"). May be empty if the profile record carries no nickname yet.
  final String nickname;

  /// Lowercase-hex public key — the real identity (§5). Immutable.
  final String publicKeyHex;

  /// First 4 hex chars of `SHA-256(pubkey)` (§5) — stable per key.
  final String fingerprint;

  /// `nickname#a4f9` — the human handle (§5).
  String get handle => '$nickname#$fingerprint';

  ProfileView copyWith({String? nickname}) => ProfileView(
    nickname: nickname ?? this.nickname,
    publicKeyHex: publicKeyHex,
    fingerprint: fingerprint,
  );
}
