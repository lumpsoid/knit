import 'package:knit/features/collection_widget/domain/collection_widget_models.dart';

/// Decides what each placed widget shows — pure. A widget bound to a live
/// collection shows its current title; one bound to a deleted collection shows
/// the removed state (tap to reconfigure); an unbound widget is left alone
/// (it already asks to pick a collection).
class CollectionWidgetTilePlanner {
  const CollectionWidgetTilePlanner();

  /// The collection ids [bindings] point at — what to look up.
  Set<String> boundIds(List<CollectionWidgetBinding> bindings) => {
    for (final b in bindings) ?b.collectionId,
  };

  /// One tile per bound widget, given the [liveTitles] of its collections;
  /// a [readOnlyIds] collection's tile offers no quick input.
  List<CollectionWidgetTile> plan(
    List<CollectionWidgetBinding> bindings,
    Map<String, String> liveTitles, {
    Set<String> readOnlyIds = const {},
  }) => [
    for (final b in bindings)
      if (b.collectionId case final id?)
        switch (liveTitles[id]) {
          final title? => CollectionWidgetTile.live(
            widgetId: b.widgetId,
            title: title,
            quickInput: !readOnlyIds.contains(id),
          ),
          null => CollectionWidgetTile.removed(widgetId: b.widgetId),
        },
  ];
}
