/// Per-feature failure family for backup/restore (result.md §9.3). Each variant
/// carries the original [error] (and [stackTrace] when caught from an exception)
/// so the shell logs the real cause, not a re-typed summary.
sealed class BackupFailure {
  const BackupFailure(this.error, [this.stackTrace]);

  /// The underlying error — a caught exception, or a domain-condition message.
  final Object error;

  /// The stack trace from the caught exception, when there was one.
  final StackTrace? stackTrace;
}

/// Building the backup bundle failed (reading the log/projection/blobs or
/// encoding the archive).
class BackupExportFailure extends BackupFailure {
  const BackupExportFailure(super.error, [super.stackTrace]);
}

/// Restoring a bundle failed while replaying ops / writing blobs.
class BackupImportFailure extends BackupFailure {
  const BackupImportFailure(super.error, [super.stackTrace]);
}

/// The picked archive is not a valid Knit backup (bad zip, missing/incompatible
/// `manifest.json`).
class BackupCorruptArchiveFailure extends BackupFailure {
  const BackupCorruptArchiveFailure(super.error, [super.stackTrace]);
}

/// Handing the bundle to the OS share sheet failed.
class BackupDeliveryFailure extends BackupFailure {
  const BackupDeliveryFailure(super.error, [super.stackTrace]);
}

/// Saving the bundle to a user-chosen file failed.
class BackupSaveFailure extends BackupFailure {
  const BackupSaveFailure(super.error, [super.stackTrace]);
}

/// Picking an archive to restore failed (the file picker errored).
class BackupSourceFailure extends BackupFailure {
  const BackupSourceFailure(super.error, [super.stackTrace]);
}
