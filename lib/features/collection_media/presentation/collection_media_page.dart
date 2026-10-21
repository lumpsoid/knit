import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:knit/features/card_edit/presentation/card_edit_page.dart';
import 'package:knit/features/audio_playback/presentation/audio_mini_player.dart';
import 'package:knit/features/audio_playback/presentation/audio_playback_controller.dart';
import 'package:knit/features/collection/presentation/image_gallery_page.dart';
import 'package:knit/features/collection_media/domain/collection_media_models.dart';
import 'package:knit/features/collection_media/presentation/collection_media_action.dart';
import 'package:knit/features/collection_media/presentation/collection_media_controller.dart';
import 'package:knit/features/collection_media/presentation/collection_media_scope.dart';
import 'package:knit/features/collection_media/presentation/collection_media_state.dart';
import 'package:knit/features/collection_media/presentation/collection_media_ui_effect.dart';
import 'package:knit/l10n/app_localizations.dart';

/// The Collection Media page (§4.2) — a read-only overview of a collection's
/// media cards, one tab per kind (photos · audio · files · links), newest first
/// under month headers. Tapping opens the item (photo → zoom gallery, audio →
/// the shared player, file → share sheet, link → browser); a long-press opens
/// the item's card in the Card Edit page. The target arrives via the route-args
/// carrier (cross_feature.md §2).
class CollectionMediaPage extends StatefulWidget {
  const CollectionMediaPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const CollectionMediaPage());

  @override
  State<CollectionMediaPage> createState() => _CollectionMediaPageState();
}

class _CollectionMediaPageState extends State<CollectionMediaPage> {
  CollectionMediaController get _controller => CollectionMediaScope.controller;
  AudioPlaybackController get _playback =>
      CollectionMediaScope.playbackController;

  @override
  void initState() {
    super.initState();
    _controller
      ..onAttach(_onUiEffect)
      ..dispatch(
        ViewAttached(collectionId: CollectionMediaScope.routeArgs.collectionId),
      );
  }

  @override
  void dispose() {
    _controller
      ..dispatch(const DeactivateFeature())
      ..onDetach();
    super.dispose();
  }

  void _onUiEffect(CollectionMediaUiEffect effect) {
    if (!mounted) return;
    switch (effect) {
      case CollectionMediaShowMessageUiEffect(:final message):
        final l10n = AppLocalizations.of(context);
        final text = switch (message) {
          CollectionMediaMessage.linkOpenFailed =>
            l10n.collectionLinkOpenFailed,
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  /// Hand the item's card to the Card Edit carrier (cross_feature.md §2) and
  /// open it (§4.3); on return, re-read — the edit may have changed or removed
  /// the media.
  Future<void> _openCard(MediaItem item) async {
    CollectionMediaScope.cardEditRouteArgsWriter.open(
      cardId: item.cardId,
      collectionId: CollectionMediaScope.routeArgs.collectionId,
      initialText: item.text ?? '',
      initialAttachmentId: item.attachmentId,
      initialMoreAttachmentIds: item.moreAttachmentIds,
      initialAttachmentKind: item.attachmentId == null
          ? null
          : item.kind.cardKind,
      initialFileName: item.fileName,
      initialFileSize: item.fileSize,
    );
    await Navigator.of(context).push(CardEditPage.route());
    if (mounted) _controller.dispatch(const ReloadRequested());
  }

  /// Open the swipeable zoom gallery over every loaded photo (newest card
  /// first), starting at [start].
  void _openGallery(CollectionMediaState state, MediaPhoto start) {
    final images = <GalleryImage>[];
    var initialIndex = 0;
    for (final photo in state.media.photos) {
      final bytes = CollectionMediaScope.images.of(photo.attachmentId);
      if (bytes == null) continue;
      if (photo.attachmentId == start.attachmentId) {
        initialIndex = images.length;
      }
      images.add(
        GalleryImage(
          bytes: bytes,
          heroTag: _photoHeroTag(photo),
          caption: photo.item.caption,
        ),
      );
    }
    if (images.isEmpty) return;
    Navigator.of(
      context,
    ).push(ImageGalleryPage.route(images: images, initialIndex: initialIndex));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: MediaKind.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.collectionMediaTitle),
          bottom: TabBar(
            tabs: [
              for (final kind in MediaKind.values)
                Tab(text: _tabLabel(l10n, kind)),
            ],
          ),
        ),
        // The grid also follows the shared image cache, so thumbnails appear as
        // their bytes land.
        body: ListenableBuilder(
          listenable: Listenable.merge([
            _controller.stateHolder,
            CollectionMediaScope.images,
          ]),
          builder: (context, _) => _body(_controller.stateHolder.value),
        ),
        bottomNavigationBar: ValueListenableBuilder<PlaybackSnapshot>(
          valueListenable: _playback.snapshot,
          builder: (context, snap, _) {
            if (!snap.isActive) return const SizedBox.shrink();
            return SafeArea(
              child: AudioMiniPlayer(
                phase: snap.phase,
                position: snap.position,
                duration: snap.duration,
                onPlayPause: () => unawaited(_playback.togglePlayPause()),
                onSeek: (d) => unawaited(_playback.seek(d)),
                onClose: () => unawaited(_playback.close()),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _body(CollectionMediaState state) => switch (state.status) {
    CollectionMediaStatus.loading => const Center(
      child: CircularProgressIndicator(),
    ),
    CollectionMediaStatus.failed => _LoadFailed(
      onRetry: () => _controller.dispatch(const ReloadRequested()),
    ),
    CollectionMediaStatus.ready => TabBarView(
      children: [for (final kind in MediaKind.values) _tab(state, kind)],
    ),
  };

  Widget _tab(CollectionMediaState state, MediaKind kind) {
    final items = state.media.ofKind(kind);
    if (items.isEmpty) return const _EmptyTab();
    final months = CollectionMedia.byMonth(items);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final monthFormat = DateFormat.yMMMM(locale);
    return CustomScrollView(
      key: PageStorageKey<MediaKind>(kind),
      slivers: [
        for (final month in months) ...[
          SliverToBoxAdapter(
            child: _MonthHeader(label: monthFormat.format(month.month)),
          ),
          if (kind == MediaKind.photo)
            _photoGrid(state, month.items)
          else
            SliverList.builder(
              itemCount: month.items.length,
              itemBuilder: (context, i) => _row(month.items[i], locale),
            ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  Widget _photoGrid(CollectionMediaState state, List<MediaItem> items) {
    final photos = MediaPhoto.of(items);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: photos.length,
        itemBuilder: (context, i) {
          final photo = photos[i];
          final bytes = CollectionMediaScope.images.of(photo.attachmentId);
          return _PhotoTile(
            heroTag: _photoHeroTag(photo),
            bytes: bytes,
            missing: CollectionMediaScope.images.isMissing(photo.attachmentId),
            onTap: bytes == null ? null : () => _openGallery(state, photo),
            onLongPress: () => _openCard(photo.item),
          );
        },
      ),
    );
  }

  Widget _row(MediaItem item, String locale) {
    final date = DateFormat.yMMMd(locale).format(item.capturedAt);
    return switch (item.kind) {
      MediaKind.audio => _AudioRow(
        cardId: item.cardId,
        title: item.fileName,
        caption: item.caption,
        date: date,
        playback: _playback.snapshot,
        onTap: () =>
            unawaited(_playback.toggle(item.cardId, item.attachmentId!)),
        onLongPress: () => _openCard(item),
      ),
      MediaKind.file => _FileRow(
        name: item.fileName,
        size: item.fileSize,
        caption: item.caption,
        date: date,
        onTap: () => _controller.dispatch(FileShareRequested(item.cardId)),
        onLongPress: () => _openCard(item),
      ),
      MediaKind.link => _LinkRow(
        url: item.url ?? '',
        date: date,
        onTap: () => _controller.dispatch(LinkOpenRequested(item.cardId)),
        onLongPress: () => _openCard(item),
      ),
      // Photos render in the grid, never as a row.
      MediaKind.photo => const SizedBox.shrink(),
    };
  }

  static String _tabLabel(AppLocalizations l10n, MediaKind kind) =>
      switch (kind) {
        MediaKind.photo => l10n.collectionMediaTabPhotos,
        MediaKind.audio => l10n.collectionMediaTabAudio,
        MediaKind.file => l10n.collectionMediaTabFiles,
        MediaKind.link => l10n.collectionMediaTabLinks,
      };
}

/// Hero tag shared by a photo tile and its gallery page. Distinct from the
/// Collection feed's tags so the two routes never collide.
Object _photoHeroTag(MediaPhoto photo) =>
    'media-photo-${photo.item.cardId}-${photo.index}';

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A square photo thumbnail. [bytes] null ⇒ still loading, or [missing] (the
/// blob isn't on this device yet) — a broken-image placeholder.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.heroTag,
    required this.bytes,
    required this.missing,
    required this.onTap,
    required this.onLongPress,
  });

  /// Decoded thumbnail width — a third of a phone screen at 3x is ~400px.
  static const int _cacheWidth = 400;

  final Object heroTag;
  final Uint8List? bytes;
  final bool missing;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = bytes;
    final Widget content = data == null
        ? ColoredBox(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Center(
              child: Icon(
                missing ? Icons.broken_image_outlined : Icons.image_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        : Hero(
            tag: heroTag,
            child: Image.memory(
              data,
              fit: BoxFit.cover,
              cacheWidth: _cacheWidth,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) =>
                  const Center(child: Icon(Icons.broken_image_outlined)),
            ),
          );
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: content,
    );
  }
}

/// An audio item: a play/pause button bound to the shared player, the picked
/// file's name (or "Audio" for a recording), and its caption/date.
class _AudioRow extends StatelessWidget {
  const _AudioRow({
    required this.cardId,
    required this.title,
    required this.caption,
    required this.date,
    required this.playback,
    required this.onTap,
    required this.onLongPress,
  });

  final String cardId;
  final String? title;
  final String? caption;
  final String date;
  final ValueListenable<PlaybackSnapshot> playback;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = title?.trim();
    return ValueListenableBuilder<PlaybackSnapshot>(
      valueListenable: playback,
      builder: (context, snap, _) {
        final active = snap.cardId == cardId;
        final color = active
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant;
        return ListTile(
          leading: active && snap.isLoading
              ? const SizedBox(
                  width: 40,
                  height: 40,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Icon(
                  active && snap.isPlaying
                      ? Icons.pause_circle
                      : Icons.play_circle,
                  size: 40,
                  color: color,
                ),
          title: Text(
            active
                ? l10n.collectionAudioNowPlaying
                : (name == null || name.isEmpty
                      ? l10n.collectionCardAudio
                      : name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: active ? TextStyle(color: color) : null,
          ),
          subtitle: _subtitle(caption, date),
          onTap: onTap,
          onLongPress: onLongPress,
        );
      },
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.name,
    required this.size,
    required this.caption,
    required this.date,
    required this.onTap,
    required this.onLongPress,
  });

  final String? name;
  final int? size;
  final String? caption;
  final String date;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final label = name?.trim();
    final size = this.size;
    return ListTile(
      leading: Icon(
        Icons.insert_drive_file_outlined,
        size: 32,
        color: theme.colorScheme.primary,
      ),
      title: Text(
        label == null || label.isEmpty ? l10n.collectionCardFile : label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: _subtitle(
        caption,
        size == null ? date : '${_formatBytes(size)} · $date',
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.url,
    required this.date,
    required this.onTap,
    required this.onLongPress,
  });

  final String url;
  final String date;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(Icons.link, size: 32, color: theme.colorScheme.primary),
      title: Text(url, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(date),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

/// A row's subtitle: the caption (if any) above the [meta] line.
Widget _subtitle(String? caption, String meta) => caption == null
    ? Text(meta)
    : Text('$caption\n$meta', maxLines: 3, overflow: TextOverflow.ellipsis);

class _EmptyTab extends StatelessWidget {
  const _EmptyTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        AppLocalizations.of(context).collectionMediaEmptyTab,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.collectionMediaLoadFailed),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: Text(l10n.actionRetry)),
        ],
      ),
    );
  }
}

/// A compact, human-readable byte size (e.g. `1.2 MB`). Pure.
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value < 10 ? 1 : 0)} ${units[unit]}';
}
