/// View-models for the Collection Media overview (§4.2) — a read-only, per-kind
/// view of the media cards already in a collection. Primitives only (widgets.md
/// §1): no `Snapshot` or other sync-core type crosses into the presentation.
library;

import 'package:flutter/foundation.dart';
import 'package:knit/features/collection/domain/collection_models.dart';

/// The overview's tabs. Each media kind maps from exactly one [CardKind]; text
/// cards are not media and have no tab.
enum MediaKind {
  photo,
  audio,
  file,
  link;

  /// The media kind a card of [kind] shows under, or null when the card is not
  /// media (a text note, or an unknown newer kind).
  static MediaKind? fromCardKind(CardKind kind) => switch (kind) {
    CardKind.image => MediaKind.photo,
    CardKind.audio => MediaKind.audio,
    CardKind.file => MediaKind.file,
    CardKind.link => MediaKind.link,
    CardKind.text || CardKind.unknown => null,
  };

  /// The card kind this media kind came from — used to hand a card back to the
  /// Card Edit page.
  CardKind get cardKind => switch (this) {
    MediaKind.photo => CardKind.image,
    MediaKind.audio => CardKind.audio,
    MediaKind.file => CardKind.file,
    MediaKind.link => CardKind.link,
  };

  /// Whether items of this kind carry an attachment (vs a link's URL text).
  bool get hasAttachment => this != MediaKind.link;
}

/// One media card in the overview.
@immutable
class MediaItem {
  const MediaItem._({
    required this.cardId,
    required this.kind,
    required this.capturedAt,
    this.text,
    this.attachmentId,
    this.moreAttachmentIds = const [],
    this.fileName,
    this.fileSize,
  });

  /// Classify a card as a media item, or null when it isn't one: a text note, an
  /// attachment kind whose attachment is gone, or a link with no URL to open.
  static MediaItem? fromCard({
    required String cardId,
    required CardKind cardKind,
    required DateTime capturedAt,
    String? text,
    String? attachmentId,
    List<String> moreAttachmentIds = const [],
    String? fileName,
    int? fileSize,
  }) {
    final kind = MediaKind.fromCardKind(cardKind);
    if (kind == null) return null;
    if (kind.hasAttachment && attachmentId == null) return null;
    if (kind == MediaKind.link && (text?.trim().isEmpty ?? true)) return null;
    return MediaItem._(
      cardId: cardId,
      kind: kind,
      capturedAt: capturedAt,
      text: text,
      attachmentId: kind.hasAttachment ? attachmentId : null,
      moreAttachmentIds: kind == MediaKind.photo ? moreAttachmentIds : const [],
      fileName: fileName,
      fileSize: fileSize,
    );
  }

  final String cardId;
  final MediaKind kind;

  /// When the card was captured (its immutable `created_at`, §6.2) — the sort
  /// and month-grouping key.
  final DateTime capturedAt;

  /// The card body: a caption for photo/audio/file, the URL for a link.
  final String? text;

  /// `attachment_id` for photo/audio/file; null for a link. A photo card's
  /// first image.
  final String? attachmentId;

  /// A photo card's further images after [attachmentId] (§4.2).
  final List<String> moreAttachmentIds;

  /// A photo card's images, in order; empty for every other kind.
  List<String> get photoIds => kind == MediaKind.photo
      ? [?attachmentId, ...moreAttachmentIds]
      : const [];

  /// For audio/file, the attachment's original name and byte size (§7.4.8);
  /// null for an in-app recording and for photos/links.
  final String? fileName;
  final int? fileSize;

  /// The trimmed caption, or null when blank.
  String? get caption {
    final t = text?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  /// A link's URL to open (its trimmed body); null for every other kind.
  String? get url => kind == MediaKind.link ? caption : null;
}

/// One image of a photo card in the overview: the [item] it belongs to and
/// its place [index] on the card (§4.2).
@immutable
class MediaPhoto {
  const MediaPhoto({
    required this.item,
    required this.index,
    required this.attachmentId,
  });

  final MediaItem item;
  final int index;
  final String attachmentId;

  /// Every image of the photo cards among [items], card by card, each card's
  /// images in order.
  static List<MediaPhoto> of(Iterable<MediaItem> items) => [
    for (final item in items)
      for (final (index, id) in item.photoIds.indexed)
        MediaPhoto(item: item, index: index, attachmentId: id),
  ];
}

/// One month's worth of [items] (newest first), headed by [month] (the 1st).
@immutable
class MediaMonth {
  const MediaMonth({required this.month, required this.items});

  final DateTime month;
  final List<MediaItem> items;
}

/// How many items each tab holds.
@immutable
class MediaCounts {
  const MediaCounts({
    this.photos = 0,
    this.audio = 0,
    this.files = 0,
    this.links = 0,
  });

  final int photos;
  final int audio;
  final int files;
  final int links;

  int get total => photos + audio + files + links;
  bool get isEmpty => total == 0;

  int of(MediaKind kind) => switch (kind) {
    MediaKind.photo => photos,
    MediaKind.audio => audio,
    MediaKind.file => files,
    MediaKind.link => links,
  };
}

/// A collection's media, newest first (by capture time, then card id so the
/// order is total).
@immutable
class CollectionMedia {
  CollectionMedia(Iterable<MediaItem> items)
    : items = List.unmodifiable(items.toList()..sort(_newestFirst));

  static final CollectionMedia empty = CollectionMedia(const []);

  final List<MediaItem> items;

  bool get isEmpty => items.isEmpty;

  List<MediaItem> ofKind(MediaKind kind) => [
    for (final item in items)
      if (item.kind == kind) item,
  ];

  MediaCounts get counts {
    var photos = 0, audio = 0, files = 0, links = 0;
    for (final item in items) {
      switch (item.kind) {
        case MediaKind.photo:
          photos += item.photoIds.length;
        case MediaKind.audio:
          audio++;
        case MediaKind.file:
          files++;
        case MediaKind.link:
          links++;
      }
    }
    return MediaCounts(
      photos: photos,
      audio: audio,
      files: files,
      links: links,
    );
  }

  /// Every image of the photo cards, newest card first.
  List<MediaPhoto> get photos => MediaPhoto.of(ofKind(MediaKind.photo));

  /// The newest [count] photos — the summary row's thumbnail strip.
  List<MediaPhoto> recentPhotos(int count) => photos.take(count).toList();

  MediaItem? byCardId(String cardId) {
    for (final item in items) {
      if (item.cardId == cardId) return item;
    }
    return null;
  }

  /// Group [items] (already newest first) under month headers, newest month
  /// first.
  static List<MediaMonth> byMonth(List<MediaItem> items) {
    final months = <MediaMonth>[];
    DateTime? current;
    var bucket = <MediaItem>[];
    for (final item in items) {
      final month = DateTime(item.capturedAt.year, item.capturedAt.month);
      if (month != current) {
        if (current != null) {
          months.add(MediaMonth(month: current, items: bucket));
        }
        current = month;
        bucket = <MediaItem>[];
      }
      bucket.add(item);
    }
    if (current != null) months.add(MediaMonth(month: current, items: bucket));
    return months;
  }

  static int _newestFirst(MediaItem a, MediaItem b) {
    final byTime = b.capturedAt.compareTo(a.capturedAt);
    return byTime != 0 ? byTime : b.cardId.compareTo(a.cardId);
  }
}
