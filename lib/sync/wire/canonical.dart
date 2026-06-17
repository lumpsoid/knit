/// Canonical serialization — spec §7.1. Turns a [Snapshot] into the **exact**
/// UTF-8 bytes that are signed and stored verbatim in `change_log.payload`.
///
/// Hand-written because neither stdlib produces these bytes: Dart `jsonEncode`
/// does not sort keys and escapes `<>&/` (and could emit non-canonical numbers).
/// Verification is over *received* bytes (§7.0), so byte-identity across Dart/Go
/// is only needed for an optional strict mode — but a deterministic per-signer
/// encoder is required so a signer can re-derive its own bytes.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:knit/sync/snapshot.dart';

/// Produces the §7.1 canonical form of a [Snapshot].
abstract class CanonicalSerializer {
  // The fixed field set per entity (§7.4) — every field always present, sorted
  // ascending by key (lowercase ASCII == UTF-8 byte order). `sig` is excluded
  // (it lives in the op envelope, never signed-over, §7.2); local-only fields
  // (`local_path`, `seq`, `acked`, `origin`) are excluded too (§7.1).
  static const Set<String> _collectionKeys = {
    'author', 'cover_attachment_id', 'created_at', 'created_by', 'deleted',
    'hlc_counter', 'hlc_ms', 'id', 't', 'title',
  };
  static const Set<String> _cardKeys = {
    'attachment_id', 'author', 'collection_id', 'created_at', 'created_by',
    'deleted', 'hlc_counter', 'hlc_ms', 'id', 'kind', 'position',
    'position_counter', 'position_ms', 't', 'text',
  };
  static const Set<String> _linkKeys = {
    'author', 'created_at', 'created_by', 'deleted', 'hlc_counter', 'hlc_ms',
    'id', 'label', 'source_id', 'source_type', 't', 'target_id', 'target_type',
  };
  static const Set<String> _profileKeys = {
    'author', 'created_at', 'created_by', 'deleted', 'hlc_counter', 'hlc_ms',
    'id', 'nickname', 't',
  };
  static const Set<String> _attachmentKeys = {
    'author', 'content_hash', 'created_at', 'created_by', 'deleted',
    'hlc_counter', 'hlc_ms', 'id', 'kind', 'mime', 'name', 'size', 't',
  };

  static Set<String> _fieldSet(EntityType type) => switch (type) {
        EntityType.collection => _collectionKeys,
        EntityType.card => _cardKeys,
        EntityType.link => _linkKeys,
        EntityType.profile => _profileKeys,
        EntityType.attachment => _attachmentKeys,
      };

  /// Envelope + content (+ placement for cards) as a raw map, before filtering.
  /// `content` already holds the §7.4 entity keys on the same names
  /// [Snapshot.fromPayload] / `ProjectionRowMapper` use.
  static Map<String, Object?> _rawMap(Snapshot s) {
    final m = <String, Object?>{
      't': s.type.name,
      'id': s.id,
      'author': s.author,
      'created_by': s.createdBy,
      'created_at': s.createdAt,
      'hlc_ms': s.hlc.ms,
      'hlc_counter': s.hlc.counter,
      'deleted': s.deleted ? 1 : 0,
      ...s.content,
    };
    if (s.isCard) {
      m['position'] = s.position;
      m['position_ms'] = s.placement!.ms;
      m['position_counter'] = s.placement!.counter;
    }
    return m;
  }

  /// The exact signed field map (§7.4): the raw map filtered to the entity's
  /// fixed field set. Filtering drops local-only extras (e.g. a projection row's
  /// `local_path` for attachments); the assert catches a genuinely missing field
  /// (§7.1 rule 4 — every field present, `null` never omitted).
  static Map<String, Object?> fieldMap(Snapshot s) {
    final required = _fieldSet(s.type);
    final raw = _rawMap(s);
    final map = <String, Object?>{
      for (final key in required) key: raw[key],
    };
    assert(
      raw.keys.toSet().containsAll(required),
      'canonical field set for ${s.type.name} is missing '
      '${required.difference(raw.keys.toSet())}',
    );
    return map;
  }

  /// The §7.1 canonical text — sorted keys, no whitespace. This string's UTF-8
  /// bytes are exactly what gets signed and stored in `change_log.payload`.
  static String string(Snapshot s) {
    final map = fieldMap(s);
    final keys = map.keys.toList()..sort();
    final out = StringBuffer('{');
    for (var i = 0; i < keys.length; i++) {
      if (i > 0) out.write(',');
      _writeString(out, keys[i]);
      out.write(':');
      _writeValue(out, map[keys[i]]);
    }
    out.write('}');
    return out.toString();
  }

  /// UTF-8 bytes of [string] — the signed/verified bytes (§7.0).
  static Uint8List bytes(Snapshot s) =>
      Uint8List.fromList(utf8.encode(string(s)));

  static void _writeValue(StringBuffer out, Object? v) {
    if (v == null) {
      out.write('null');
    } else if (v is int) {
      // Integers only in signed payloads (§7.1 rule 6); Dart ints are already
      // shortest-decimal (no leading zero / `+` / point / exponent).
      out.write(v.toString());
    } else if (v is String) {
      _writeString(out, v);
    } else if (v is bool) {
      // `deleted` is pre-converted to int 0/1 (§7.1 rule 5); no bool may reach here.
      throw StateError('canonical payloads carry no JSON booleans: $v');
    } else {
      throw StateError('non-canonical value type ${v.runtimeType}: $v');
    }
  }

  /// JSON string per §7.1 rule 7: escape only what JSON requires; emit UTF-8
  /// (incl. non-ASCII) and `/ < > &` verbatim; control chars as the short
  /// escapes or lowercase `\u00xx`.
  static void _writeString(StringBuffer out, String s) {
    out.write('"');
    for (final unit in s.codeUnits) {
      switch (unit) {
        case 0x22: // "
          out.write(r'\"');
        case 0x5c: // \
          out.write(r'\\');
        case 0x08:
          out.write(r'\b');
        case 0x09:
          out.write(r'\t');
        case 0x0a:
          out.write(r'\n');
        case 0x0c:
          out.write(r'\f');
        case 0x0d:
          out.write(r'\r');
        default:
          if (unit < 0x20) {
            out.write(r'\u');
            out.write(unit.toRadixString(16).padLeft(4, '0'));
          } else {
            out.writeCharCode(unit);
          }
      }
    }
    out.write('"');
  }
}
