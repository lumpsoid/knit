import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:knit/core/attachments/presentation/attachment_image.dart';
import 'package:knit/features/audio_playback/presentation/audio_playback_controller.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/l10n/app_localizations.dart';

/// The shared [Hero] tag tying a card's feed thumbnail to its full-screen
/// preview, so the open/close transition flies between the two.
Object imageHeroTag(String cardId) => 'card-image-$cardId';

/// A card's chat bubble in the feed: a note, a link, an image, an audio clip,
/// or a file, with its caption where it has one.
class CardBubble extends StatelessWidget {
  const CardBubble({
    super.key,
    required this.cardId,
    required this.kind,
    required this.text,
    required this.fileName,
    required this.fileSize,
    required this.imageBytes,
    required this.onTap,
    this.onImageTap,
    this.onFileTap,
    this.onLinkTap,
    this.playback,
    this.onToggleAudio,
  });
  final String cardId;
  final CardKind kind;

  /// The card's text: a note's body, a link's URL, or a media card's caption.
  final String? text;

  /// An audio or file card's attachment name and a file card's size.
  final String? fileName;
  final int? fileSize;

  /// Decoded bytes for an image card; null while loading or missing.
  final Uint8List? imageBytes;
  final VoidCallback onTap;

  /// Opens the full-screen image preview; null when the image hasn't loaded yet
  /// (a tap then falls through to [onTap], the card-actions sheet).
  final VoidCallback? onImageTap;

  /// Shares a file card through the system sheet; null for every other kind (a
  /// tap then falls through to [onTap], the card-actions sheet).
  final VoidCallback? onFileTap;

  /// Opens a link card's URL in the browser; null for every other kind and for
  /// label-less link cards (a tap then falls through to [onTap], the
  /// card-actions sheet, so Delete stays reachable).
  final VoidCallback? onLinkTap;

  /// The shared player snapshot for a playable audio card, so its chip flips to
  /// a now-playing state when this card is the one in the player. Null for every
  /// other card kind (and audio cards whose bytes are gone).
  final ValueListenable<PlaybackSnapshot>? playback;

  /// Toggle this audio card's playback (play / pause / replay); null when not a
  /// playable audio card.
  final VoidCallback? onToggleAudio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 64, 4),
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: _content(theme, l10n),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(ThemeData theme, AppLocalizations l10n) {
    switch (kind) {
      case CardKind.link:
        final link = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text?.trim().isNotEmpty == true
                    ? text!.trim()
                    : l10n.collectionCardLink,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        );
        // Tap the link itself to open it in the browser; the gesture consumes
        // the tap so it won't bubble to the actions sheet. A label-less link
        // has no [onLinkTap], so its tap falls through to [onTap].
        final onLinkTap = this.onLinkTap;
        if (onLinkTap == null) return link;
        return GestureDetector(onTap: onLinkTap, child: link);
      case CardKind.image:
        final caption = text?.trim();
        Widget image = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AttachmentImage(
            bytes: imageBytes,
            width: 220,
            height: 220,
            placeholder: _placeholder(
              theme,
              Icons.image_outlined,
              l10n.collectionCardPhoto,
            ),
          ),
        );
        // Tap the image itself to view it full-screen; the Hero ties this
        // thumbnail to the preview so the transition flies between them.
        final onImageTap = this.onImageTap;
        if (onImageTap != null) {
          image = GestureDetector(
            onTap: onImageTap,
            child: Hero(tag: imageHeroTag(cardId), child: image),
          );
        }
        if (caption == null || caption.isEmpty) return image;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            image,
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(caption),
            ),
          ],
        );
      case CardKind.audio:
        final audioCaption = text?.trim();
        final chip = AudioCardChip(
          cardId: cardId,
          name: fileName?.trim(),
          playback: playback,
          onToggle: onToggleAudio,
        );
        if (audioCaption == null || audioCaption.isEmpty) return chip;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            chip,
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(audioCaption),
            ),
          ],
        );
      case CardKind.file:
        final fileCaption = text?.trim();
        final chip = FileCardChip(
          name: fileName,
          size: fileSize,
          onTap: onFileTap,
        );
        if (fileCaption == null || fileCaption.isEmpty) return chip;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            chip,
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(fileCaption),
            ),
          ],
        );
      case CardKind.text:
      case CardKind.unknown:
        return Text(
          text?.trim().isNotEmpty == true ? text!.trim() : l10n.labelEmptyNote,
        );
    }
  }

  Widget _placeholder(ThemeData theme, IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
      const SizedBox(width: 8),
      Text(label),
    ],
  );
}

/// An audio card's in-feed chip. Tapping its icon starts/toggles playback in the
/// shared player; when this card is the one playing it flips — a primary-tinted
/// pause/play icon and a "Now playing" label — so the user can scroll back and
/// find it. [playback] null ⇒ no attachment to play: a plain, static mic chip.
class AudioCardChip extends StatelessWidget {
  const AudioCardChip({
    super.key,
    required this.cardId,
    required this.name,
    required this.playback,
    required this.onToggle,
  });

  final String cardId;

  /// The picked file's name, shown in place of the generic "Audio" label; null
  /// or empty for an in-app recording.
  final String? name;
  final ValueListenable<PlaybackSnapshot>? playback;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final playback = this.playback;
    if (playback == null) {
      return _chip(context, active: false, playing: false, loading: false);
    }
    return ValueListenableBuilder<PlaybackSnapshot>(
      valueListenable: playback,
      builder: (context, snap, _) {
        final active = snap.cardId == cardId;
        return _chip(
          context,
          active: active,
          playing: active && snap.isPlaying,
          loading: active && snap.isLoading,
        );
      },
    );
  }

  Widget _chip(
    BuildContext context, {
    required bool active,
    required bool playing,
    required bool loading,
  }) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = active
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Own circular Material so the tap ripple clips to a circle around the
        // button instead of splashing onto the bubble's rounded rectangle (where
        // it would spill past the left corner and clip square on the right).
        Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkResponse(
            onTap: onToggle,
            containedInkWell: true,
            radius: 30,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: loading
                  ? const SizedBox(
                      width: 48,
                      height: 48,
                      child: Padding(
                        padding: EdgeInsets.all(2),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Icon(
                      playing ? Icons.pause_circle : Icons.play_circle,
                      size: 48,
                      color: color,
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            active
                ? l10n.collectionAudioNowPlaying
                : (name?.isNotEmpty == true ? name! : l10n.collectionCardAudio),
            style: active ? TextStyle(color: color) : null,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// A file card's in-feed chip: a file-type icon, the attachment's name, and its
/// size. Tapping it shares the file through the system sheet (via [onTap]); a
/// null [onTap] (e.g. a missing attachment) leaves it inert so the bubble's own
/// tap (the actions sheet) still fires.
class FileCardChip extends StatelessWidget {
  const FileCardChip({
    super.key,
    required this.name,
    required this.size,
    required this.onTap,
  });

  /// The attachment's file name; null or blank shows the generic label.
  final String? name;

  /// The attachment's size in bytes; null hides it.
  final int? size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final name = this.name?.trim();
    final size = this.size;
    final chip = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: 32,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name == null || name.isEmpty ? l10n.collectionCardFile : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (size != null)
                  Text(
                    _formatBytes(size),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return GestureDetector(onTap: onTap, child: chip);
  }
}

/// A compact, human-readable byte size (e.g. `1.2 MB`). Decimal units, pure.
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = value >= 10
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}
