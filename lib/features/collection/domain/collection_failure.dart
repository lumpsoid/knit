/// Per-feature failure family for the Collection screen (result.md §9.3). The
/// shell maps these to user-facing messages; the updater never sees a [Result].
sealed class CollectionFailure {
  const CollectionFailure();
}

/// Reading the collection header + feed from the projection failed.
class CollectionLoadFailure extends CollectionFailure {
  const CollectionLoadFailure(this.cause);
  final String cause;
}

/// A local write (create/edit/delete/reorder/link) failed to persist.
class CollectionWriteFailure extends CollectionFailure {
  const CollectionWriteFailure(this.cause);
  final String cause;
}
