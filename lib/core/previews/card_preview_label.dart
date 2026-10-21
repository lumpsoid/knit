import 'package:knit/l10n/app_localizations.dart';

/// The one-line preview of a collection's newest card (§8.6.3): its text, or
/// a kind-based summary ("Photo", "Audio", "Link"). Shared by the Home row and
/// the feed's collection-link tile (§4.2), so both read the same.
abstract final class CardPreviewLabel {
  /// The label for a card of `kind` tag [kind] with [text]; a null [kind]
  /// means the collection has no cards yet.
  static String of(AppLocalizations l10n, {String? kind, String? text}) {
    switch (kind) {
      case null:
        return l10n.timelineNoCardsYet;
      case 'text':
        final t = text?.trim() ?? '';
        return t.isEmpty ? l10n.labelEmptyNote : t;
      case 'image':
        return l10n.timelinePreviewPhoto;
      case 'audio':
        return l10n.timelinePreviewAudio;
      case 'link':
        return l10n.timelinePreviewLink;
      default:
        return kind;
    }
  }
}
