import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:knit/core/attachments/presentation/attachment_image.dart';
import 'package:knit/l10n/app_localizations.dart';
import 'package:knit/features/collection/presentation/collection_page.dart';
import 'package:knit/features/profile/presentation/profile_page.dart';
import 'package:knit/features/search/presentation/search_page.dart';
import 'package:knit/features/settings/presentation/settings_page.dart';
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
        final l10n = AppLocalizations.of(context);
        final text = switch (message) {
          TimelineMessage.createFailed => l10n.timelineCreateFailed,
          TimelineMessage.deleteFailed => l10n.timelineDeleteFailed,
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(text)));
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
    final l10n = AppLocalizations.of(context);
    final title = summary.title.trim().isEmpty
        ? l10n.labelUntitled
        : summary.title;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.timelineDeleteTitle),
        content: Text(l10n.timelineDeleteBody(title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionDelete),
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.searchOpen,
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(
              context,
            ).push(SearchPage.route(TimelineScope.createSearch())),
          ),
          IconButton(
            tooltip: l10n.profileOpen,
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.of(context).push(ProfilePage.route()),
          ),
          IconButton(
            tooltip: l10n.settingsOpen,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(SettingsPage.route()),
          ),
          const SyncStatusIndicator(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCollection,
        icon: const Icon(Icons.add),
        label: Text(l10n.timelineCollectionFab),
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
                message: l10n.timelineLoadError,
                onRetry: () => _controller.dispatch(const RefreshRequested()),
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
        itemBuilder: (context, i) {
          final summary = state.collections[i];
          final coverId = summary.coverAttachmentId;
          return _CollectionTile(
            summary: summary,
            coverBytes: coverId == null ? null : state.coverBytes[coverId],
            onTap: () =>
                _controller.dispatch(CollectionTapped(summary.collectionId)),
            onLongPress: () => _openCollectionActions(summary),
          );
        },
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
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.timelineNewCollectionTitle),
      content: TextField(
        controller: _field,
        autofocus: true,
        decoration: InputDecoration(hintText: l10n.timelineNewCollectionHint),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_field.text),
          child: Text(l10n.actionCreate),
        ),
      ],
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.summary,
    required this.coverBytes,
    required this.onTap,
    required this.onLongPress,
  });
  final CollectionSummary summary;

  /// Decoded cover bytes, or null when the collection has no cover or its bytes
  /// haven't loaded — in which case the lettered-avatar placeholder is shown.
  final Uint8List? coverBytes;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final title = summary.title.trim().isEmpty
        ? l10n.labelUntitled
        : summary.title;
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: _leading(title),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${_preview(l10n, summary.lastCard)} · '
        '${l10n.timelineCardCount(summary.cardCount)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _relative(l10n, summary.lastUpdated),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// A collection row's leading glyph: its cover image (clipped to the avatar
  /// circle) when its bytes are loaded, otherwise the lettered-avatar
  /// placeholder tinted from the collection id.
  Widget _leading(String title) {
    final bytes = coverBytes;
    if (bytes != null) {
      return ClipOval(
        child: AttachmentImage(
          bytes: bytes,
          width: 40,
          height: 40,
          placeholder: _letterAvatar(title),
        ),
      );
    }
    return _letterAvatar(title);
  }

  Widget _letterAvatar(String title) => CircleAvatar(
    backgroundColor: _tint(summary.collectionId),
    child: Text(
      title.substring(0, 1).toUpperCase(),
      style: const TextStyle(color: Colors.white),
    ),
  );

  Color _tint(String seed) {
    final h = seed.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) & 0xFFFF);
    return HSLColor.fromAHSL(1, (h % 360).toDouble(), 0.5, 0.5).toColor();
  }

  String _preview(AppLocalizations l10n, CardPreview? card) {
    if (card == null) return l10n.timelineNoCardsYet;
    switch (card.kind) {
      case 'text':
        final t = card.text?.trim() ?? '';
        return t.isEmpty ? l10n.labelEmptyNote : t;
      case 'image':
        return l10n.timelinePreviewPhoto;
      case 'audio':
        return l10n.timelinePreviewAudio;
      case 'link':
        return l10n.timelinePreviewLink;
      default:
        return card.kind;
    }
  }

  String _relative(AppLocalizations l10n, int ms) {
    final delta = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(ms),
    );
    if (delta.inMinutes < 1) return l10n.timeNow;
    if (delta.inHours < 1) return l10n.timeMinutesShort(delta.inMinutes);
    if (delta.inDays < 1) return l10n.timeHoursShort(delta.inHours);
    if (delta.inDays < 7) return l10n.timeDaysShort(delta.inDays);
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
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text(
              l10n.actionDelete,
              style: TextStyle(color: theme.colorScheme.error),
            ),
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
            Icon(
              Icons.workspaces_outline,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context).timelineEmptyTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).timelineEmptyBody,
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
