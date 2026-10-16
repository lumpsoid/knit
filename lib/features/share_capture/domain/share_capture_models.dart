import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/share_capture/domain/shared_item.dart';

/// A collection the shared items can be saved into — a row of the picker.
class ShareTarget {
  const ShareTarget({required this.collectionId, required this.title});

  final String collectionId;
  final String title;

  /// Whether this row survives the picker's filter [query]: a case-insensitive
  /// substring of the title. A blank query keeps every row.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    return q.isEmpty || title.toLowerCase().contains(q);
  }
}

/// One card the capture will write, with its pre-computed [position] (§8.7).
/// [text] is set for text/link cards; [file] for image/audio/file cards.
class PlannedCard {
  const PlannedCard({
    required this.kind,
    required this.position,
    this.text,
    this.file,
  });

  final CardKind kind;
  final String position;
  final String? text;
  final SharedFile? file;
}

/// What a finished capture wrote: [cardCount] cards into [collectionId].
class ShareCaptureSaved {
  const ShareCaptureSaved({
    required this.collectionId,
    required this.title,
    required this.cardCount,
  });

  final String collectionId;
  final String title;
  final int cardCount;
}
