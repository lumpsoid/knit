import 'package:knit/l10n/app_localizations.dart';

/// The one-line preview of a collection's newest card (§8.6.3): its text, or
/// a kind-based summary ("Photo", "Audio", "Link", "File"). Shared by the Home
/// row and the feed's link tiles and chips (§4.2), so all read the same.
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
      case 'file':
        return l10n.timelinePreviewFile;
      default:
        return kind;
    }
  }

  /// "→ Trips": a link's target in one line (§4.1/§4.2). A null [cardKind]
  /// names a collection titled [name] (blank ⇒ untitled); otherwise a card
  /// by the first line of [name] (its text or file name), else its kind label.
  static String linkTo(
    AppLocalizations l10n, {
    String? cardKind,
    String? name,
  }) {
    final line = (name ?? '').trim().split('\n').first.trim();
    return l10n.linkTo(
      line.isNotEmpty
          ? line
          : cardKind == null
          ? l10n.labelUntitled
          : of(l10n, kind: cardKind),
    );
  }
}
