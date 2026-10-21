/// Failure family of the file ports (result.md §9.3). Each variant carries
/// the original [error] and, when caught, its [stackTrace].
sealed class FileFailure {
  const FileFailure(this.error, [this.stackTrace]);

  final Object error;
  final StackTrace? stackTrace;
}

/// Handing a file to the OS share sheet failed.
class FileDeliveryFailure extends FileFailure {
  const FileDeliveryFailure(super.error, [super.stackTrace]);
}

/// Saving a file to a user-chosen location failed.
class FileSaveFailure extends FileFailure {
  const FileSaveFailure(super.error, [super.stackTrace]);
}

/// Picking a file failed (the file picker errored).
class FileSourceFailure extends FileFailure {
  const FileSourceFailure(super.error, [super.stackTrace]);
}
