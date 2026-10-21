import 'package:flutter/foundation.dart';

/// The imported-collection actions' state — a [ChangeNotifier] the
/// [ImportedCollectionController] owns: whether a copy or a removal is
/// running, and whether the last one failed.
class ImportedCollectionState extends ChangeNotifier {
  bool _busy = false;
  bool _failed = false;

  bool get busy => _busy;
  bool get failed => _failed;

  void start() {
    _busy = true;
    _failed = false;
    notifyListeners();
  }

  void finish({required bool failed}) {
    _busy = false;
    _failed = failed;
    notifyListeners();
  }
}
