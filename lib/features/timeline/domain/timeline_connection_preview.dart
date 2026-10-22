import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/domain/link_tile.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/sync/sync.dart';

/// A live card a Connection card may point at, as the Home preview names it:
/// its `kind` tag and text.
typedef PreviewedCard = ({String kind, String? text});

/// The Home row preview of a Connection card (§4.1): when a collection's
/// newest card links to a collection or a card as its whole purpose
/// ([LinkTile.targetOf]), the row reads "→ Trips" (or "→" and the target
/// card's first line) instead of the generic "Link". Pure; the reader feeds it
/// batched reads.
abstract final class TimelineConnectionPreview {
  /// The ids of the newest cards that may be Connection cards — a text or link
  /// card — whose links out the reader loads.
  static List<String> candidates(Iterable<CollectionSummary> summaries) => [
    for (final s in summaries)
      if (s.lastCard case final card?)
        if (_mayLink(CardKind.fromTag(card.kind))) card.id,
  ];

  /// [summaries] with each Connection card's live target attached to its
  /// preview ([CardPreview.linkTarget]), given the candidates' [linksOut] (by
  /// card id) and the live target [cards] (by id, each in a live collection).
  /// A collection target is named by its row among [summaries] (every live
  /// collection is one). A deleted target leaves the preview as it was, so the
  /// row falls back to the generic label.
  static List<CollectionSummary> attach(
    List<CollectionSummary> summaries, {
    required Map<String, List<CardLinkOut>> linksOut,
    required Map<String, PreviewedCard> cards,
  }) {
    final titles = {for (final s in summaries) s.collectionId: s.title};
    return [
      for (final summary in summaries)
        switch (_targetOf(summary.lastCard, linksOut, titles, cards)) {
          final target? => summary.withLastCard(
            summary.lastCard!.withLinkTarget(target),
          ),
          null => summary,
        },
    ];
  }

  static LinkTargetPreview? _targetOf(
    CardPreview? card,
    Map<String, List<CardLinkOut>> linksOut,
    Map<String, String> titles,
    Map<String, PreviewedCard> cards,
  ) {
    if (card == null) return null;
    final kind = CardKind.fromTag(card.kind);
    if (!_mayLink(kind)) return null;
    final target = LinkTile.targetOf(
      kind: kind,
      text: card.text,
      // A text or link card carries no attachment.
      attachmentIds: const [],
      linksOut: linksOut[card.id] ?? const [],
    );
    if (target == null) return null;
    return switch (target.targetKind) {
      ConnectedEntityKind.collection => switch (titles[target.targetId]) {
        final title? => LinkTargetPreview(name: title),
        null => null,
      },
      ConnectedEntityKind.card => switch (cards[target.targetId]) {
        final c? => LinkTargetPreview(cardKind: c.kind, name: c.text),
        null => null,
      },
      ConnectedEntityKind.unknown => null,
    };
  }

  static bool _mayLink(CardKind kind) =>
      kind == CardKind.text || kind == CardKind.link;
}
