import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:knit/core/attachments/presentation/attachment_image.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/l10n/app_localizations.dart';

/// A card's row in reorder mode: a thumbnail or drag handle, a one-line label,
/// and the drag grip.
class CardReorderRow extends StatelessWidget {
  const CardReorderRow({
    required this.kind,
    required this.text,
    required this.fileName,
    required this.index,
    required this.imageBytes,
    super.key,
  });
  final CardKind kind;
  final String? text;
  final String? fileName;
  final int index;

  /// Decoded bytes for an image card; null while loading or missing.
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = switch (kind) {
      CardKind.link =>
        text?.isNotEmpty == true ? text! : l10n.collectionCardLink,
      CardKind.image =>
        text?.isNotEmpty == true ? text! : l10n.collectionReorderPhoto,
      CardKind.audio =>
        text?.trim().isNotEmpty == true
            ? text!.trim()
            : (fileName?.trim().isNotEmpty == true
                  ? fileName!.trim()
                  : l10n.collectionCardAudio),
      CardKind.file =>
        fileName?.trim().isNotEmpty == true
            ? fileName!.trim()
            : (text?.trim().isNotEmpty == true
                  ? text!.trim()
                  : l10n.collectionCardFile),
      CardKind.text || CardKind.unknown =>
        text?.trim().isNotEmpty == true ? text! : l10n.labelEmptyNote,
    };
    return ListTile(
      leading: kind == CardKind.image
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
