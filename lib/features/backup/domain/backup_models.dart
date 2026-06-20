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
