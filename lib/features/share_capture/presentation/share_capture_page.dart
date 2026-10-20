import 'dart:io';

import 'package:flutter/material.dart';
import 'package:knit/features/new_collection/new_collection.dart';
import 'package:knit/features/share_capture/domain/share_capture_models.dart';
import 'package:knit/features/share_capture/domain/shared_item.dart';
import 'package:knit/features/share_capture/presentation/share_capture_controller.dart';
import 'package:knit/features/share_capture/presentation/share_capture_state.dart';
import 'package:knit/l10n/app_localizations.dart';

/// The share-sheet capture screen (§4.7): previews what another app shared and
/// lets the user pick a collection — or create one — to save it into. Pops
/// with the [ShareCaptureSaved] result, or null when dismissed. Takes ownership
/// of [controller] and disposes it with the page.
class ShareCapturePage extends StatefulWidget {
  const ShareCapturePage({super.key, required this.controller});

  final ShareCaptureController controller;

  static Route<ShareCaptureSaved> route(ShareCaptureController controller) =>
      MaterialPageRoute<ShareCaptureSaved>(
        fullscreenDialog: true,
        builder: (_) => ShareCapturePage(controller: controller),
      );

  @override
  State<ShareCapturePage> createState() => _ShareCapturePageState();
}

class _ShareCapturePageState extends State<ShareCapturePage> {
  ShareCaptureController get _controller => widget.controller;

  /// The "New collection" row the title line grows out of.
  final _newRowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveTo(ShareTarget target) =>
      _finish(_controller.saveTo(target));

  /// The "New collection" row grows into the title line (§4.1). A title that
  /// reads like an existing collection offers to save there instead.
  Future<void> _saveToNew() async {
    final box = _newRowKey.currentContext?.findRenderObject() as RenderBox?;
    final targets = _controller.state.targets;
    final choice = await showNewCollectionBar(
      context,
      origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      originColor: Theme.of(context).colorScheme.surface,
      originRadius: 0,
      existing: [
        for (final t in targets)
          CollectionTitle(collectionId: t.collectionId, title: t.title),
      ],
      existingActionLabel: AppLocalizations.of(context).newCollectionSaveThere,
    );
    if (!mounted) return;
    switch (choice) {
      case NewCollectionCreate(:final title):
        await _finish(_controller.saveToNew(title));
      case NewCollectionUseExisting(:final collectionId):
        await _saveTo(
          targets.firstWhere((t) => t.collectionId == collectionId),
        );
      case null:
        break;
    }
  }

  Future<void> _finish(Future<ShareCaptureSaved?> save) async {
    final saved = await save;
    if (!mounted) return;
    if (saved != null) {
      Navigator.of(context).pop(saved);
      return;
    }
    if (_controller.state.saveFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).shareCaptureSaveError),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _controller.state,
      builder: (context, _) {
        final state = _controller.state;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: l10n.actionCancel,
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(l10n.shareCaptureTitle),
            bottom: state.saving
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(4),
                    child: LinearProgressIndicator(),
                  )
                : null,
          ),
          body: AbsorbPointer(
            absorbing: state.saving,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SharedPreview(items: _controller.items),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    onChanged: _controller.filter,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: l10n.shareCaptureSearchHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                ListTile(
                  key: _newRowKey,
                  leading: const Icon(Icons.add),
                  title: Text(l10n.shareCaptureNewCollection),
                  onTap: _saveToNew,
                ),
                const Divider(height: 1),
                Expanded(child: _targets(l10n, state)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _targets(AppLocalizations l10n, ShareCaptureState state) {
    switch (state.status) {
      case ShareCaptureStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case ShareCaptureStatus.failed:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.shareCaptureLoadError),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _controller.load,
                child: Text(l10n.actionRetry),
              ),
            ],
          ),
        );
      case ShareCaptureStatus.ready:
        final targets = state.visibleTargets;
        if (targets.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                state.targets.isEmpty
                    ? l10n.shareCaptureEmpty
                    : l10n.shareCaptureNoMatches,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.builder(
          itemCount: targets.length,
          itemBuilder: (context, i) {
            final target = targets[i];
            return ListTile(
              leading: const Icon(Icons.collections_bookmark_outlined),
              title: Text(
                target.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _saveTo(target),
            );
          },
        );
    }
  }
}

/// A horizontal strip previewing each shared item: a thumbnail for an image,
/// the start of the text for text, an icon and name for any other file.
class _SharedPreview extends StatelessWidget {
  const _SharedPreview({required this.items});

  final List<SharedItem> items;

  static const double _height = 96;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            l10n.shareCaptureItemCount(items.length),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        SizedBox(
          height: _height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _PreviewTile(item: items[i]),
          ),
        ),
      ],
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.item});

  final SharedItem item;

  static const double _size = _SharedPreview._height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final Widget content = switch (item) {
      SharedText(:final text) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          text.trim(),
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall,
        ),
      ),
      SharedFile(:final path, :final mime) when mime.startsWith('image/') =>
        Image.file(
          File(path),
          fit: BoxFit.cover,
          cacheWidth: 256,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
        ),
      SharedFile(:final name, :final mime) => Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              mime.startsWith('audio/')
                  ? Icons.audiotrack_outlined
                  : Icons.insert_drive_file_outlined,
            ),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: _size,
        height: _size,
        color: scheme.surfaceContainerHighest,
        child: content,
      ),
    );
  }
}
