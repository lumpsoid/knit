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

/// One staged photo in a [PendingImagesPreview] — a widget-owned view-model
/// (widgets.md §1): its [bytes], and whether the optimiser is working on it.
@immutable
class PendingImageThumb {
  const PendingImageThumb({required this.bytes, this.optimizing = false});

  final Uint8List bytes;
  final bool optimizing;
}

/// The picked-but-unsent photos shown above the composer (§4.2), in pick
/// order: one send makes one image card holding them all. Each thumbnail's ✕
/// drops that photo via [onRemove]; the trailing "+" tile ([onAdd]) picks more.
///
/// Under them sits their size and the opt-in "Optimize size" chip: when it is
/// on, the size shows what the smaller copies save. Optimizing is a phase of
/// its own: the photo being worked on dims under a spinner and the line says
/// what is happening and that it takes a moment (turning the chip off cancels
/// it). [onOptimizeChanged] is null when no photo's format can be optimized,
/// which hides the chip.
class PendingImagesPreview extends StatelessWidget {
  const PendingImagesPreview({
    super.key,
    required this.images,
    required this.size,
    required this.onRemove,
    required this.onAdd,
    this.optimize = false,
    this.optimizedSize,
    this.optimizing = false,
    this.alreadySmall = false,
    this.onOptimizeChanged,
  });
  final List<PendingImageThumb> images;

  /// The photos' total byte size as picked.
  final int size;
  final ValueChanged<int> onRemove;
  final VoidCallback onAdd;

  /// Whether "Optimize size" is on.
  final bool optimize;

  /// The optimized photos' total byte size, once every one is ready.
  final int? optimizedSize;
  final bool optimizing;

  /// Optimizing found nothing worth saving; the originals are sent.
  final bool alreadySmall;
  final ValueChanged<bool>? onOptimizeChanged;

  static const double _thumbSize = 88;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final onOptimizeChanged = this.onOptimizeChanged;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _thumbSize,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => index == images.length
                  ? _AddImageTile(size: _thumbSize, onTap: onAdd)
                  : _PendingThumb(
                      image: images[index],
                      size: _thumbSize,
                      onRemove: () => onRemove(index),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: optimizing
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.collectionImageOptimizing,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.collectionImageOptimizingHint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _sizeLabel(l10n),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
              if (onOptimizeChanged != null) ...[
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(l10n.collectionImageOptimize),
                  selected: optimize,
                  onSelected: onOptimizeChanged,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _sizeLabel(AppLocalizations l10n) {
    final original = formatByteSize(size);
    if (!optimize) return original;
    if (alreadySmall) return '$original · ${l10n.collectionImageAlreadySmall}';
    final optimizedSize = this.optimizedSize;
    if (optimizedSize == null) return original;
    return l10n.collectionImageSizeSaved(
      original,
      formatByteSize(optimizedSize),
    );
  }
}

/// One staged photo: the thumbnail, dimmed under a spinner while it is being
/// optimized, with a ✕ in its corner.
class _PendingThumb extends StatelessWidget {
  const _PendingThumb({
    required this.image,
    required this.size,
    required this.onRemove,
  });

  final PendingImageThumb image;
  final double size;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            image.bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
        if (image.optimizing)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: CircularProgressIndicator()),
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
              onTap: onRemove,
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
    );
  }
}

/// The tile after the staged photos that adds more to the same card.
class _AddImageTile extends StatelessWidget {
  const _AddImageTile({required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: AppLocalizations.of(context).collectionAddMorePhotos,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox.square(
            dimension: size,
            child: Icon(
              Icons.add_photo_alternate_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// The recorded-but-unsent audio clip shown above the composer (§4.2) — the
/// audio twin of [PendingImagesPreview]. Tapping ✕ drops it via [onClear]; the
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
