/// View-models for the Collection screen (§4.2). These carry **primitives
/// only** — never a `Snapshot` or other sync-core type (widgets.md §1) — so the
/// presentation layer and shared widgets never reach into the merge core.
library;

import 'package:knit/features/connections/domain/connections_models.dart';

/// A card's `kind` (spec §6.4). `text` is the everyday quick-capture; `link` is
/// the "+"-block standalone link card; `image`/`audio`/`file` arrive with
/// attachments (`file` is an arbitrary attachment, labelled by its file name).
enum CardKind {
  text,
  image,
  audio,
  file,
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
    'file' => CardKind.file,
    'link' => CardKind.link,
    _ => CardKind.unknown,
  };

  /// Classify a picked file by its declared [mime] into the card kind it should
  /// become (§4.2): an `image/*` file is an [image] card, an `audio/*` file an
  /// [audio] card, and anything else a generic [file] card. Pure — the picker
  /// derives the mime from the extension when the platform omits one, so this is
  /// effectively the "judge it by extension" rule. Lives here (not in a shell)
  /// because it is a business decision (business_logic.md §placement ladder).
  static CardKind forFileMime(String mime) =>
      switch (mime.split('/').first.toLowerCase()) {
        'image' => CardKind.image,
        'audio' => CardKind.audio,
        _ => CardKind.file,
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
    this.fileName,
    this.fileSize,
    this.connectionCount = 0,
  });

  final String id;
  final CardKind kind;

  /// Fractional-index placement key (§8.7). The feed is already sorted by it;
  /// the updater mints new keys between neighbours for append/reorder.
  final String position;

  /// Body text for a text card; the URL/label for a link card; null otherwise.
  final String? text;

  /// `attachment_id` for image/audio/file cards (§7.4.3); null otherwise.
  final String? attachmentId;

  /// For a file card, the attachment's original file name and byte size (§7.4.8),
  /// resolved eagerly into the feed read so the chip can label/size it without a
  /// per-card bytes load. Null for every other kind.
  final String? fileName;
  final int? fileSize;

  /// How many links (§4.4) this card takes part in, counting both directions —
  /// links-out (made *from* this card) and backlinks (made *to* it) — so both
  /// ends of a link surface a badge. A read-time derivation shown under the
  /// bubble so the user can see, at a glance, which cards are woven into the
  /// graph. The two directions are disjoint per card, so a single link is never
  /// double-counted. Zero ⇒ no badge is shown.
  final int connectionCount;

  /// The card's capture time, decoded from the millisecond timestamp in the
  /// leading 48 bits of its UUIDv7 [id] (§6.1) — every minted card id is v7, so
  /// this resolves for real cards. Null when [id] isn't a v7 uuid, so callers
  /// can fall back. Used to date-stamp a shared photo's file name (§4.2).
  DateTime? get capturedAt {
    final hex = id.replaceAll('-', '');
    if (hex.length < 12) return null;
    final ms = int.tryParse(hex.substring(0, 12), radix: 16);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Used by the updater's optimistic reorder to re-stamp [position] locally
  /// before the placement write lands.
  FeedCard copyWith({String? position}) => FeedCard(
    id: id,
    kind: kind,
    position: position ?? this.position,
    text: text,
    attachmentId: attachmentId,
    fileName: fileName,
    fileSize: fileSize,
    connectionCount: connectionCount,
  );
}

/// One selectable target in the link finder — a collection or a card (§4.4).
/// [kind] chooses the wire `target_type`; [label] is its display title/preview.
/// The finder loads collections first, then a collection's [LinkOption] cards on
/// drill, so a card can link to *any* card or collection — not just a collection.
class LinkOption {
  const LinkOption({required this.kind, required this.id, required this.label});

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
    required this.description,
    required this.coverAttachmentId,
    required this.cards,
  });

  final String collectionId;
  final String title;

  /// The collection's optional free-text blurb (spec §3.1); null/empty when unset.
  final String? description;
  final String? coverAttachmentId;
  final List<FeedCard> cards;
}
