import 'package:flutter/foundation.dart';
import 'package:knit/features/share_capture/domain/share_capture_models.dart';

enum ShareCaptureStatus { loading, ready, failed }

/// The capture screen's state (§4.7) — a [ChangeNotifier] the
/// [ShareCaptureController] owns and mutates, and the page listens to.
/// [visibleTargets] is [targets] narrowed by the typed [query].
class ShareCaptureState extends ChangeNotifier {
  ShareCaptureStatus _status = ShareCaptureStatus.loading;
  List<ShareTarget> _targets = const [];
  String _query = '';
  bool _saving = false;
  bool _saveFailed = false;

  ShareCaptureStatus get status => _status;
  List<ShareTarget> get targets => _targets;
  String get query => _query;

  /// A save is in flight — the page blocks further taps.
  bool get saving => _saving;

  /// The last save failed (some cards may have been written).
  bool get saveFailed => _saveFailed;

  List<ShareTarget> get visibleTargets => [
    for (final t in _targets)
      if (t.matches(_query)) t,
  ];

  void startLoading() {
    _status = ShareCaptureStatus.loading;
    notifyListeners();
  }

  void showTargets(List<ShareTarget> targets) {
    _status = ShareCaptureStatus.ready;
    _targets = targets;
    notifyListeners();
  }

  void showLoadFailure() {
    _status = ShareCaptureStatus.failed;
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
