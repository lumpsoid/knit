import 'package:flutter/material.dart';
import 'package:knit/features/collection/presentation/collection_page.dart';
import 'package:knit/features/sync_status/presentation/sync_status_indicator.dart';
import 'package:knit/features/timeline/presentation/timeline_action.dart';
import 'package:knit/features/timeline/presentation/timeline_controller.dart';
import 'package:knit/features/timeline/presentation/timeline_scope.dart';
import 'package:knit/features/timeline/presentation/timeline_state.dart';
import 'package:knit/features/timeline/presentation/timeline_ui_effect.dart';
import 'package:knit/sync/sync.dart';

/// The Home / collections timeline (§4.1) — newest-updated first, not
/// reorderable. Rows show title · last-card preview · count · last-updated.
class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const TimelinePage());

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  TimelineController get _controller => TimelineScope.controller;

  @override
  void initState() {
    super.initState();
    _controller
      ..onAttach(_onUiEffect)
      ..dispatch(const ViewAttached());
  }

  @override
  void dispose() {
    _controller
      ..dispatch(const DeactivateFeature())
      ..onDetach();
    super.dispose();
  }

  void _onUiEffect(TimelineUiEffect effect) {
    if (!mounted) return;
    switch (effect) {
      case TimelineOpenCollectionUiEffect(:final collectionId):
        // Carrier is the payload (cross_feature.md §2): write, then navigate.
        TimelineScope.routeArgsWriter.open(collectionId);
        Navigator.of(context).push(CollectionPage.route());
      case TimelineShowMessageUiEffect(:final message):
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Long-press a row → actions sheet (§4.1). Today the only action is Delete,
  /// guarded by a confirmation dialog since it's destructive.
  Future<void> _openCollectionActions(CollectionSummary summary) async {
    final action = await showModalBottomSheet<_CollectionAction>(
      context: context,
      builder: (_) => const _CollectionActionsSheet(),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _CollectionAction.delete:
        await _confirmDelete(summary);
    }
  }

  Future<void> _confirmDelete(CollectionSummary summary) async {
    final title = summary.title.trim().isEmpty ? 'Untitled' : summary.title;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete collection?'),
        content: Text('"$title" and its cards will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _controller.dispatch(DeleteCollectionRequested(summary.collectionId));
  }

  /// Inline collection creation (§4.1): a title/theme line → create → open.
  Future<void> _createCollection() async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => const _NewCollectionDialog(),
    );
    if (title == null || title.trim().isEmpty || !mounted) return;
    _controller.dispatch(CreateCollectionRequested(title));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Knit'),
        actions: const [SyncStatusIndicator()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCollection,
        icon: const Icon(Icons.add),
        label: const Text('Collection'),
      ),
      body: ValueListenableBuilder<TimelineState>(
        valueListenable: _controller.stateHolder,
        builder: (context, state, _) {
          switch (state.status) {
            case TimelineStatus.loading:
              if (state.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              return _list(state);
            case TimelineStatus.failed:
              return _ErrorView(
                message: state.errorMessage ?? 'Something went wrong',
                onRetry: () =>
                    _controller.dispatch(const RefreshRequested()),
              );
            case TimelineStatus.ready:
              if (state.isEmpty) return const _EmptyView();
              return _list(state);
          }
        },
      ),
    );
  }

  Widget _list(TimelineState state) {
    return RefreshIndicator(
      onRefresh: () async => _controller.dispatch(const RefreshRequested()),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.collections.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) => _CollectionTile(
          summary: state.collections[i],
          onTap: () => _controller
              .dispatch(CollectionTapped(state.collections[i].collectionId)),
          onLongPress: () => _openCollectionActions(state.collections[i]),
        ),
      ),
    );
  }
}

/// The inline "new collection" prompt. Owns its [TextEditingController] so it's
/// disposed when the dialog route is actually removed — disposing it the moment
/// `showDialog` returns races the route's exit animation, which still rebuilds
/// the `TextField` (TextEditingController used after being disposed).
class _NewCollectionDialog extends StatefulWidget {
  const _NewCollectionDialog();

  @override
  State<_NewCollectionDialog> createState() => _NewCollectionDialogState();
}

class _NewCollectionDialogState extends State<_NewCollectionDialog> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New collection'),
      content: TextField(
        controller: _field,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Title or theme'),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_field.text),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.summary,
    required this.onTap,
    required this.onLongPress,
  });
  final CollectionSummary summary;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = summary.title.trim().isEmpty ? 'Untitled' : summary.title;
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: CircleAvatar(
        backgroundColor: _tint(summary.collectionId),
        child: Text(
          title.substring(0, 1).toUpperCase(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${_preview(summary.lastCard)} · ${summary.cardCount} '
        '${summary.cardCount == 1 ? 'card' : 'cards'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _relative(summary.lastUpdated),
        style: theme.textTheme.labelSmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }

  Color _tint(String seed) {
    final h = seed.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) & 0xFFFF);
    return HSLColor.fromAHSL(1, (h % 360).toDouble(), 0.5, 0.5).toColor();
  }

  String _preview(CardPreview? card) {
    if (card == null) return 'No cards yet';
    switch (card.kind) {
      case 'text':
        final t = card.text?.trim() ?? '';
        return t.isEmpty ? 'Empty note' : t;
      case 'image':
        return '📷 Photo';
      case 'audio':
        return '🎙 Audio';
      case 'link':
        return '🔗 Link';
      default:
        return card.kind;
    }
  }

  String _relative(int ms) {
    final delta = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (delta.inMinutes < 1) return 'now';
    if (delta.inHours < 1) return '${delta.inMinutes}m';
    if (delta.inDays < 1) return '${delta.inHours}h';
    if (delta.inDays < 7) return '${delta.inDays}d';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}';
  }
}

enum _CollectionAction { delete }

/// Long-press actions sheet for a collection row (§4.1).
class _CollectionActionsSheet extends StatelessWidget {
  const _CollectionActionsSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text('Delete',
                style: TextStyle(color: theme.colorScheme.error)),
            onTap: () => Navigator.of(context).pop(_CollectionAction.delete),
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
            Icon(Icons.workspaces_outline,
                size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 20),
            Text('No collections yet',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Collections are chat-style notebooks of cards.\n'
              'Create one to start weaving things together.',
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
            Icon(Icons.error_outline,
                size: 48, color: theme.colorScheme.error),
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
