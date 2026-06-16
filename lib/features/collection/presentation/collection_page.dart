import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:knit/l10n/app_localizations.dart';
import 'package:knit/core/attachments/domain/image_picker_port.dart';
import 'package:knit/core/attachments/presentation/attachment_image.dart';
import 'package:knit/features/card_edit/presentation/card_edit_page.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/presentation/collection_action.dart';
import 'package:knit/features/collection/presentation/collection_controller.dart';
import 'package:knit/features/collection/presentation/collection_scope.dart';
import 'package:knit/features/collection/presentation/collection_state.dart';
import 'package:knit/features/collection/presentation/collection_ui_effect.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/features/connections/presentation/connections_page.dart';

/// The Collection screen (§4.2) — a chat-style card feed (oldest at top), a
/// bottom composer, a "+" add-block sheet, per-card actions, and drag-to-reorder
/// as a *mode* of this screen.
class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const CollectionPage());

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  CollectionController get _controller => CollectionScope.controller;
  final TextEditingController _composer = TextEditingController();

  /// Whether the inline gallery/camera options are shown above the composer.
  /// Pure UI state (like [_composer]): the user revealed them via "+" → Photo
  /// and dismisses them by picking a source. Kept local — no business decision.
  bool _showPhotoSources = false;

  @override
  void initState() {
    super.initState();
    _controller
      ..onAttach(_onUiEffect)
      ..dispatch(ViewAttached(CollectionScope.routeArgs.collectionId));
  }

  @override
  void dispose() {
    _controller
      ..dispatch(const DeactivateFeature())
      ..onDetach();
    _composer.dispose();
    super.dispose();
  }

  void _onUiEffect(CollectionUiEffect effect) {
    if (!mounted) return;
    switch (effect) {
      case CollectionShowMessageUiEffect(:final message):
        final text = switch (message) {
          CollectionMessage.saveFailed => AppLocalizations.of(
            context,
          ).collectionSaveFailed,
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  // --- intents ---------------------------------------------------------------

  void _submitComposer() {
    final text = _composer.text;
    // A staged image makes an empty caption a valid send (photo, no caption).
    final hasPendingImage = _controller.stateHolder.value.pendingImage != null;
    if (text.trim().isEmpty && !hasPendingImage) return;
    _controller.dispatch(ComposerSubmitted(text));
    _composer.clear();
    if (_showPhotoSources) setState(() => _showPhotoSources = false);
  }

  /// A source was chosen from the inline options: hide them and open the picker.
  void _pickImage(ImagePickerSource source) {
    setState(() => _showPhotoSources = false);
    _controller.dispatch(PickImageRequested(source));
  }

  /// Leave the photo-source mode without picking (the "✕" the "+" turns into).
  void _cancelPhotoSources() => setState(() => _showPhotoSources = false);

  Future<void> _openAddBlock() async {
    final kind = await showModalBottomSheet<CardKind>(
      context: context,
      builder: (_) => const _AddBlockSheet(),
    );
    if (kind == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    switch (kind) {
      case CardKind.link:
        final url = await _promptText(
          title: l10n.collectionAddLinkTitle,
          hint: l10n.collectionAddLinkHint,
          action: l10n.actionAdd,
        );
        if (url != null) _controller.dispatch(LinkCardSubmitted(url));
      case CardKind.image:
        // Reveal the inline gallery/camera options above the composer; choosing
        // one opens the picker. The photo only becomes a card when the user
        // sends, so they can add a caption, clear it, or repick first.
        setState(() => _showPhotoSources = true);
      case CardKind.audio:
        _comingSoon(l10n.collectionAudioCards);
      case CardKind.text:
      case CardKind.unknown:
        break;
    }
  }

  Future<void> _openCardActions(FeedCard card) async {
    final action = await showModalBottomSheet<_CardAction>(
      context: context,
      builder: (_) => const _CardActionsSheet(),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _CardAction.edit:
        await _openCardEdit(card);
      case _CardAction.delete:
        _controller.dispatch(CardDeleteRequested(card.id));
      case _CardAction.link:
        await _openLinkFinder(card);
      case _CardAction.connections:
        _openConnections(
          kind: ConnectedEntityKind.card,
          id: card.id,
          title: _cardLabel(AppLocalizations.of(context), card),
        );
      case _CardAction.share:
        _controller.dispatch(CardShareRequested(card.id));
      case _CardAction.reorder:
        _controller.dispatch(const StartReorder());
    }
  }

  /// Hand the card to the Card Edit carrier (cross_feature.md §2), then navigate
  /// to the dedicated edit page (§4.3). On return, resync from the projection so
  /// the saved change shows in the feed (projection-is-truth — no push needed).
  Future<void> _openCardEdit(FeedCard card) async {
    CollectionScope.cardEditRouteArgsWriter.open(
      cardId: card.id,
      initialText: card.text ?? '',
      initialAttachmentId: card.attachmentId,
    );
    await Navigator.of(context).push(CardEditPage.route());
    if (mounted) _controller.dispatch(const ReloadRequested());
  }

  /// Open a card's image full-screen for pinch-to-zoom viewing (§4.2). The feed
  /// thumbnail and the full image share a [Hero], so the open/close animates.
  void _openImagePreview(FeedCard card, Uint8List bytes) {
    Navigator.of(context).push(
      _ImagePreviewPage.route(
        bytes: bytes,
        heroTag: _imageHeroTag(card.id),
        caption: card.text,
      ),
    );
  }

  /// Hand the focused entity to the Connections carrier (cross_feature.md §2),
  /// then navigate (§4.4). The carrier is the payload — navigation stays empty.
  void _openConnections({
    required ConnectedEntityKind kind,
    required String id,
    required String title,
  }) {
    CollectionScope.connectionsRouteArgsWriter.open(
      kind: kind,
      id: id,
      title: title,
    );
    Navigator.of(context).push(ConnectionsPage.route());
  }

  /// A short label for a card, used to seed the Connections breadcrumb.
  static String _cardLabel(AppLocalizations l10n, FeedCard card) {
    final text = card.text?.trim();
    if (text != null && text.isNotEmpty) return text;
    return switch (card.kind) {
      CardKind.image => l10n.collectionCardPhoto,
      CardKind.audio => l10n.collectionCardAudio,
      CardKind.link => l10n.collectionCardLink,
      CardKind.text || CardKind.unknown => l10n.labelEmptyNote,
    };
  }

  /// Open the link finder for [card]: load the first level (collections), then
  /// let the user link directly to a collection or drill in to pick any card
  /// (§4.4). The sheet observes controller state so each level loads lazily.
  Future<void> _openLinkFinder(FeedCard card) async {
    _controller.dispatch(const LinkFinderOpened());
    final picked = await showModalBottomSheet<LinkOption>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LinkFinderSheet(
        controller: _controller,
        sourceCardId: card.id,
        currentCollectionId: _controller.stateHolder.value.collectionId,
      ),
    );
    if (picked == null || !mounted) return;
    _controller.dispatch(
      LinkRequested(
        cardId: card.id,
        targetKind: picked.kind,
        targetId: picked.id,
      ),
    );
  }

  Future<void> _renameCollection(String current) async {
    final l10n = AppLocalizations.of(context);
    final title = await _promptText(
      title: l10n.collectionRenameTitle,
      initial: current,
      action: l10n.actionSave,
    );
    if (title != null) _controller.dispatch(TitleSubmitted(title));
  }

  /// A simple single-field text prompt; returns null on cancel/empty.
  Future<String?> _promptText({
    required String title,
    required String action,
    String initial = '',
    String? hint,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _PromptDialog(
        title: title,
        action: action,
        initial: initial,
        hint: hint,
      ),
    );
    final trimmed = result?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  void _comingSoon(String what) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(AppLocalizations.of(context).collectionComingSoon(what)),
    ),
  );

  // --- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<CollectionState>(
      valueListenable: _controller.stateHolder,
      builder: (context, state, _) {
        return Scaffold(
          appBar: AppBar(
            title: GestureDetector(
              onLongPress: state.status == CollectionStatus.ready
                  ? () => _renameCollection(state.title)
                  : null,
              child: Text(
                state.title.trim().isEmpty ? l10n.labelUntitled : state.title,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            actions: [
              if (state.status == CollectionStatus.ready && !state.reordering)
                IconButton(
                  tooltip: l10n.collectionConnectionsTooltip,
                  icon: const Icon(Icons.hub_outlined),
                  onPressed: () => _openConnections(
                    kind: ConnectedEntityKind.collection,
                    id: state.collectionId,
                    title: state.title,
                  ),
                ),
              if (state.status == CollectionStatus.ready && state.canReorder)
                state.reordering
                    ? TextButton(
                        onPressed: () =>
                            _controller.dispatch(const EndReorder()),
                        child: Text(l10n.actionDone),
                      )
                    : IconButton(
                        tooltip: l10n.collectionReorderTooltip,
                        icon: const Icon(Icons.swap_vert),
                        onPressed: () =>
                            _controller.dispatch(const StartReorder()),
                      ),
            ],
          ),
          body: Column(
            children: [
              Expanded(child: _body(state)),
              if (!state.reordering)
                _Composer(
                  controller: _composer,
                  pendingImageBytes: state.pendingImage?.bytes,
                  showPhotoSources: _showPhotoSources,
                  onSend: _submitComposer,
                  onAddBlock: _openAddBlock,
                  onCancelPhotoSources: _cancelPhotoSources,
                  onPickFromGallery: () => _pickImage(ImagePickerSource.gallery),
                  onPickFromCamera: () => _pickImage(ImagePickerSource.camera),
                  onClearImage: () =>
                      _controller.dispatch(const PendingImageCleared()),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _body(CollectionState state) {
    switch (state.status) {
      case CollectionStatus.loading:
        if (state.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return _feed(state);
      case CollectionStatus.failed:
        return _ErrorView(
          message: AppLocalizations.of(context).collectionLoadError,
          onRetry: () => _controller.dispatch(const ReloadRequested()),
        );
      case CollectionStatus.ready:
        if (state.isEmpty) return const _EmptyView();
        return _feed(state);
    }
  }

  Widget _feed(CollectionState state) {
    if (state.reordering) {
      return ReorderableListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.cards.length,
        onReorder: (oldIndex, newIndex) =>
            _controller.dispatch(CardMoved(oldIndex, newIndex)),
        itemBuilder: (context, i) {
          final card = state.cards[i];
          return _ReorderRow(
            key: ValueKey(card.id),
            card: card,
            index: i,
            imageBytes: _bytesFor(state, card),
          );
        },
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _controller.dispatch(const ReloadRequested()),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.cards.length,
        itemBuilder: (context, i) {
          final card = state.cards[i];
          final bytes = _bytesFor(state, card);
          return _CardBubble(
            card: card,
            imageBytes: bytes,
            onTap: () => _openCardActions(card),
            onImageTap: bytes == null
                ? null
                : () => _openImagePreview(card, bytes),
          );
        },
      ),
    );
  }

  /// The cached decoded bytes for a card's image, if any (null ⇒ placeholder).
  static Uint8List? _bytesFor(CollectionState state, FeedCard card) {
    final id = card.attachmentId;
    return id == null ? null : state.imageBytes[id];
  }
}

// --- card kinds for the sheets ---------------------------------------------

enum _CardAction { edit, delete, link, connections, share, reorder }

// --- widgets ---------------------------------------------------------------

/// The shared [Hero] tag tying a card's feed thumbnail to its full-screen
/// preview, so the open/close transition flies between the two.
Object _imageHeroTag(String cardId) => 'card-image-$cardId';

class _CardBubble extends StatelessWidget {
  const _CardBubble({
    required this.card,
    required this.imageBytes,
    required this.onTap,
    this.onImageTap,
  });
  final FeedCard card;

  /// Decoded bytes for an image card; null while loading or missing.
  final Uint8List? imageBytes;
  final VoidCallback onTap;

  /// Opens the full-screen image preview; null when the image hasn't loaded yet
  /// (a tap then falls through to [onTap], the card-actions sheet).
  final VoidCallback? onImageTap;

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
    switch (card.kind) {
      case CardKind.link:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                card.text?.trim().isNotEmpty == true
                    ? card.text!.trim()
                    : l10n.collectionCardLink,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        );
      case CardKind.image:
        final caption = card.text?.trim();
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
            child: Hero(tag: _imageHeroTag(card.id), child: image),
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
        return _placeholder(theme, Icons.mic_none, l10n.collectionCardAudio);
      case CardKind.text:
      case CardKind.unknown:
        return Text(
          card.text?.trim().isNotEmpty == true
              ? card.text!.trim()
              : l10n.labelEmptyNote,
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

/// A full-screen, pinch-to-zoom viewer for a card's image (§4.2). Pushed when an
/// image bubble is tapped; takes primitives only (widgets.md §1) — the decoded
/// [bytes], a [heroTag] shared with the feed thumbnail, and an optional caption.
/// Tapping the backdrop or the close button dismisses it.
class _ImagePreviewPage extends StatelessWidget {
  const _ImagePreviewPage({
    required this.bytes,
    required this.heroTag,
    this.caption,
  });

  final Uint8List bytes;
  final Object heroTag;
  final String? caption;

  static Route<void> route({
    required Uint8List bytes,
    required Object heroTag,
    String? caption,
  }) => MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) =>
        _ImagePreviewPage(bytes: bytes, heroTag: heroTag, caption: caption),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final caption = this.caption?.trim();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: l10n.actionClose,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Hero(
                    tag: heroTag,
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
          if (caption != null && caption.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                width: double.infinity,
                color: Colors.black.withValues(alpha: 0.5),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: SafeArea(
                  top: false,
                  child: Text(
                    caption,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReorderRow extends StatelessWidget {
  const _ReorderRow({
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
      CardKind.audio => l10n.collectionCardAudio,
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

/// A single-field text prompt that owns its [TextEditingController], so the
/// controller is disposed when the dialog route is actually removed — disposing
/// it the moment `showDialog` returns races the route's exit animation, which
/// still rebuilds the `TextField` (TextEditingController used after dispose).
class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.action,
    required this.initial,
    required this.hint,
  });

  final String title;
  final String action;
  final String initial;
  final String? hint;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _field = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _field,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_field.text),
          child: Text(widget.action),
        ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.pendingImageBytes,
    required this.showPhotoSources,
    required this.onSend,
    required this.onAddBlock,
    required this.onCancelPhotoSources,
    required this.onPickFromGallery,
    required this.onPickFromCamera,
    required this.onClearImage,
  });
  final TextEditingController controller;

  /// Bytes of an image the user picked but hasn't sent yet; null ⇒ no preview.
  final Uint8List? pendingImageBytes;

  /// Whether the gallery/camera options row is shown above the input row.
  final bool showPhotoSources;
  final VoidCallback onSend;
  final VoidCallback onAddBlock;

  /// Leave photo-source mode without picking (the "+" becomes a "✕" in mode).
  final VoidCallback onCancelPhotoSources;
  final VoidCallback onPickFromGallery;
  final VoidCallback onPickFromCamera;
  final VoidCallback onClearImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final bytes = pendingImageBytes;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bytes != null)
              _PendingImagePreview(bytes: bytes, onClear: onClearImage),
            if (showPhotoSources)
              _PhotoSourceOptions(
                onGallery: onPickFromGallery,
                onCamera: onPickFromCamera,
              ),
            Row(
              children: [
                // In photo-source mode the "+" becomes a "✕" so the user can
                // back out of the mode without picking a source.
                showPhotoSources
                    ? IconButton(
                        tooltip: l10n.actionCancel,
                        icon: const Icon(Icons.close),
                        onPressed: onCancelPhotoSources,
                      )
                    : IconButton(
                        tooltip: l10n.collectionAddBlockTooltip,
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: onAddBlock,
                      ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: l10n.collectionComposerHint,
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                IconButton(
                  tooltip: l10n.collectionSendTooltip,
                  icon: const Icon(Icons.send),
                  onPressed: onSend,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The inline photo-source options shown above the composer when the user
/// chose Photo from "+": gallery on the left, camera on the right (§4.2). Takes
/// primitives only (widgets.md §1) — two callbacks, one per source.
class _PhotoSourceOptions extends StatelessWidget {
  const _PhotoSourceOptions({required this.onGallery, required this.onCamera});
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
class _PendingImagePreview extends StatelessWidget {
  const _PendingImagePreview({required this.bytes, required this.onClear});
  final Uint8List bytes;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Stack(
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
                  message: AppLocalizations.of(context).actionRemove,
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
    );
  }
}

class _AddBlockSheet extends StatelessWidget {
  const _AddBlockSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.link),
            title: Text(l10n.collectionBlockLink),
            subtitle: Text(l10n.collectionBlockLinkSubtitle),
            onTap: () => Navigator.of(context).pop(CardKind.link),
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: Text(l10n.collectionBlockPhoto),
            onTap: () => Navigator.of(context).pop(CardKind.image),
          ),
          ListTile(
            leading: const Icon(Icons.mic_none),
            title: Text(l10n.collectionBlockAudio),
            onTap: () => Navigator.of(context).pop(CardKind.audio),
          ),
        ],
      ),
    );
  }
}

class _CardActionsSheet extends StatelessWidget {
  const _CardActionsSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(l10n.collectionActionEdit),
            onTap: () => Navigator.of(context).pop(_CardAction.edit),
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: Text(l10n.collectionActionMakeLink),
            onTap: () => Navigator.of(context).pop(_CardAction.link),
          ),
          ListTile(
            leading: const Icon(Icons.hub_outlined),
            title: Text(l10n.collectionActionConnections),
            onTap: () => Navigator.of(context).pop(_CardAction.connections),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: Text(l10n.collectionActionShare),
            onTap: () => Navigator.of(context).pop(_CardAction.share),
          ),
          ListTile(
            leading: const Icon(Icons.swap_vert),
            title: Text(l10n.collectionActionReorder),
            onTap: () => Navigator.of(context).pop(_CardAction.reorder),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text(
              l10n.collectionActionDelete,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () => Navigator.of(context).pop(_CardAction.delete),
          ),
        ],
      ),
    );
  }
}

/// Two-level link finder (§4.4): browse collections, link to one directly, or
/// drill into it to link to any card. Levels load lazily, so the sheet observes
/// the controller's state (collections + a per-collection card cache) and
/// dispatches drill loads; selecting a target pops the chosen [LinkOption] back
/// to the page, which dispatches the link write.
class _LinkFinderSheet extends StatefulWidget {
  const _LinkFinderSheet({
    required this.controller,
    required this.sourceCardId,
    required this.currentCollectionId,
  });

  final CollectionController controller;

  /// The card being linked — dropped from the drilled card list (no self-link).
  final String sourceCardId;

  /// The source card's own collection — its direct "link to collection" action
  /// is hidden (a card→its-own-collection link is meaningless), but it can still
  /// be drilled into to link to a sibling card.
  final String currentCollectionId;

  @override
  State<_LinkFinderSheet> createState() => _LinkFinderSheetState();
}

class _LinkFinderSheetState extends State<_LinkFinderSheet> {
  /// The collection currently drilled into; null ⇒ the collections list.
  String? _drilledId;

  void _drill(LinkOption collection) {
    setState(() => _drilledId = collection.id);
    widget.controller.dispatch(LinkCollectionOpened(collection.id));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: ValueListenableBuilder<CollectionState>(
          valueListenable: widget.controller.stateHolder,
          builder: (context, state, _) {
            final drilledId = _drilledId;
            if (drilledId == null) return _collectionsList(state);
            return _cardsList(state, drilledId);
          },
        ),
      ),
    );
  }

  Widget _collectionsList(CollectionState state) {
    final l10n = AppLocalizations.of(context);
    final collections = state.linkCollections;
    if (collections == null) {
      return const _SheetSpinner();
    }
    if (collections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l10n.collectionNothingToLink),
      );
    }
    return ListView(
      shrinkWrap: true,
      children: [
        _SheetHeader(l10n.collectionLinkFinderTitle),
        for (final c in collections)
          ListTile(
            leading: const Icon(Icons.workspaces_outline),
            title: Text(
              c.label.trim().isEmpty ? l10n.labelUntitled : c.label.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (c.id != widget.currentCollectionId)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(c),
                    child: Text(l10n.actionLink),
                  ),
                IconButton(
                  tooltip: l10n.actionOpen,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _drill(c),
                ),
              ],
            ),
            onTap: () => _drill(c),
          ),
      ],
    );
  }

  Widget _cardsList(CollectionState state, String collectionId) {
    final l10n = AppLocalizations.of(context);
    final collection = _collectionFor(state, collectionId);
    final label = (collection?.label.trim().isNotEmpty ?? false)
        ? collection!.label.trim()
        : l10n.labelUntitled;
    final cached = state.linkCardsByCollection[collectionId];
    final cards = cached
        ?.where((o) => o.id != widget.sourceCardId)
        .toList(growable: false);

    return ListView(
      shrinkWrap: true,
      children: [
        ListTile(
          leading: const Icon(Icons.arrow_back),
          title: Text(l10n.collectionBackToCollections),
          onTap: () => setState(() => _drilledId = null),
        ),
        const Divider(height: 1),
        // The collection itself is a valid target — unless it's the source
        // card's own collection (a card→own-collection link is meaningless).
        if (collection != null && collectionId != widget.currentCollectionId)
          ListTile(
            leading: const Icon(Icons.workspaces_outline),
            title: Text(
              l10n.collectionLinkToCollection(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => Navigator.of(context).pop(collection),
          ),
        if (cards == null)
          const _SheetSpinner()
        else if (cards.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.collectionNoCardsToLink),
          )
        else ...[
          _SheetHeader(l10n.collectionOrACardInIt),
          for (final card in cards)
            ListTile(
              leading: const Icon(Icons.sticky_note_2_outlined),
              title: Text(
                card.label.trim().isEmpty
                    ? l10n.labelEmptyNote
                    : card.label.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.of(context).pop(card),
            ),
        ],
      ],
    );
  }

  static LinkOption? _collectionFor(CollectionState state, String id) {
    for (final c in state.linkCollections ?? const <LinkOption>[]) {
      if (c.id == id) return c;
    }
    return null;
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(label, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _SheetSpinner extends StatelessWidget {
  const _SheetSpinner();

  // heightFactor: 1 hugs the indicator's height (still centred horizontally) so
  // the sheet doesn't balloon to the ConstrainedBox max while a level loads —
  // and stays valid inside the drilled-cards ListView (unbounded height).
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Center(heightFactor: 1, child: CircularProgressIndicator()),
  );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).collectionEmptyTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).collectionEmptyBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).actionRetry),
            ),
          ],
        ),
      ),
    );
  }
}
