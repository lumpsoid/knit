import 'dart:convert';
import 'dart:typed_data';

import 'package:knit/core/files/infra/log_archive.dart';
import 'package:knit/features/backup/domain/backup_models.dart';

/// The on-disk backup layout (one `.zip`):
/// - `manifest.json` — format/version + counts (this file)
/// - `log.jsonl` — one signed PersistedOp row per line (verbatim)
/// - `blobs/<content_hash>` — raw attachment bytes, content-addressed
/// - `identity.json` — the keypair, secret sealed under a passphrase (v2+)
const String kBackupFormat = 'knit-backup';
const int kBackupVersion = 2;

const String _identityEntry = 'identity.json';

/// The bundle header. Self-describing so a future reader can refuse an
/// incompatible bundle instead of mis-parsing it.
class BackupManifest {
  const BackupManifest({
    required this.createdAtMs,
    required this.author,
    required this.opCount,
    required this.blobCount,
    this.format = kBackupFormat,
    this.version = kBackupVersion,
  });

  factory BackupManifest.fromJson(Map<String, Object?> json) => BackupManifest(
    format: json['format'] as String? ?? '',
    version: (json['version'] as num?)?.toInt() ?? 0,
    createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
    author: json['author'] as String? ?? '',
    opCount: (json['opCount'] as num?)?.toInt() ?? 0,
    blobCount: (json['blobCount'] as num?)?.toInt() ?? 0,
  );

  final String format;
  final int version;
  final int createdAtMs;
  final String author;
  final int opCount;
  final int blobCount;

  Map<String, Object?> toJson() => {
    'format': format,
    'version': version,
    'createdAtMs': createdAtMs,
    'author': author,
    'opCount': opCount,
    'blobCount': blobCount,
  };
}

/// The decoded contents of a bundle, ready to replay/rehydrate.
class ParsedBackup {
  const ParsedBackup({
    required this.manifest,
    required this.opLines,
    required this.blobs,
    this.identity,
  });

  final BackupManifest manifest;
  final List<String> opLines;
  final Map<String, Uint8List> blobs;

  /// The sealed keypair; null in a v1 bundle.
  final SealedIdentity? identity;

  BackupBundle toBundle() => BackupBundle(
    author: manifest.author,
    createdAtMs: manifest.createdAtMs,
    identity: identity,
    opLines: opLines,
    blobs: blobs,
  );
}

/// Pure zip (de)serialization for the backup bundle, over the shared
/// [LogArchive] layout. The repositories own the store/blob I/O; this only
/// shapes bytes ↔ entries.
class BackupArchiveCodec {
  const BackupArchiveCodec();

  Uint8List encode({
    required BackupManifest manifest,
    required List<String> opLines,
    required Map<String, Uint8List> blobs,
    SealedIdentity? identity,
  }) => LogArchive.encode(
    LogArchiveEntries(
      manifest: manifest.toJson(),
      opLines: opLines,
      blobs: blobs,
      extras: {
        if (identity != null)
          _identityEntry: jsonEncode(_identityToJson(identity)),
      },
    ),
  );

  /// Decode a bundle. Throws [FormatException] when the bytes are not a valid
  /// zip, the manifest is missing, or the format/version is incompatible — the
  /// repository maps that to a `BackupCorruptArchiveFailure`.
  ParsedBackup decode(Uint8List zip) {
    final entries = LogArchive.decode(zip, extras: const {_identityEntry});
    final manifest = BackupManifest.fromJson(entries.manifest);
    if (manifest.format != kBackupFormat) {
      throw FormatException('unrecognized backup format: "${manifest.format}"');
    }
    if (manifest.version > kBackupVersion) {
      throw FormatException('unsupported backup version: ${manifest.version}');
    }

    final identityJson = entries.extras[_identityEntry];
    final identity = identityJson == null
        ? null
        : _identityFromJson(jsonDecode(identityJson) as Map<String, Object?>);

    return ParsedBackup(
      manifest: manifest,
      opLines: entries.opLines,
      blobs: entries.blobs,
      identity: identity,
    );
  }

  static Map<String, Object?> _identityToJson(SealedIdentity identity) => {
    'public_key': identity.publicKeyHex,
    'kdf': {
      'alg': 'argon2id',
      'memory_kib': identity.kdf.memoryKib,
      'iterations': identity.kdf.iterations,
      'parallelism': identity.kdf.parallelism,
      'salt': base64Encode(identity.salt),
    },
    'cipher': 'xchacha20-poly1305',
    'nonce': base64Encode(identity.nonce),
    'cipher_text': base64Encode(identity.cipherText),
    'mac': base64Encode(identity.mac),
  };

  /// Throws [FormatException] on a malformed or unknown-algorithm entry.
  static SealedIdentity _identityFromJson(Map<String, Object?> json) {
    final kdf = json['kdf'];
    if (kdf is! Map<String, Object?> ||
        kdf['alg'] != 'argon2id' ||
        json['cipher'] != 'xchacha20-poly1305') {
      throw const FormatException('unsupported identity sealing');
    }
    try {
      return SealedIdentity(
        publicKeyHex: json['public_key']! as String,
        kdf: KdfParams(
          memoryKib: (kdf['memory_kib']! as num).toInt(),
          iterations: (kdf['iterations']! as num).toInt(),
          parallelism: (kdf['parallelism']! as num).toInt(),
        ),
        salt: base64Decode(kdf['salt']! as String),
        nonce: base64Decode(json['nonce']! as String),
        cipherText: base64Decode(json['cipher_text']! as String),
        mac: base64Decode(json['mac']! as String),
      );
    } on TypeError {
      throw const FormatException('malformed identity.json');
    }
  }
}
