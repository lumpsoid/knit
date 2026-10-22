import 'package:flutter/foundation.dart';
import 'package:knit/features/collection_share/domain/collection_share_models.dart';

enum ShareExportStatus { loading, ready, failed }

/// The "Share as file" sheet's state — a [ChangeNotifier] the
/// [CollectionShareExportController] owns and mutates, and the sheet listens
/// to. [includeMedia] starts on, [includeLinked] off.
class CollectionShareExportState extends ChangeNotifier {
  ShareExportStatus _status = ShareExportStatus.loading;
  CollectionShareEstimate? _estimate;
  bool _includeMedia = true;
  bool _includeLinked = false;
  bool _busy = false;
  bool _failed = false;

  ShareExportStatus get status => _status;
  CollectionShareEstimate? get estimate => _estimate;
  bool get includeMedia => _includeMedia;
  bool get includeLinked => _includeLinked;

  /// A file is being built or handed off — the sheet blocks further taps.
  bool get busy => _busy;

  /// The last send or save failed.
  bool get failed => _failed;

  /// Live connections pointing outside the collection — the warning shows
  /// when there are any.
  int get outsideCount => _estimate?.reach.outsideCount ?? 0;

  /// Of those, the ones that can't be bundled (not this identity's own).
  int get notOwnedCount => _estimate?.reach.notOwnedCount ?? 0;

  /// The own collections "Include linked collections" would bundle; the
  /// switch shows only when there are any.
  int get linkedCollectionCount =>
      _estimate?.reach.linkedCollectionIds.length ?? 0;

  /// Whether the linked collections ride along: the switch is on and there
  /// is something to bundle.
  bool get linked => _includeLinked && linkedCollectionCount > 0;

  /// The size numbers for the current [includeLinked] choice.
  ShareSize? get sizes => _estimate?.sizeFor(linked: linked);

  /// Whether the file has media to include at all.
  bool get hasMedia => (sizes?.mediaCount ?? 0) > 0;

  /// The file size for the current [includeMedia] and [includeLinked]
  /// choices.
  int? get size => sizes?.sizeWith(media: _includeMedia && hasMedia);

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

  void setIncludeLinked(bool include) {
    if (include == _includeLinked) return;
    _includeLinked = include;
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
