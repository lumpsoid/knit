/// Lowercase-hex encode/decode for the crypto layer (spec §7.1 rule 8 / §5).
///
/// Public keys, signatures, and content hashes ride the wire as lowercase hex;
/// the canonical serializer treats them as already-hex strings, so the only
/// place bytes↔hex conversion happens is here, at the signer boundary.
library;

import 'dart:typed_data';

const String _digits = '0123456789abcdef';

/// Bytes → lowercase hex.
String hexEncode(List<int> bytes) {
  final out = StringBuffer();
  for (final b in bytes) {
    out.write(_digits[(b >> 4) & 0xf]);
    out.write(_digits[b & 0xf]);
  }
  return out.toString();
}

/// Lowercase/uppercase hex → bytes. Throws [FormatException] on odd length or a
/// non-hex character.
Uint8List hexDecode(String hex) {
  if (hex.length.isOdd) {
    throw FormatException('hex string must have even length', hex);
  }
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] =
        (_nibble(hex.codeUnitAt(i * 2)) << 4) |
        _nibble(hex.codeUnitAt(i * 2 + 1));
  }
  return out;
}

int _nibble(int codeUnit) {
  if (codeUnit >= 0x30 && codeUnit <= 0x39) return codeUnit - 0x30; // 0-9
  if (codeUnit >= 0x61 && codeUnit <= 0x66) return codeUnit - 0x61 + 10; // a-f
  if (codeUnit >= 0x41 && codeUnit <= 0x46) return codeUnit - 0x41 + 10; // A-F
  throw FormatException('not a hex digit: ${String.fromCharCode(codeUnit)}');
}
