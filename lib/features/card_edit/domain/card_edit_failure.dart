/// Per-feature failure family for the Card Edit page (result.md §9.3). The shell
/// maps these to user-facing messages; the updater never sees a [Result].
sealed class CardEditFailure {
  const CardEditFailure();
}

/// A local write (edit card content, add/remove a link, set/clear the image)
/// failed to persist.
class CardEditWriteFailure extends CardEditFailure {
  const CardEditWriteFailure(this.cause);
  final String cause;
}

/// A read failed (loading the card's links or the link-target tree).
class CardEditReadFailure extends CardEditFailure {
  const CardEditReadFailure(this.cause);
  final String cause;
}
