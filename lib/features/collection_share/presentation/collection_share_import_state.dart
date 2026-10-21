import 'package:flutter/foundation.dart';
import 'package:knit/features/collection_share/domain/collection_share_failure.dart';
import 'package:knit/features/collection_share/domain/collection_share_models.dart';

enum ShareImportStatus { reading, ready, importing, failed }

/// Why an import stopped, as the preview sheet words it.
enum ShareImportProblem {
  /// Not a Knit collection file (or a damaged one).
  unreadable,

  /// Made by a newer Knit.
  newerVersion,

  /// Refused by the validation rules (signatures, authors, scope).
  refused,

  /// Applying the file failed part-way.
  importFailed,
}

/// The import preview sheet's state — a [ChangeNotifier] the
/// [CollectionShareImportController] owns and mutates, and the sheet listens
/// to.
class CollectionShareImportState extends ChangeNotifier {
  ShareImportStatus _status = ShareImportStatus.reading;
  CollectionShareImportPlan? _plan;
  ShareImportProblem? _problem;

  ShareImportStatus get status => _status;

  /// The validated file and its preview, once read.
  CollectionShareImportPlan? get plan => _plan;
  ShareImportProblem? get problem => _problem;

  void startReading() {
    _status = ShareImportStatus.reading;
    _plan = null;
    _problem = null;
    notifyListeners();
  }

  void showPlan(CollectionShareImportPlan plan) {
    _status = ShareImportStatus.ready;
    _plan = plan;
    notifyListeners();
  }

  void startImporting() {
    _status = ShareImportStatus.importing;
    notifyListeners();
  }

  void fail(CollectionShareFailure failure) {
    _status = ShareImportStatus.failed;
    _problem = switch (failure) {
      CollectionShareNewerVersionFailure() => ShareImportProblem.newerVersion,
      CollectionShareRejectedFailure() => ShareImportProblem.refused,
      CollectionShareCorruptFailure() => ShareImportProblem.unreadable,
      _ => ShareImportProblem.importFailed,
    };
    notifyListeners();
  }
}
