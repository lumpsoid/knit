import 'package:flutter/foundation.dart';
import 'package:knit/features/collection_widget/domain/collection_widget_models.dart';

enum CollectionWidgetPickerStatus { loading, ready, failed }

/// The widget picker's state — a [ChangeNotifier] the
/// [CollectionWidgetPickerController] owns and mutates, and the page listens
/// to. [visibleTargets] is [targets] narrowed by the typed [query].
class CollectionWidgetPickerState extends ChangeNotifier {
  CollectionWidgetPickerStatus _status = CollectionWidgetPickerStatus.loading;
  List<CollectionWidgetTarget> _targets = const [];
  String _query = '';
  bool _saving = false;
  bool _saveFailed = false;

  CollectionWidgetPickerStatus get status => _status;
  List<CollectionWidgetTarget> get targets => _targets;
  String get query => _query;

  /// A bind is in flight — the page blocks further taps.
  bool get saving => _saving;

  /// The last bind failed.
  bool get saveFailed => _saveFailed;

  List<CollectionWidgetTarget> get visibleTargets => [
    for (final t in _targets)
      if (t.matches(_query)) t,
  ];

  void startLoading() {
    _status = CollectionWidgetPickerStatus.loading;
    notifyListeners();
  }

  void showTargets(List<CollectionWidgetTarget> targets) {
    _status = CollectionWidgetPickerStatus.ready;
    _targets = targets;
    notifyListeners();
  }

  void showLoadFailure() {
    _status = CollectionWidgetPickerStatus.failed;
    _targets = const [];
    notifyListeners();
  }

  void setQuery(String query) {
    if (query == _query) return;
    _query = query;
    notifyListeners();
  }

  void startSaving() {
    _saving = true;
    _saveFailed = false;
    notifyListeners();
  }

  void finishSaving({required bool failed}) {
    _saving = false;
    _saveFailed = failed;
    notifyListeners();
  }
}
