import 'package:knit/features/share_capture/domain/share_capture_failure.dart';
import 'package:knit/features/share_capture/domain/share_capture_models.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port for the capture screen (business_logic.md §5).
abstract interface class ShareCaptureReadRepository {
  /// Every live collection, most recently updated first (§8.6.3).
  Future<Result<List<ShareTarget>, ShareCaptureFailure>> loadTargets();

  /// The `position` of [collectionId]'s last live card, or null when it is
  /// empty — the shared cards are appended after it (§8.7).
  Future<Result<String?, ShareCaptureFailure>> lastCardPosition(
    String collectionId,
  );
}
