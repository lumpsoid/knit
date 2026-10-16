import 'package:knit/features/card_edit/domain/card_edit_failure.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port (business_logic.md §5): is the card being edited the one its
/// collection's home-timeline row previews (§8.6.3)? Only an edit to that card
/// changes what the Timeline shows, so only then does Card Edit ask it to
/// refresh.
abstract interface class CardEditTimelinePreviewReadRepository {
  Future<Result<bool, CardEditFailure>> isTimelinePreview({
    required String cardId,
    required String collectionId,
  });
}
