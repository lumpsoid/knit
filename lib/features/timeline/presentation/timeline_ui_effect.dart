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

/// Show a transient message (e.g. create failed) — a snackbar.
class TimelineShowMessageUiEffect extends TimelineUiEffect {
  const TimelineShowMessageUiEffect(this.message);
  final String message;
}
