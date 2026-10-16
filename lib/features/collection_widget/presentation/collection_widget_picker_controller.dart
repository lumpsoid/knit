import 'package:knit/features/collection_widget/domain/collection_widget_host.dart';
import 'package:knit/features/collection_widget/domain/collection_widget_models.dart';
import 'package:knit/features/collection_widget/domain/collection_widget_read_repository.dart';
import 'package:knit/features/collection_widget/presentation/collection_widget_picker_state.dart';
import 'package:logging/logging.dart';

/// The widget picker's input object: lists the collections and binds the
/// placed widget [widgetId] to the chosen one. One per page instance; the page
/// disposes it.
class CollectionWidgetPickerController {
  CollectionWidgetPickerController({
    required this.widgetId,
    required CollectionWidgetReadRepository readRepository,
    required CollectionWidgetHost host,
    Logger? logger,
  }) : _read = readRepository,
       _host = host,
       _log = logger ?? Logger('knit.collection_widget');

  final int widgetId;

  final CollectionWidgetReadRepository _read;
  final CollectionWidgetHost _host;
  final Logger _log;

  final CollectionWidgetPickerState state = CollectionWidgetPickerState();

  Future<void> load() async {
    state.startLoading();
    final result = await _read.loadTargets();
    result.fold(state.showTargets, (failure) {
      _log.severe(
        'loading collections failed',
        failure.error,
        failure.stackTrace,
      );
      state.showLoadFailure();
    });
  }

  void filter(String query) => state.setQuery(query);

  /// Bind the widget to [target]. True once bound; false when the bind failed
  /// (see [CollectionWidgetPickerState.saveFailed]) or one is running.
  Future<bool> choose(CollectionWidgetTarget target) async {
    if (state.saving) return false;
    state.startSaving();
    final result = await _host.bind(widgetId, target);
    return result.fold(
      (_) {
        state.finishSaving(failed: false);
        return true;
      },
      (failure) {
        _log.severe(
          'binding the widget failed',
          failure.error,
          failure.stackTrace,
        );
        state.finishSaving(failed: true);
        return false;
      },
    );
  }

  void dispose() => state.dispose();
}
