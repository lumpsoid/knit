import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Computes a stable checksum for a migration based on its version and
/// description. This is used to detect when an already-applied migration
/// has been modified.
///
/// The checksum is intentionally based on version + description rather than
/// function bytecode (which Dart cannot inspect at runtime). Developers
/// should update the description if they meaningfully change a migration.
String computeMigrationChecksum(int version, String description) {
  final input = 'v$version:$description';
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  return digest.toString();
}
