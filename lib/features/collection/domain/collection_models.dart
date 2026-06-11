/// View-models for the Collection screen (§4.2). These carry **primitives
/// only** — never a `Snapshot` or other sync-core type (widgets.md §1) — so the
/// presentation layer and shared widgets never reach into the merge core.
library;

/// A card's `kind` (spec §6.4). `text` is the everyday quick-capture; `link` is
/// the "+"-block standalone link card; `image`/`audio` arrive with attachments.
enum CardKind {
  text,
  image,
  audio,
  link,
  unknown;

  /// The wire/`content.kind` tag (spec §7.4.3).
  String get tag => this == CardKind.unknown ? 'text' : name;

  /// Resolve a stored `kind` tag; unknown tags degrade to [CardKind.unknown]
  /// rather than throwing, so a newer peer's card kind still renders.
  static CardKind fromTag(String? tag) => switch (tag) {
        'text' => CardKind.text,
        'image' => CardKind.image,
        'audio' => CardKind.audio,
        'link' => CardKind.link,
        _ => CardKind.unknown,
      };
}

/// One card in the feed (spec §4.2 / §8.7). Ordered by [position] (string,
/// lexicographic) then id — the same key the projection [feed] returns.
class FeedCard {
  const FeedCard({
    required this.id,
    required this.kind,
    required this.position,
    this.text,
    this.attachmentId,
  });

  final String id;
  final CardKind kind;

  /// Fractional-index placement key (§8.7). The feed is already sorted by it;
  /// the updater mints new keys between neighbours for append/reorder.
  final String position;

  /// Body text for a text card; the URL/label for a link card; null otherwise.
  final String? text;

  /// `attachment_id` for image/audio cards (§7.4.3); null otherwise.
  final String? attachmentId;

  /// Used by the updater's optimistic reorder to re-stamp [position] locally
  /// before the placement write lands.
  FeedCard copyWith({String? position}) => FeedCard(
        id: id,
        kind: kind,
        position: position ?? this.position,
        text: text,
        attachmentId: attachmentId,
      );
}

/// A link destination offered in the finder sheet (§4.2). For MVP the finder
/// lists the device's other collections; a card can be linked to one.
class LinkCandidate {
  const LinkCandidate({required this.collectionId, required this.title});
  final String collectionId;
  final String title;
}

/// The full Collection screen payload — header + ordered feed + the link-finder
/// candidates, read together so the View never issues a second load.
class CollectionData {
  const CollectionData({
    required this.collectionId,
    required this.title,
    required this.coverAttachmentId,
    required this.cards,
    required this.linkTargets,
  });

  final String collectionId;
  final String title;
  final String? coverAttachmentId;
  final List<FeedCard> cards;
  final List<LinkCandidate> linkTargets;
}
