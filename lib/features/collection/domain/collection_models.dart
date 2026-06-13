/// View-models for the Collection screen (§4.2). These carry **primitives
/// only** — never a `Snapshot` or other sync-core type (widgets.md §1) — so the
/// presentation layer and shared widgets never reach into the merge core.
library;

import 'package:knit/features/connections/domain/connections_models.dart';

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

/// One selectable target in the link finder — a collection or a card (§4.4).
/// [kind] chooses the wire `target_type`; [label] is its display title/preview.
/// The finder loads collections first, then a collection's [LinkOption] cards on
/// drill, so a card can link to *any* card or collection — not just a collection.
class LinkOption {
  const LinkOption({
    required this.kind,
    required this.id,
    required this.label,
  });

  final ConnectedEntityKind kind;
  final String id;
  final String label;
}

/// The Collection screen payload — header + ordered feed. The link-finder
/// targets are loaded lazily (per level) when the finder opens, so they are not
/// part of this read.
class CollectionData {
  const CollectionData({
    required this.collectionId,
    required this.title,
    required this.coverAttachmentId,
    required this.cards,
  });

  final String collectionId;
  final String title;
  final String? coverAttachmentId;
  final List<FeedCard> cards;
}
