import 'package:knit/core/ordering/fractional_index.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/share_capture/domain/share_capture_models.dart';
import 'package:knit/features/share_capture/domain/shared_item.dart';

/// Decides which cards a share becomes (§4.7) — pure. One card per item, in
/// the order shared, appended after the target's last card (§8.7):
/// - text that is a bare http(s) URL → a link card; any other text → a text
///   card ([CardKind.forText]); blank text is dropped;
/// - a file → an image / audio / file card by its mime ([CardKind.forFileMime],
///   the same rule as a file picked in the Collection).
class ShareCapturePlanner {
  const ShareCapturePlanner();

  /// Plan [items] as cards placed after [lastPosition] (null for an empty
  /// collection).
  List<PlannedCard> plan(List<SharedItem> items, {String? lastPosition}) {
    final cards = <PlannedCard>[];
    var previous = lastPosition;
    String nextPosition() => previous = previous == null
        ? FractionalIndex.first()
        : FractionalIndex.keyAfter(previous!);

    for (final item in items) {
      switch (item) {
        case SharedText(:final text):
          final trimmed = text.trim();
          if (trimmed.isEmpty) continue;
          cards.add(
            PlannedCard(
              kind: CardKind.forText(trimmed),
              position: nextPosition(),
              text: trimmed,
            ),
          );
        case SharedFile(:final mime):
          cards.add(
            PlannedCard(
              kind: CardKind.forFileMime(mime),
              position: nextPosition(),
              file: item,
            ),
          );
      }
    }
    return cards;
  }
}
