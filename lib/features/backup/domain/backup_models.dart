import 'dart:typed_data';

/// A finished backup bundle ready to hand to the OS share sheet: the zip
/// [bytes] and the suggested [fileName] (e.g. `knit-backup-<author8>-<ms>.zip`).
class BackupArchive {
  const BackupArchive({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

/// The outcome of restoring a bundle — surfaced to the user so a partial or
/// already-applied restore is honest rather than silent.
///
/// Ops replay through `SyncStore.applyRemote`, so each lands as exactly one of
/// applied / deduped / quarantined (a quarantined op had a bad signature or a
/// future-dated clock). Blobs are content-addressed: a restored blob whose bytes
/// don't hash to its name is counted in [blobsMismatched] and skipped.
class ImportSummary {
  const ImportSummary({
    required this.opsApplied,
    required this.opsDeduped,
    required this.opsQuarantined,
    required this.blobsRestored,
    required this.blobsMismatched,
  });

  final int opsApplied;
  final int opsDeduped;
  final int opsQuarantined;
  final int blobsRestored;
  final int blobsMismatched;

  int get opsTotal => opsApplied + opsDeduped + opsQuarantined;
}

/// The key-derivation settings a [SealedIdentity] was sealed with. Stored in
/// the bundle so a later reader derives the same key even if the defaults
/// change.
class KdfParams {
  const KdfParams({
    required this.memoryKib,
    required this.iterations,
    required this.parallelism,
  });

  /// Argon2id at the OWASP minimum (19 MiB, 2 passes, 1 lane): slow enough to
  /// make guessing a passphrase costly, fast enough for a phone.
  static const recommended = KdfParams(
    memoryKib: 19456,
    iterations: 2,
    parallelism: 1,
  );

  final int memoryKib;
  final int iterations;
  final int parallelism;
}

/// The device keypair as it travels inside a backup bundle (§5 — identity is
/// backed up by backing up the keypair). The public key is in the clear; the
/// secret is encrypted under a key derived from the user's passphrase, with the
/// public key bound as associated data so the two can't be swapped apart.
class SealedIdentity {
  const SealedIdentity({
    required this.publicKeyHex,
    required this.kdf,
    required this.salt,
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  final String publicKeyHex;
  final KdfParams kdf;
  final List<int> salt;
  final List<int> nonce;
  final List<int> cipherText;
  final List<int> mac;
}

/// A decoded backup bundle, ready to restore. [identity] is null for a bundle
/// made before backups carried the keypair (format v1).
class BackupBundle {
  const BackupBundle({
    required this.author,
    required this.createdAtMs,
    required this.identity,
    required this.opLines,
    required this.blobs,
  });

  /// The public key of the device that made the bundle.
  final String author;
  final int createdAtMs;
  final SealedIdentity? identity;

  /// One signed `change_log` row per line, verbatim.
  final List<String> opLines;

  /// Attachment bytes by content hash.
  final Map<String, Uint8List> blobs;
}

/// How a bundle restores onto this device — decided by [RestorePolicy].
enum RestoreKind {
  /// Replay the ops onto the current identity: the bundle is this device's
  /// own, or an old bundle without a keypair.
  merge,

  /// Erase this device, adopt the bundle's keypair (after the passphrase
  /// unseals it), then replay its ops.
  replaceDevice,

  /// The device has no identity and the bundle carries none either, so there
  /// is no key to restore (onboarding with a v1 bundle).
  missingIdentity,
}

/// A decoded [bundle] and how it restores here.
class RestorePlan {
  const RestorePlan({required this.bundle, required this.kind});

  final BackupBundle bundle;
  final RestoreKind kind;
}
