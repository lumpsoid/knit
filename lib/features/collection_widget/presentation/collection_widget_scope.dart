import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/collection_widget/presentation/collection_widget_controller.dart';
import 'package:knit/features/collection_widget/presentation/collection_widget_picker_controller.dart';

/// Composition seam for the home-screen collection widget (Android): `main`
/// wires the app-wide [CollectionWidgetController], the per-page picker
/// factory, and the Collection carrier a widget tap writes.
class CollectionWidgetScope {
  const CollectionWidgetScope._();

  static CollectionWidgetController? _controller;
  static CollectionWidgetPickerController Function(int widgetId)? _factory;
  static CollectionRouteArgsWriter? _collectionRouteArgs;

  static void setController(CollectionWidgetController controller) =>
      _controller = controller;
  static void setPickerFactory(
    CollectionWidgetPickerController Function(int widgetId) factory,
  ) => _factory = factory;
  static void setCollectionRouteArgsWriter(CollectionRouteArgsWriter writer) =>
      _collectionRouteArgs = writer;

  /// The app-wide controller, or null when the widget isn't wired (other
  /// platforms, tests that pump a page on its own) — the gate then does
  /// nothing.
  static CollectionWidgetController? get controller => _controller;

  static CollectionWidgetPickerController createPicker(int widgetId) {
    final factory = _factory;
    if (factory == null) {
      throw StateError(
        'CollectionWidgetScope has no picker factory. '
        'Call CollectionWidgetScope.setPickerFactory() during composition.',
      );
    }
    return factory(widgetId);
  }

  static CollectionRouteArgsWriter get collectionRouteArgs {
    final writer = _collectionRouteArgs;
    if (writer == null) {
      throw StateError(
        'CollectionWidgetScope has no Collection route-args writer. '
        'Call CollectionWidgetScope.setCollectionRouteArgsWriter() during '
        'composition.',
      );
    }
    return writer;
  }
}
