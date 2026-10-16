/// View-models for the Collection screen (§4.2). These carry **primitives
/// only** — never a `Snapshot` or other sync-core type (widgets.md §1) — so the
/// presentation layer and shared widgets never reach into the merge core.
library;

import 'package:flutter/foundation.dart';

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

  /// For a file or audio card, the attachment's original file name and byte size
  /// (§7.4.8), resolved eagerly into the feed read so the chip can label/size it
  /// without a per-card bytes load. The name is null for an in-app recording
  /// (no original name) and for every other kind.
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

/// The Collection screen payload — header + ordered feed.
class CollectionData {
  const CollectionData({
    required this.collectionId,
    required this.title,
    required this.description,
    required this.coverAttachmentId,
    required this.cards,
    this.olderBoundary,
    this.connectionCount = 0,
  });

  final String collectionId;
  final String title;

  /// The collection's optional free-text blurb (spec §3.1); null/empty when unset.
  final String? description;
  final String? coverAttachmentId;

  /// The loaded window of the feed, oldest → newest — the whole feed for
  /// [FeedWindow.all], otherwise its newest end.
  final List<FeedCard> cards;

  /// The key of the newest card older than [cards]; null when [cards] reaches
  /// the head of the feed (see [FeedPage.olderBoundary]).
  final FeedCursor? olderBoundary;

  /// How many links (§4.4) the collection *itself* takes part in — links-out
  /// plus backlinks (things linked to it), counted once each like a card's
  /// [FeedCard.connectionCount]. Surfaced on the title card; zero ⇒ no badge.
  final int connectionCount;
}

/// A card's feed sort key (§8.7) — [position], then [id] breaking ties. The
/// keyset cursor the paged feed reads from (primitives only, widgets.md §1).
@immutable
class FeedCursor {
  const FeedCursor(this.position, this.id);

  /// The cursor of a loaded [card].
  FeedCursor.of(FeedCard card) : this(card.position, card.id);

  final String position;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is FeedCursor && other.position == position && other.id == id;

  @override
  int get hashCode => Object.hash(position, id);
}

/// Which slice of a collection's feed to read (§8.7). A large collection is
/// never read whole by the screen: it holds a contiguous **newest-end** window
/// (so append keys and the chat-style bottom stay exact) and pages older cards
/// in as the user scrolls up.
sealed class FeedWindow {
  const FeedWindow();

  /// Every live card — for consumers that need the whole collection (relay).
  const factory FeedWindow.all() = AllFeedWindow;

  /// The newest [limit] cards — a fresh entry into the collection.
  const factory FeedWindow.latest(int limit) = LatestFeedWindow;

  /// Every card at or newer than [cursor] — a resync that keeps the window the
  /// user has already scrolled through.
  const factory FeedWindow.from(FeedCursor cursor) = FromFeedWindow;

  /// The newest cards down to (and including) card [cardId], and at least
  /// [minLimit] of them — an entry that must reveal an older card (search hit).
  /// Falls back to [FeedWindow.latest] when the card isn't live here.
  const factory FeedWindow.through(String cardId, int minLimit) =
      ThroughFeedWindow;
}

class AllFeedWindow extends FeedWindow {
  const AllFeedWindow();
}

class LatestFeedWindow extends FeedWindow {
  const LatestFeedWindow(this.limit);
  final int limit;
}

class FromFeedWindow extends FeedWindow {
  const FromFeedWindow(this.cursor);
  final FeedCursor cursor;
}

class ThroughFeedWindow extends FeedWindow {
  const ThroughFeedWindow(this.cardId, this.minLimit);
  final String cardId;
  final int minLimit;
}

/// A run of cards in feed order (oldest → newest) plus the key of the card
/// just *before* it. [olderBoundary] is null when nothing older exists (the
/// window reaches the head of the feed); otherwise it both says "more to load"
/// and gives a reorder to the top of the window a lower bound, so a moved card
/// never jumps past unloaded ones (§8.7).
class FeedPage {
  const FeedPage({required this.cards, this.olderBoundary});

  final List<FeedCard> cards;
  final FeedCursor? olderBoundary;
}
