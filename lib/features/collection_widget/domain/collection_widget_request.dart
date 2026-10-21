/// What a tap on a home-screen collection widget asks Knit to do (Android). The
/// platform-agnostic shape the [CollectionWidgetRequestSource] hands over, so
/// nothing past the adapter sees the platform intent.
sealed class CollectionWidgetRequest {
  const CollectionWidgetRequest();
}

/// Open the collection the tapped widget is bound to.
final class OpenCollectionRequest extends CollectionWidgetRequest {
  const OpenCollectionRequest(this.collectionId);

  final String collectionId;
}

/// Open the bound collection for one quick card: the composer focused, and
/// back to the home screen once it is sent (the tile's ✎ button).
final class QuickInputRequest extends CollectionWidgetRequest {
  const QuickInputRequest(this.collectionId);

  final String collectionId;
}

/// Pick the collection for widget [widgetId] — when it is placed, when the
/// launcher reconfigures it, or when an unbound or orphaned widget is tapped.
final class ConfigureWidgetRequest extends CollectionWidgetRequest {
  const ConfigureWidgetRequest(this.widgetId);

  final int widgetId;
}
