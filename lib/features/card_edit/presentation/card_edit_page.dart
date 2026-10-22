import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:knit/core/attachments/presentation/byte_size.dart';
import 'package:knit/l10n/app_localizations.dart';
import 'package:knit/core/attachments/presentation/attachment_image.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/card_edit/presentation/card_edit_action.dart';
import 'package:knit/features/card_edit/presentation/card_edit_controller.dart';
import 'package:knit/features/card_edit/presentation/card_edit_scope.dart';
import 'package:knit/features/card_edit/presentation/card_edit_state.dart';
import 'package:knit/features/card_edit/presentation/card_edit_ui_effect.dart';
import 'package:knit/features/card_links/domain/card_links_models.dart';
import 'package:knit/features/card_links/presentation/link_picker_sheet.dart';
import 'package:knit/features/connections/domain/connections_models.dart';

/// The Card Edit page (§4.3) — a dedicated page for editing a card's content:
/// its text (saved with the Save action), its image (subtask 4), and its links
/// (subtask 3, incl. card→card). The edit target arrives via the route-args
/// carrier (cross_feature.md §2); on text-save the page pops and the Collection
/// screen resyncs from the projection. Image/link edits are applied in place.
class CardEditPage extends StatefulWidget {
  const CardEditPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const CardEditPage());

  @override
  State<CardEditPage> createState() => _CardEditPageState();
}

class _CardEditPageState extends State<CardEditPage> {
  CardEditController get _controller => CardEditScope.controller;
  late final TextEditingController _field;

  @override
  void initState() {
    super.initState();
    final args = CardEditScope.routeArgs;
    _field = TextEditingController(text: args.initialText);
    _controller
      ..onAttach(_onUiEffect)
      ..dispatch(
        ViewAttached(
          cardId: args.cardId,
          collectionId: args.collectionId,
          initialText: args.initialText,
          initialKind: args.initialKind,
          initialAttachmentId: args.initialAttachmentId,
          initialMoreAttachmentIds: args.initialMoreAttachmentIds,
          initialAttachmentKind: args.initialAttachmentKind,
          initialFileName: args.initialFileName,
          initialFileSize: args.initialFileSize,
          initialSettled: args.initialSettled,
          initialEmphasized: args.initialEmphasized,
        ),
      );
  }

  @override
  void dispose() {
    _controller
      ..dispatch(const DeactivateFeature())
      ..onDetach();
    _field.dispose();
    super.dispose();
  }

  void _onUiEffect(CardEditUiEffect effect) {
    if (!mounted) return;
    switch (effect) {
      case CardEditSavedUiEffect():
        Navigator.of(context).pop();
      case CardEditShowMessageUiEffect(:final message):
        final text = switch (message) {
          CardEditMessage.saveFailed => AppLocalizations.of(
            context,
          ).cardEditSaveFailed,
          CardEditMessage.imageNotSmaller => AppLocalizations.of(
            context,
          ).cardEditImageNotSmaller,
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(text)));
      case CardEditImageOptimizedUiEffect(:final fromBytes, :final toBytes):
        final text = AppLocalizations.of(context).cardEditImageOptimized(
          formatByteSize(fromBytes),
          formatByteSize(toBytes),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  void _save() => _controller.dispatch(SaveRequested(_field.text));

  Future<void> _addLink() async {
    final args = CardEditScope.routeArgs;
    final option = await LinkPickerSheet.show(
      context,
      links: CardEditScope.cardLinks,
      source: LinkSource(cardId: args.cardId, collectionId: args.collectionId),
    );
    if (option == null || !mounted) return;
    _controller.dispatch(switch (option) {
      LinkTargetPicked(:final target) => AddLinkRequested(
        targetKind: target.kind,
        targetId: target.id,
      ),
      // A ✓ target tapped again: the same remove as a link row's.
      LinkTargetUnpicked(:final linkId) => RemoveLinkRequested(linkId),
      LinkToNewCollection(:final title) => AddLinkToNewCollectionRequested(
        title,
      ),
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        _controller.stateHolder,
        CardEditScope.images,
      ]),
      builder: (context, _) {
        final state = _controller.stateHolder.value;
        final saving = state.status == CardEditStatus.saving;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.cardEditTitle),
            actions: [
              saving
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : TextButton(onPressed: _save, child: Text(l10n.actionSave)),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _AttachmentSection(
                state: state,
                images: [
                  for (final id in state.imageIds) CardEditScope.images.of(id),
                ],
                onPickImage: () =>
                    _controller.dispatch(const PickImageRequested()),
                onRemoveImage: (index) => _controller.dispatch(
                  RemoveImageRequested(state.imageIds[index]),
                ),
                onPickFile: () =>
                    _controller.dispatch(const PickFileRequested()),
                onOptimizeImage: () =>
                    _controller.dispatch(const OptimizeImageRequested()),
                onRemove: () =>
                    _controller.dispatch(const RemoveAttachmentRequested()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _field,
                enabled: !saving,
                minLines: 3,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: l10n.cardEditHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              _LinksSection(
                state: state,
                onAdd: _addLink,
                onRemove: (linkId) =>
                    _controller.dispatch(RemoveLinkRequested(linkId)),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(state.settled ? Icons.eco : Icons.eco_outlined),
                title: Text(l10n.cardEditSettled),
                subtitle: Text(l10n.cardEditSettledSubtitle),
                value: state.settled,
                onChanged: state.markBusy
                    ? null
                    : (v) => _controller.dispatch(SettledToggled(v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  state.emphasized
                      ? Icons.auto_awesome
                      : Icons.auto_awesome_outlined,
                ),
                title: Text(l10n.cardEditEmphasized),
                subtitle: Text(l10n.cardEditEmphasizedSubtitle),
                value: state.emphasized,
                onChanged: state.markBusy
                    ? null
                    : (v) => _controller.dispatch(EmphasizedToggled(v)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- attachment section ------------------------------------------------------

/// The card's attachment manager (§4.3, subtask 4). With no attachment it offers
/// two adds — photos (from the gallery, several at once) and any file (routed
/// to image/audio/file by mime). With one, it renders the right representation
/// (the images, an audio chip, or a file chip) over Replace (any file) +
/// Remove. An image card also offers Add photos (more images on the same card,
/// §4.2) and Optimize (swap its images for smaller copies), and with several
/// images each has its own ✕.
class _AttachmentSection extends StatelessWidget {
  const _AttachmentSection({
    required this.state,
    required this.images,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onPickFile,
    required this.onOptimizeImage,
    required this.onRemove,
  });

  final CardEditState state;

  /// An image card's images, decoded from the shared cache (null while
  /// loading); empty for audio/file attachments.
  final List<Uint8List?> images;
  final VoidCallback onPickImage;
  final ValueChanged<int> onRemoveImage;
  final VoidCallback onPickFile;
  final VoidCallback onOptimizeImage;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (state.attachmentBusy) {
      return SizedBox(
        height: 160,
        child: Center(
          child: state.optimizingImage
              ? const _OptimizingImage()
              : const CircularProgressIndicator(),
        ),
      );
    }
    if (!state.hasAttachment) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(l10n.cardEditAddPhoto),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPickFile,
              icon: const Icon(Icons.attach_file),
              label: Text(l10n.cardEditAttachFile),
            ),
          ),
        ],
      );
    }
    final isImage = state.attachmentKind == CardKind.image;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (images.length > 1)
          _ImageGrid(images: images, onRemove: onRemoveImage)
        else
          _AttachmentPreview(state: state, imageBytes: images.firstOrNull),
        const SizedBox(height: 8),
        Row(
          children: [
            // Replace with any file type — the file picker routes by mime, so a
            // card's attachment can switch kind (image → audio, etc.). The
            // adds wrap on a narrow screen rather than squeeze Remove.
            Expanded(
              child: Wrap(
                children: [
                  if (isImage)
                    TextButton.icon(
                      onPressed: onPickImage,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(l10n.cardEditAddPhoto),
                    ),
                  TextButton.icon(
                    onPressed: onPickFile,
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(l10n.cardEditReplace),
                  ),
                  if (isImage)
                    TextButton.icon(
                      onPressed: onOptimizeImage,
                      icon: const Icon(Icons.compress),
                      label: Text(l10n.cardEditOptimize),
                    ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onRemove,
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              label: Text(
                images.length > 1
                    ? l10n.cardEditRemoveAll
                    : l10n.cardEditRemove,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The attachment section while "Optimize" runs: what is happening and that it
/// takes a moment, so the wait doesn't look like a hang.
class _OptimizingImage extends StatelessWidget {
  const _OptimizingImage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text(
          l10n.collectionImageOptimizing,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.collectionImageOptimizingHint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// An image card's several images (§4.2) as a grid of square thumbnails, in
/// order, each with a ✕ that removes it from the card.
class _ImageGrid extends StatelessWidget {
  const _ImageGrid({required this.images, required this.onRemove});

  final List<Uint8List?> images;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final (index, bytes) in images.indexed)
          Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AttachmentImage(bytes: bytes),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: Material(
                  color: theme.colorScheme.surface.withValues(alpha: 0.8),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onRemove(index),
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
      ],
    );
  }
}

/// Renders the current attachment by its kind: an image thumbnail, an audio
/// chip, or a file chip (name + size). An unknown/unloadable kind degrades to a
/// generic attachment chip so the card is still editable.
class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({required this.state, required this.imageBytes});

  final CardEditState state;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    switch (state.attachmentKind) {
      case CardKind.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AttachmentImage(
            bytes: imageBytes,
            height: 220,
            fit: BoxFit.cover,
          ),
        );
      case CardKind.audio:
        return _AttachmentChip(
          icon: Icons.mic,
          label: AppLocalizations.of(context).collectionCardAudio,
        );
      case CardKind.file:
        final l10n = AppLocalizations.of(context);
        final name = state.attachmentName?.trim();
        final size = state.attachmentSize;
        return _AttachmentChip(
          icon: Icons.insert_drive_file_outlined,
          label: name == null || name.isEmpty ? l10n.collectionCardFile : name,
          sublabel: size == null ? null : formatByteSize(size),
        );
      case CardKind.text:
      case CardKind.link:
      case CardKind.unknown:
      case null:
        return _AttachmentChip(
          icon: Icons.attachment,
          label: AppLocalizations.of(context).cardEditAttachment,
        );
    }
  }
}

/// A compact tile for a non-image attachment: a type icon, a primary label, and
/// an optional sublabel (a file's size).
class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({
    required this.icon,
    required this.label,
    this.sublabel,
  });

  final IconData icon;
  final String label;
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (sublabel != null)
                  Text(
                    sublabel!,
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
  }
}

// --- links section ----------------------------------------------------------

class _LinksSection extends StatelessWidget {
  const _LinksSection({
    required this.state,
    required this.onAdd,
    required this.onRemove,
  });

  final CardEditState state;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              l10n.cardEditLinksHeader,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            if (state.linksLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (state.links.isEmpty && !state.linksLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.cardEditNoLinks,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final item in state.links)
          _LinkRow(item: item, onRemove: () => onRemove(item.linkId)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_link),
          label: Text(l10n.cardEditAddLink),
        ),
      ],
    );
  }
}

/// One outgoing-link row. A live link shows the far endpoint's label + kind icon;
/// a broken one (§8.6.1) is error-styled and never hidden. Both offer remove.
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.item, required this.onRemove});

  final ConnectionItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    if (item.broken) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.link_off, color: theme.colorScheme.error),
        title: Text(
          l10n.cardEditBrokenLink,
          style: TextStyle(color: theme.colorScheme.error),
        ),
        subtitle: Text(l10n.cardEditBrokenLinkSubtitle),
        trailing: IconButton(
          tooltip: l10n.actionRemove,
          icon: const Icon(Icons.close),
          onPressed: onRemove,
        ),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_kindIcon(item.otherKind)),
      title: Text(
        item.label?.trim().isNotEmpty == true
            ? item.label!.trim()
            : l10n.labelUntitled,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: l10n.actionRemove,
        icon: const Icon(Icons.close),
        onPressed: onRemove,
      ),
    );
  }

  IconData _kindIcon(ConnectedEntityKind kind) => switch (kind) {
    ConnectedEntityKind.collection => Icons.workspaces_outline,
    ConnectedEntityKind.card => Icons.sticky_note_2_outlined,
    ConnectedEntityKind.unknown => Icons.help_outline,
  };
}

// --- link picker ------------------------------------------------------------

/// Two-level target picker (§4.3, full scope): browse collections, then drill
/// into one to pick a card — or link to the collection itself. The whole tree is
/// already in state, so the drill is local (a [StatefulBuilder]); selecting an
/// option pops it back to the page, which dispatches the add.
