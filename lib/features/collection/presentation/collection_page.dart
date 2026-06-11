import 'package:flutter/material.dart';
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
        final text = await _promptText(
          title: 'Edit card',
          initial: card.text ?? '',
          action: 'Save',
        );
        if (text != null) {
          _controller.dispatch(CardEditSubmitted(card.id, text));
        }
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

  Future<void> _openLinkFinder(FeedCard card) async {
    final targets = _controller.stateHolder.value.linkTargets;
    final targetId = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => _LinkFinderSheet(targets: targets),
    );
    if (targetId == null || !mounted) return;
    _controller
        .dispatch(LinkRequested(cardId: card.id, targetCollectionId: targetId));
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
    final field = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: field,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(field.text),
            child: Text(action),
          ),
        ],
      ),
    );
    field.dispose();
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
              if (state.status == CollectionStatus.ready && !state.isEmpty)
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
            onTap: () => _openCardActions(card),
          );
        },
      ),
    );
  }
}

// --- card kinds for the sheets ---------------------------------------------

enum _CardAction { edit, delete, link, connections, reorder }

// --- widgets ---------------------------------------------------------------

class _CardBubble extends StatelessWidget {
  const _CardBubble({required this.card, required this.onTap});
  final FeedCard card;
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
        return _placeholder(theme, Icons.image_outlined, 'Photo');
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
  const _ReorderRow({required this.card, required this.index, super.key});
  final FeedCard card;
  final int index;

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
      leading: const Icon(Icons.drag_handle),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_indicator),
      ),
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
            title: const Text('Link to a collection'),
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

class _LinkFinderSheet extends StatelessWidget {
  const _LinkFinderSheet({required this.targets});
  final List<LinkCandidate> targets;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: targets.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No other collections to link to yet.'),
            )
          : ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Link to which collection?'),
                ),
                for (final t in targets)
                  ListTile(
                    leading: const Icon(Icons.workspaces_outline),
                    title: Text(
                      t.title.trim().isEmpty ? 'Untitled' : t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.of(context).pop(t.collectionId),
                  ),
              ],
            ),
    );
  }
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
