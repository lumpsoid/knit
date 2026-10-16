import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
          initialText: args.initialText,
          initialAttachmentId: args.initialAttachmentId,
          initialAttachmentKind: args.initialAttachmentKind,
          initialFileName: args.initialFileName,
          initialFileSize: args.initialFileSize,
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
        };
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
    _controller.dispatch(
      AddLinkRequested(targetKind: option.kind, targetId: option.id),
    );
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
                imageBytes: state.attachmentKind == CardKind.image
                    ? CardEditScope.images.of(state.attachmentId!)
                    : null,
                onPickImage: () =>
                    _controller.dispatch(const PickImageRequested()),
                onPickFile: () =>
                    _controller.dispatch(const PickFileRequested()),
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
            ],
          ),
        );
      },
    );
  }
}

// --- attachment section ------------------------------------------------------

/// The card's attachment manager (§4.3, subtask 4). With no attachment it offers
/// two adds — a photo (gallery/camera) and any file (routed to image/audio/file
/// by mime). With one, it renders the right representation (image thumbnail,
/// audio chip, or file chip) over Replace (any file) + Remove.
class _AttachmentSection extends StatelessWidget {
  const _AttachmentSection({
    required this.state,
    required this.imageBytes,
    required this.onPickImage,
    required this.onPickFile,
    required this.onRemove,
  });

  final CardEditState state;

  /// The image attachment's decoded bytes from the shared cache; null for
  /// audio/file attachments and while loading.
  final Uint8List? imageBytes;
  final VoidCallback onPickImage;
  final VoidCallback onPickFile;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (state.attachmentBusy) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AttachmentPreview(state: state, imageBytes: imageBytes),
        const SizedBox(height: 8),
        Row(
          children: [
            // Replace with any file type — the file picker routes by mime, so a
            // card's attachment can switch kind (image → audio, etc.).
            TextButton.icon(
              onPressed: onPickFile,
              icon: const Icon(Icons.swap_horiz),
              label: Text(l10n.cardEditReplace),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onRemove,
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              label: Text(
                l10n.cardEditRemove,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
          sublabel: size == null ? null : _formatBytes(size),
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
