/// One-shot UI effects for Timeline (fcis.md §6.4), pushed by the shell only.
sealed class TimelineUiEffect {
  const TimelineUiEffect();
}

/// Open the Collection screen for [collectionId] (§4.1). The View writes the
/// id into the route-args carrier (cross_feature.md §2) and navigates.
class TimelineOpenCollectionUiEffect extends TimelineUiEffect {
  const TimelineOpenCollectionUiEffect(this.collectionId);
  final String collectionId;
}

/// A semantic, locale-independent message the shell can raise without reaching
/// for `BuildContext` — the View maps it to localized text (l10n).
enum TimelineMessage { createFailed, deleteFailed }

/// Show a transient message (e.g. create failed) — a snackbar. Carries a
/// semantic [TimelineMessage] key, not display text; the View localizes it.
class TimelineShowMessageUiEffect extends TimelineUiEffect {
  const TimelineShowMessageUiEffect(this.message);
  final TimelineMessage message;
}
