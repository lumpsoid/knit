/// Failure family of the recents store (result.md §9.3). Carries the original
/// [error] and, when caught, its [stackTrace].
sealed class RecentTargetsFailure {
  const RecentTargetsFailure(this.error, [this.stackTrace]);

  final Object error;
  final StackTrace? stackTrace;
}

/// Reading or writing a device-local recents list failed.
class RecentTargetsStorageFailure extends RecentTargetsFailure {
  const RecentTargetsStorageFailure(super.error, [super.stackTrace]);
}
