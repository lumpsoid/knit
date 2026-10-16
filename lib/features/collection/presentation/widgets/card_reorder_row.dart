import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:knit/core/attachments/presentation/attachment_image.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/l10n/app_localizations.dart';

class CardReorderRow extends StatelessWidget {
  const CardReorderRow({
    required this.card,
    required this.index,
    required this.imageBytes,
    super.key,
  });
  final FeedCard card;
  final int index;

  /// Decoded bytes for an image card; null while loading or missing.
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = switch (card.kind) {
      CardKind.link =>
        card.text?.isNotEmpty == true ? card.text! : l10n.collectionCardLink,
      CardKind.image =>
        card.text?.isNotEmpty == true
            ? card.text!
            : l10n.collectionReorderPhoto,
      CardKind.audio =>
        card.text?.trim().isNotEmpty == true
            ? card.text!.trim()
            : (card.fileName?.trim().isNotEmpty == true
                  ? card.fileName!.trim()
                  : l10n.collectionCardAudio),
      CardKind.file =>
        card.fileName?.trim().isNotEmpty == true
            ? card.fileName!.trim()
            : (card.text?.trim().isNotEmpty == true
                  ? card.text!.trim()
                  : l10n.collectionCardFile),
      CardKind.text || CardKind.unknown =>
        card.text?.trim().isNotEmpty == true ? card.text! : l10n.labelEmptyNote,
    };
    return ListTile(
      key: ValueKey('tile-${card.id}'),
      leading: card.kind == CardKind.image
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: AttachmentImage(
                bytes: imageBytes,
                width: 24,
                height: 24,
                placeholder: const Icon(Icons.image_outlined),
              ),
            )
          : const Icon(Icons.drag_handle),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_indicator),
      ),
    );
  }
}
