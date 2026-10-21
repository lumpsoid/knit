import 'package:flutter/foundation.dart';
import 'package:knit/features/collection/domain/collection_link_tile.dart';
import 'package:knit/features/collection/domain/collection_models.dart';

/// What saving a card's text writes (§4.3): the trimmed [text] and, for a
/// Connection card, the [kind] that text calls for.
@immutable
class CardTextEdit {
  const CardTextEdit({required this.text, this.kind});

  /// The new text; null clears it.
  final String? text;

  /// The card's new kind; null keeps it.
  final CardKind? kind;

  /// The edit that saving [text] makes to a card of [kind] with these
  /// attachments and live links out, or null when there is nothing to save.
  ///
  /// A blank text is refused, except on a Connection card: a text or link card
  /// with no attachment whose whole purpose is one link out to a collection
  /// (the [CollectionLinkTile] shape, whatever its text). Its text is a label,
  /// never a URL to open, so blank makes it the §6.4 link block again and a
  /// label a text card — still drawn as the tile while short. A pasted bare
  /// URL makes it a link card, as in the composer.
  static CardTextEdit? of({
    required CardKind kind,
    required String text,
    required List<String> attachmentIds,
    required List<CardLinkOut> linksOut,
  }) {
    final body = text.trim();
    final connection =
        CollectionLinkTile.targetOf(
          kind: kind,
          text: null,
          attachmentIds: attachmentIds,
          linksOut: linksOut,
        ) !=
        null;
    if (!connection) return body.isEmpty ? null : CardTextEdit(text: body);
    return body.isEmpty
        ? const CardTextEdit(text: null, kind: CardKind.link)
        : CardTextEdit(text: body, kind: CardKind.forText(body));
  }

  @override
  bool operator ==(Object other) =>
      other is CardTextEdit && other.text == text && other.kind == kind;

  @override
  int get hashCode => Object.hash(text, kind);
}
