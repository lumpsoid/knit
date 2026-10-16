import 'package:flutter/foundation.dart';
import 'package:knit/features/collection_widget/domain/collection_widget_request.dart';

/// The widget request waiting to be handled — app-wide, owned and mutated by
/// the [CollectionWidgetController]; the [CollectionWidgetGate] listens to it.
/// A newer request replaces one nobody has taken yet.
class CollectionWidgetState extends ChangeNotifier {
  CollectionWidgetRequest? _pending;

  CollectionWidgetRequest? get pending => _pending;
  bool get hasPending => _pending != null;

  void offer(CollectionWidgetRequest request) {
    _pending = request;
    notifyListeners();
  }

  /// Hand out the pending request and clear it.
  CollectionWidgetRequest? take() {
    final request = _pending;
    if (request == null) return null;
    _pending = null;
    notifyListeners();
    return request;
  }
}
