import 'package:flutter/foundation.dart';
import 'package:knit/features/collection_share/domain/collection_share_models.dart';

enum ShareExportStatus { loading, ready, failed }

/// The "Share as file" sheet's state — a [ChangeNotifier] the
/// [CollectionShareExportController] owns and mutates, and the sheet listens
/// to. [includeMedia] starts on.
class CollectionShareExportState extends ChangeNotifier {
  ShareExportStatus _status = ShareExportStatus.loading;
  CollectionShareEstimate? _estimate;
  bool _includeMedia = true;
  bool _busy = false;
  bool _failed = false;

  ShareExportStatus get status => _status;
  CollectionShareEstimate? get estimate => _estimate;
  bool get includeMedia => _includeMedia;

  /// A file is being built or handed off — the sheet blocks further taps.
  bool get busy => _busy;

  /// The last send or save failed.
  bool get failed => _failed;

  /// Whether the collection has media to include at all.
  bool get hasMedia => (_estimate?.mediaCount ?? 0) > 0;

  /// The file size for the current [includeMedia] choice.
  int? get size => _estimate?.sizeWith(media: _includeMedia && hasMedia);

  void startLoading() {
    _status = ShareExportStatus.loading;
    notifyListeners();
  }

  void showEstimate(CollectionShareEstimate estimate) {
    _status = ShareExportStatus.ready;
    _estimate = estimate;
    notifyListeners();
  }

  void showLoadFailure() {
    _status = ShareExportStatus.failed;
    notifyListeners();
  }

  void setIncludeMedia(bool include) {
    if (include == _includeMedia) return;
    _includeMedia = include;
    notifyListeners();
  }

  void startDelivery() {
    _busy = true;
    _failed = false;
    notifyListeners();
  }

  void finishDelivery({required bool failed}) {
    _busy = false;
    _failed = failed;
    notifyListeners();
  }
}
