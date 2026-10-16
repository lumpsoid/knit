import 'package:knit/features/share_capture/domain/share_capture_failure.dart';
import 'package:knit/features/share_capture/domain/share_capture_models.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow write port for the capture screen (business_logic.md §5).
abstract interface class ShareCaptureWriteRepository {
  /// Create a collection titled [title] (§7.4.1); returns its id.
  Future<Result<String, ShareCaptureFailure>> createCollection(String title);

  /// Write [cards] into [collectionId] in order: a file card first stores its
  /// bytes as an attachment (§7.4.8), then the signed card. Each card is its
  /// own write, so a failure part-way keeps the cards written before it.
  /// Returns how many cards were written.
  Future<Result<int, ShareCaptureFailure>> saveCards(
    String collectionId,
    List<PlannedCard> cards,
  );
}
