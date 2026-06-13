import 'dart:typed_data';

import 'package:flutter/material.dart';
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
import 'package:knit/features/sync_status/presentation/sync_status_indicator.dart';

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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // --- intents ---------------------------------------------------------------

  void _submitComposer() {
    final text = _composer.text;
    if (text.trim().isEmpty) return;
    _controller.dispatch(ComposerSubmitted(text));
    _composer.clear();
  }

  Future<void> _openAddBlock() async {
    final kind = await showModalBottomSheet<CardKind>(
      context: context,
      builder: (_) => const _AddBlockSheet(),
    );
    if (kind == null || !mounted) return;
    switch (kind) {
      case CardKind.link:
        final url = await _promptText(
          title: 'Add a link',
          hint: 'https://…',
          action: 'Add',
        );
        if (url != null) _controller.dispatch(LinkCardSubmitted(url));
      case CardKind.image:
      case CardKind.audio:
        _comingSoon(kind == CardKind.image ? 'Photo cards' : 'Audio cards');
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
          title: _cardLabel(card),
        );
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

  /// Hand the focused entity to the Connections carrier (cross_feature.md §2),
  /// then navigate (§4.4). The carrier is the payload — navigation stays empty.
  void _openConnections({
    required ConnectedEntityKind kind,
    required String id,
    required String title,
  }) {
    CollectionScope.connectionsRouteArgsWriter
        .open(kind: kind, id: id, title: title);
    Navigator.of(context).push(ConnectionsPage.route());
  }

  /// A short label for a card, used to seed the Connections breadcrumb.
  static String _cardLabel(FeedCard card) {
    final text = card.text?.trim();
    if (text != null && text.isNotEmpty) return text;
    return switch (card.kind) {
      CardKind.image => 'Photo',
      CardKind.audio => 'Audio',
      CardKind.link => 'Link',
      CardKind.text || CardKind.unknown => 'Empty note',
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
      LinkRequested(cardId: card.id, targetKind: picked.kind, targetId: picked.id),
    );
  }

  Future<void> _renameCollection(String current) async {
    final title = await _promptText(
      title: 'Rename collection',
      initial: current,
      action: 'Save',
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

  void _comingSoon(String what) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('$what — coming soon')));

  // --- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
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
                state.title.trim().isEmpty ? 'Untitled' : state.title,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            actions: [
              if (state.status == CollectionStatus.ready && !state.reordering)
                IconButton(
                  tooltip: 'Connections',
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
                        child: const Text('Done'),
                      )
                    : IconButton(
                        tooltip: 'Reorder',
                        icon: const Icon(Icons.swap_vert),
                        onPressed: () =>
                            _controller.dispatch(const StartReorder()),
                      ),
              const SyncStatusIndicator(),
            ],
          ),
          body: Column(
            children: [
              Expanded(child: _body(state)),
              if (!state.reordering) _Composer(
                controller: _composer,
                onSend: _submitComposer,
                onAddBlock: _openAddBlock,
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
          message: state.errorMessage ?? 'Something went wrong',
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
          return _CardBubble(
            card: card,
            imageBytes: _bytesFor(state, card),
            onTap: () => _openCardActions(card),
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

enum _CardAction { edit, delete, link, connections, reorder }

// --- widgets ---------------------------------------------------------------

class _CardBubble extends StatelessWidget {
  const _CardBubble({
    required this.card,
    required this.imageBytes,
    required this.onTap,
  });
  final FeedCard card;

  /// Decoded bytes for an image card; null while loading or missing.
  final Uint8List? imageBytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              child: _content(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(ThemeData theme) {
    switch (card.kind) {
      case CardKind.link:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                card.text?.trim().isNotEmpty == true ? card.text!.trim() : 'Link',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        );
      case CardKind.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AttachmentImage(
            bytes: imageBytes,
            width: 220,
            height: 220,
            placeholder: _placeholder(theme, Icons.image_outlined, 'Photo'),
          ),
        );
      case CardKind.audio:
        return _placeholder(theme, Icons.mic_none, 'Audio');
      case CardKind.text:
      case CardKind.unknown:
        return Text(
          card.text?.trim().isNotEmpty == true ? card.text!.trim() : 'Empty note',
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
    final label = switch (card.kind) {
      CardKind.link => card.text?.trim().isNotEmpty == true ? card.text!.trim() : 'Link',
      CardKind.image => 'Photo',
      CardKind.audio => 'Audio',
      CardKind.text || CardKind.unknown =>
        card.text?.trim().isNotEmpty == true ? card.text!.trim() : 'Empty note',
    };
    return ListTile(
      key: ValueKey('tile-${card.id}'),
      leading: card.kind == CardKind.image
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: AttachmentImage(
                bytes: imageBytes,
                width: 40,
                height: 40,
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
  late final TextEditingController _field =
      TextEditingController(text: widget.initial);

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
          child: const Text('Cancel'),
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
    required this.onSend,
    required this.onAddBlock,
  });
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAddBlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Add block',
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
                  hintText: 'Write a card…',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            IconButton(
              tooltip: 'Send',
              icon: const Icon(Icons.send),
              onPressed: onSend,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddBlockSheet extends StatelessWidget {
  const _AddBlockSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Link'),
            subtitle: const Text('A standalone link card'),
            onTap: () => Navigator.of(context).pop(CardKind.link),
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('Photo'),
            onTap: () => Navigator.of(context).pop(CardKind.image),
          ),
          ListTile(
            leading: const Icon(Icons.mic_none),
            title: const Text('Audio'),
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
    return SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit'),
            onTap: () => Navigator.of(context).pop(_CardAction.edit),
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Make a link'),
            onTap: () => Navigator.of(context).pop(_CardAction.link),
          ),
          ListTile(
            leading: const Icon(Icons.hub_outlined),
            title: const Text('Connections'),
            onTap: () => Navigator.of(context).pop(_CardAction.connections),
          ),
          ListTile(
            leading: const Icon(Icons.swap_vert),
            title: const Text('Reorder'),
            onTap: () => Navigator.of(context).pop(_CardAction.reorder),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text('Delete',
                style: TextStyle(color: theme.colorScheme.error)),
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
    final collections = state.linkCollections;
    if (collections == null) {
      return const _SheetSpinner();
    }
    if (collections.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Nothing to link to yet.'),
      );
    }
    return ListView(
      shrinkWrap: true,
      children: [
        const _SheetHeader('Make a link'),
        for (final c in collections)
          ListTile(
            leading: const Icon(Icons.workspaces_outline),
            title: Text(
              c.label.trim().isEmpty ? 'Untitled' : c.label.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (c.id != widget.currentCollectionId)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(c),
                    child: const Text('Link'),
                  ),
                IconButton(
                  tooltip: 'Open',
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
    final collection = _collectionFor(state, collectionId);
    final label = (collection?.label.trim().isNotEmpty ?? false)
        ? collection!.label.trim()
        : 'Untitled';
    final cached = state.linkCardsByCollection[collectionId];
    final cards = cached
        ?.where((o) => o.id != widget.sourceCardId)
        .toList(growable: false);

    return ListView(
      shrinkWrap: true,
      children: [
        ListTile(
          leading: const Icon(Icons.arrow_back),
          title: const Text('Back to collections'),
          onTap: () => setState(() => _drilledId = null),
        ),
        const Divider(height: 1),
        // The collection itself is a valid target — unless it's the source
        // card's own collection (a card→own-collection link is meaningless).
        if (collection != null && collectionId != widget.currentCollectionId)
          ListTile(
            leading: const Icon(Icons.workspaces_outline),
            title: Text(
              'Link to "$label"',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => Navigator.of(context).pop(collection),
          ),
        if (cards == null)
          const _SheetSpinner()
        else if (cards.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No cards here to link to.'),
          )
        else ...[
          const _SheetHeader('Or a card in it'),
          for (final card in cards)
            ListTile(
              leading: const Icon(Icons.sticky_note_2_outlined),
              title: Text(
                card.label.trim().isEmpty ? 'Empty note' : card.label.trim(),
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
        child: Center(
          heightFactor: 1,
          child: CircularProgressIndicator(),
        ),
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
            Icon(Icons.chat_bubble_outline,
                size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('No cards yet',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Write your first card below, or tap + to add a block.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
            Text(message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
