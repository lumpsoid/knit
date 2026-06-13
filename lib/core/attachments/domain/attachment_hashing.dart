import 'package:cryptography/cryptography.dart';
import 'package:knit/sync/sync.dart' show hexEncode;

/// SHA-256 (lowercase hex) over [bytes] — the attachment `content_hash`
/// (spec §6.4/§7.4.8: dedup + integrity). Async because `package:cryptography`'s
/// hash API is async; the hex encoding reuses the signer-boundary helper so the
/// hash format matches everything else on the wire.
Future<String> sha256Hex(List<int> bytes) async {
  final hash = await Sha256().hash(bytes);
  return hexEncode(hash.bytes);
}
