import 'package:knit/core/ordering/fractional_index.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/share_capture/domain/share_capture_models.dart';
import 'package:knit/features/share_capture/domain/shared_item.dart';

/// Decides which cards a share becomes (§4.7) — pure. One card per item, in
/// the order shared, appended after the target's last card (§8.7):
/// - text that is a bare http(s) URL → a link card; any other text → a text
///   card; blank text is dropped;
/// - a file → an image / audio / file card by its mime ([CardKind.forFileMime],
///   the same rule as a file picked in the Collection).
class ShareCapturePlanner {
  const ShareCapturePlanner();

  static const Set<String> _linkSchemes = {'http', 'https'};

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
              kind: isBareUrl(trimmed) ? CardKind.link : CardKind.text,
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

  /// Whether [text] is nothing but one http(s) URL with a host.
  static bool isBareUrl(String text) {
    if (text.contains(RegExp(r'\s'))) return false;
    final uri = Uri.tryParse(text);
    return uri != null &&
        _linkSchemes.contains(uri.scheme.toLowerCase()) &&
        uri.host.isNotEmpty;
  }
}
