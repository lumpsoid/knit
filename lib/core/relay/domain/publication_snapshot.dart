/// The wire contract for publishing a collection to the relay's web view
/// (relay server §2.6 / §4.6). These are **primitives-only** DTOs (widgets.md
/// §1) that mirror, field-for-field, what the Phoenix relay stores and renders:
/// the relay never parses the op log, so the app hands it a ready-to-show
/// view-model and the relay serves it verbatim.
///
/// `SnapshotBuilder` builds a [PublicationSnapshot] from the collection read
/// model; `RelayPublishClient` uploads it (and the referenced blobs).
library;

/// Web publication visibility (relay §4.6). [public] renders the snapshot as a
/// live web page to anyone with the link; [private] shows only an "open in the
/// Knit app" gate — the content stays behind the capability-token pull path.
enum PublishVisibility {
  public,
  private;

  /// The wire tag the relay expects in the `visibility` field.
  String get tag => name;

  /// Resolve a wire tag; anything but `"public"` degrades to [private] (the
  /// safe default — never accidentally expose a collection on the web).
  static PublishVisibility fromTag(String? tag) =>
      tag == 'public' ? PublishVisibility.public : PublishVisibility.private;
}

/// A content-addressed blob reference (relay §7.7): the sha256 [hash] the bytes
/// were uploaded under and their [mime]. Used for a collection cover or an image
/// card; the web page resolves it to `/v1/blobs/<hash>`.
class SnapshotBlob {
  const SnapshotBlob({required this.hash, required this.mime});

  final String hash;
  final String mime;

  Map<String, Object?> toJson() => {'hash': hash, 'mime': mime};
}

/// A file/audio attachment on a card (relay §2.6 `file`): its content [hash],
/// plus the original [name] and byte [size] for labelling the download chip.
class SnapshotFile {
  const SnapshotFile({required this.hash, this.name, this.size});

  final String hash;
  final String? name;
  final int? size;

  Map<String, Object?> toJson() => {
    'hash': hash,
    if (name != null) 'name': name,
    if (size != null) 'size': size,
  };
}

/// A link card's target (relay §2.6 `link`). Knit stores a link card's URL as
/// the card body, so [url] is that verbatim value; [label] is optional.
class SnapshotLink {
  const SnapshotLink({this.label, this.url});

  final String? label;
  final String? url;

  Map<String, Object?> toJson() => {
    if (label != null) 'label': label,
    if (url != null) 'url': url,
  };
}

/// One card in the published feed (relay §2.6). [kind] is the wire tag
/// (`text|image|link|audio|file`); [text] is the body/caption; [image]/[file]/
/// [link] are present per kind. Null sub-objects are omitted, matching the
/// relay's defensive renderer.
class SnapshotCard {
  const SnapshotCard({
    required this.id,
    required this.kind,
    this.text,
    this.image,
    this.file,
    this.link,
  });

  final String id;
  final String kind;
  final String? text;
  final SnapshotBlob? image;
  final SnapshotFile? file;
  final SnapshotLink? link;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    if (text != null) 'text': text,
    if (image != null) 'image': image!.toJson(),
    if (file != null) 'file': file!.toJson(),
    if (link != null) 'link': link!.toJson(),
  };
}

/// The self-contained view-model published for a collection (relay §2.6 /
/// §4.6): header ([title], [description], [cover]) plus the ordered [cards].
class PublicationSnapshot {
  const PublicationSnapshot({
    required this.title,
    this.description,
    this.cover,
    this.cards = const [],
  });

  final String title;
  final String? description;
  final SnapshotBlob? cover;
  final List<SnapshotCard> cards;

  Map<String, Object?> toJson() => {
    'title': title,
    if (description != null) 'description': description,
    if (cover != null) 'cover': cover!.toJson(),
    'cards': [for (final c in cards) c.toJson()],
  };
}
