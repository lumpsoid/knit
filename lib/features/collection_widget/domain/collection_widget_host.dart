import 'package:knit/features/collection_widget/domain/collection_widget_failure.dart';
import 'package:knit/features/collection_widget/domain/collection_widget_models.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow port to the platform's home-screen widgets: which are placed, what
/// they are bound to, and what they show.
abstract interface class CollectionWidgetHost {
  /// Every placed widget with its bound collection.
  Future<Result<List<CollectionWidgetBinding>, CollectionWidgetFailure>>
  bindings();

  /// Bind widget [widgetId] to [target] and redraw it.
  Future<Result<void, CollectionWidgetFailure>> bind(
    int widgetId,
    CollectionWidgetTarget target,
  );

  /// Redraw the widgets in [tiles] with what they now show.
  Future<Result<void, CollectionWidgetFailure>> publish(
    List<CollectionWidgetTile> tiles,
  );

  /// Configuring is done: send the app to the background, back to the home
  /// screen the widget lives on.
  Future<void> returnToHomeScreen();
}
