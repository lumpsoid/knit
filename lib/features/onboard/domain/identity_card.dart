import 'package:flutter/foundation.dart';

/// The freshly-minted identity, surfaced on the onboarding reveal so the user
/// gets acquainted with who they now are (spec §5). Display-only view data.
@immutable
class IdentityCard {
  const IdentityCard({
    required this.nickname,
    required this.publicKeyHex,
    required this.fingerprint,
  });

  /// The free display label the user chose (§5).
  final String nickname;

  /// Lowercase-hex public key — the real identity (§5).
  final String publicKeyHex;

  /// First 4 hex chars of `SHA-256(pubkey)` (§5).
  final String fingerprint;

  /// `nickname#a4f9` — the human handle (§5).
  String get handle => '$nickname#$fingerprint';
}
