import 'package:flutter/foundation.dart';
import 'package:knit/features/collection/domain/collection_models.dart';

/// What "+" → Connection makes of the text typed in the composer (§4.2): the
/// trimmed text becomes the new Connection card's label, so a card can be
/// named as it is linked. A label makes it a text card (the [CardKind.forText]
/// rule Card Edit follows too); a short one-line label is still drawn as the
/// tile with a caption, a long or multi-line one as a plain card with a link
/// chip (`LinkTile.targetOf`). Blank text, or a bare URL — a web link the
/// user is about to send, not a name — leaves the input alone and makes the
/// text-less §6.4 link block.
@immutable
class ConnectionCardText {
  const ConnectionCardText._(this.label);

  /// The text-less link block: the composer input is left as it is.
  static const ConnectionCardText none = ConnectionCardText._(null);

  /// The text typed in the composer, read as the new card's text.
  factory ConnectionCardText.of(String composerText) {
    final body = composerText.trim();
    if (body.isEmpty || CardKind.isBareUrl(body)) return none;
    return ConnectionCardText._(body);
  }

  /// The card's label, or null for the text-less link block.
  final String? label;

  /// The new card's kind: a labelled card is a text card.
  CardKind get kind => label == null ? CardKind.link : CardKind.text;

  /// Whether the composer input becomes the label, and so is cleared once
  /// the card is saved (and only then).
  bool get usesInput => label != null;

  @override
  bool operator ==(Object other) =>
      other is ConnectionCardText && other.label == label;

  @override
  int get hashCode => label.hashCode;
}
