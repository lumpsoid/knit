/// Intents + async-result deliveries for the Card Edit page (fcis.md §6.4). All
/// payloads are scalars (no sync-core types).
sealed class CardEditAction {
  const CardEditAction();
}

/// View attached for [cardId], seeded with [initialText] from the route-args
/// carrier (cross_feature.md §2).
class ViewAttached extends CardEditAction {
  const ViewAttached({required this.cardId, required this.initialText});
  final String cardId;
  final String initialText;
}

/// Save tapped with the composed [text].
class SaveRequested extends CardEditAction {
  const SaveRequested(this.text);
  final String text;
}

/// The write committed; the page pops (driven by a UI effect from the shell).
class SaveSucceeded extends CardEditAction {
  const SaveSucceeded();
}

/// The write failed; stay on the page so the edit isn't lost.
class SaveFailed extends CardEditAction {
  const SaveFailed(this.message);
  final String message;
}

class DeactivateFeature extends CardEditAction {
  const DeactivateFeature();
}
