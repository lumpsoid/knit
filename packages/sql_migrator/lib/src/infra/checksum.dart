import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Computes a stable checksum for a migration based on its version and
/// description. This is used to detect when an already-applied migration
/// has been modified.
///
/// The checksum is intentionally based on version + description rather than
/// function bytecode (which Dart cannot inspect at runtime). Developers
/// should update the description if they meaningfully change a migration.
///
/// **Known weakness — does NOT hash the migration body.** Because the `up`/
/// `down` closures cannot be hashed, editing the SQL a migration runs while
/// leaving its [version] and [description] unchanged yields an identical
/// checksum, so the change is invisible to `validateIntegrity()`. This is the
/// canonical job of a migration checksum (catch edits to already-applied
/// migrations) and this implementation cannot do it. The description is only a
/// human-maintained proxy. Treat this as a rename/renumber detector, not a
/// content guarantee, and rely on immutability-by-policy (never edit a shipped
/// migration's body — bump the version instead). See the package README
/// ("Checksums and integrity") for the full rationale and alternatives.
String computeMigrationChecksum(int version, String description) {
  final input = 'v$version:$description';
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  return digest.toString();
}
