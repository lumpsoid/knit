/// Async-work descriptors for the Card Edit page (fcis.md §6.4).
sealed class CardEditEffect {
  const CardEditEffect();
}

/// Persist the card's edited content (§4.3). [text] is the trimmed body.
class SaveCardEffect extends CardEditEffect {
  const SaveCardEffect(this.cardId, this.text);
  final String cardId;
  final String text;
}
