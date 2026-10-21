import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:knit/core/attachments/presentation/byte_size.dart';
import 'package:knit/l10n/app_localizations.dart';

/// The inline photo-source options shown above the composer when the user
/// chose Photo from "+": gallery on the left, camera on the right (§4.2). Takes
/// primitives only (widgets.md §1) — two callbacks, one per source.
class PhotoSourceOptions extends StatelessWidget {
  const PhotoSourceOptions({
    super.key,
    required this.onGallery,
    required this.onCamera,
  });
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: onGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(l10n.collectionPhotoSourceGallery),
            ),
            TextButton.icon(
              onPressed: onCamera,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(l10n.collectionPhotoSourceCamera),
            ),
          ],
        ),
      ),
    );
  }
}

/// The picked-but-unsent image shown above the composer (§4.2). Tapping ✕ drops
/// it via [onClear]; the user keeps composing text or picks another from "+".
///
/// Beside it sits the photo's size and the opt-in "Optimize size" chip: when it
/// is on, the size shows what the smaller copy saves. [onOptimizeChanged] is
/// null for a format that can't be optimized, which hides the chip.
class PendingImagePreview extends StatelessWidget {
  const PendingImagePreview({
    super.key,
    required this.bytes,
    required this.onClear,
    this.optimize = false,
    this.optimizedSize,
    this.optimizing = false,
    this.alreadySmall = false,
    this.onOptimizeChanged,
  });
  final Uint8List bytes;
  final VoidCallback onClear;

  /// Whether "Optimize size" is on.
  final bool optimize;

  /// The optimized copy's byte size, once it is ready.
  final int? optimizedSize;
  final bool optimizing;

  /// Optimizing found nothing worth saving; the original is sent.
  final bool alreadySmall;
  final ValueChanged<bool>? onOptimizeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final onOptimizeChanged = this.onOptimizeChanged;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  bytes,
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: Material(
                  color: theme.colorScheme.surface.withValues(alpha: 0.8),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onClear,
                    child: Tooltip(
                      message: l10n.actionRemove,
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.close, size: 18),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sizeLabel(l10n),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (onOptimizeChanged != null) ...[
                  const SizedBox(height: 4),
                  FilterChip(
                    label: Text(l10n.collectionImageOptimize),
                    selected: optimize,
                    onSelected: optimizing ? null : onOptimizeChanged,
                    avatar: optimizing
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _sizeLabel(AppLocalizations l10n) {
    final original = formatByteSize(bytes.length);
    if (!optimize) return original;
    if (optimizing) return '$original · ${l10n.collectionImageOptimizing}';
    if (alreadySmall) return '$original · ${l10n.collectionImageAlreadySmall}';
    final optimizedSize = this.optimizedSize;
    if (optimizedSize == null) return original;
    return l10n.collectionImageSizeSaved(
      original,
      formatByteSize(optimizedSize),
    );
  }
}

/// The recorded-but-unsent audio clip shown above the composer (§4.2) — the
/// audio twin of [PendingImagePreview]. Tapping ✕ drops it via [onClear]; the
/// user can add a caption first, then send.
class PendingAudioPreview extends StatelessWidget {
  const PendingAudioPreview({super.key, required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.mic, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(l10n.collectionAudioMessage)),
            IconButton(
              tooltip: l10n.actionRemove,
              icon: const Icon(Icons.close),
              onPressed: onClear,
            ),
          ],
        ),
      ),
    );
  }
}

/// The picked-but-unsent file shown above the composer (§4.2) — the file twin of
/// [PendingAudioPreview]. Shows the file's name; tapping ✕ drops it via
/// [onClear]. The user can add a caption first, then send.
class PendingFilePreview extends StatelessWidget {
  const PendingFilePreview({
    super.key,
    required this.name,
    required this.onClear,
  });
  final String name;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              tooltip: AppLocalizations.of(context).actionRemove,
              icon: const Icon(Icons.close),
              onPressed: onClear,
            ),
          ],
        ),
      ),
    );
  }
}
