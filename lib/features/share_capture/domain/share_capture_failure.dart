/// Per-feature failure family for Share Capture (result.md §9.3). Carries the
/// original [error] (and [stackTrace] when caught) so the controller logs the
/// real cause.
sealed class ShareCaptureFailure {
  const ShareCaptureFailure(this.error, [this.stackTrace]);

  final Object error;
  final StackTrace? stackTrace;
}

/// Reading the collections (or a collection's tail) failed.
class ShareCaptureLoadFailure extends ShareCaptureFailure {
  const ShareCaptureLoadFailure(super.error, [super.stackTrace]);
}

/// Creating the collection, reading a shared file or writing a card failed.
class ShareCaptureWriteFailure extends ShareCaptureFailure {
  const ShareCaptureWriteFailure(super.error, [super.stackTrace]);
}
