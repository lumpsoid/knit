import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:knit/core/attachments/presentation/attachment_image.dart';
import 'package:knit/l10n/app_localizations.dart';
import 'package:knit/features/collection/presentation/collection_page.dart';
import 'package:knit/features/collection_widget/presentation/collection_widget_gate.dart';
import 'package:knit/features/profile/presentation/profile_page.dart';
import 'package:knit/features/search/presentation/search_page.dart';
import 'package:knit/features/settings/presentation/settings_page.dart';
import 'package:knit/features/share_capture/presentation/incoming_share_gate.dart';
import 'package:knit/features/sync_status/presentation/sync_status_indicator.dart';
import 'package:knit/features/timeline/presentation/timeline_action.dart';
import 'package:knit/features/timeline/presentation/timeline_controller.dart';
import 'package:knit/features/timeline/presentation/timeline_scope.dart';
import 'package:knit/features/timeline/presentation/timeline_state.dart';
import 'package:knit/features/timeline/presentation/timeline_ui_effect.dart';
import 'package:knit/sync/sync.dart';

/// The Home / collections timeline (§4.1) — newest-updated first, not
/// reorderable. Rows show title · last-card preview · count · last-updated.
/// Collections pinned on this device sit in a "Pinned" section above the rest.
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
          TimelineMessage.pinFailed => l10n.timelinePinFailed,
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  /// Long-press a row → actions sheet (§4.1): Pin / Unpin, and Delete (guarded
  /// by a confirmation dialog since it's destructive).
  Future<void> _openCollectionActions(
    CollectionSummary summary, {
    required bool isPinned,
  }) async {
    final action = await showModalBottomSheet<_CollectionAction>(
      context: context,
      builder: (_) => _CollectionActionsSheet(isPinned: isPinned),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _CollectionAction.pin:
      case _CollectionAction.unpin:
        _controller.dispatch(
          PinToggled(
            summary.collectionId,
            pinned: action == _CollectionAction.pin,
          ),
        );
      case _CollectionAction.delete:
        await _confirmDelete(summary);
    }
  }

  /// [summary]'s current title — the shared collection details' copy when
  /// known, else the summary's own.
  static String _titleOf(CollectionSummary summary) =>
      TimelineScope.collectionDetails.of(summary.collectionId)?.title ??
      summary.title;

  Future<void> _confirmDelete(CollectionSummary summary) async {
    final l10n = AppLocalizations.of(context);
    final name = _titleOf(summary);
    final title = name.trim().isEmpty ? l10n.labelUntitled : name;
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
    // A home-screen widget tap opens its collection (or the widget picker), and
    // shares from other apps open the capture screen, over whatever is on top.
    return CollectionWidgetGate(
      mode: CollectionWidgetGateMode.handle,
      child: IncomingShareGate(
        mode: IncomingShareGateMode.capture,
        child: Scaffold(
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
                onPressed: () =>
                    Navigator.of(context).push(ProfilePage.route()),
              ),
              IconButton(
                tooltip: l10n.settingsOpen,
                icon: const Icon(Icons.settings_outlined),
                onPressed: () =>
                    Navigator.of(context).push(SettingsPage.route()),
              ),
              const SyncStatusIndicator(),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _createCollection,
            icon: const Icon(Icons.add),
            label: Text(l10n.timelineCollectionFab),
          ),
          body: ListenableBuilder(
            listenable: Listenable.merge([
              _controller.stateHolder,
              TimelineScope.collectionDetails,
              TimelineScope.images,
            ]),
            builder: (context, _) {
              final state = _controller.stateHolder.value;
              switch (state.status) {
                case TimelineStatus.loading:
                  if (state.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return _list(state);
                case TimelineStatus.failed:
                  return _ErrorView(
                    message: l10n.timelineLoadError,
                    onRetry: () =>
                        _controller.dispatch(const RefreshRequested()),
                  );
                case TimelineStatus.ready:
                  if (state.isEmpty) return const _EmptyView();
                  return _list(state);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _list(TimelineState state) {
    final l10n = AppLocalizations.of(context);
    final sections = state.sections;
    // Section headers only appear once something is pinned; with no pins the
    // feed is the plain recency list.
    final rows = <Widget>[
      if (sections.hasPinned) ...[
        _SectionHeader(
          label: l10n.timelinePinnedSection,
          icon: Icons.push_pin_outlined,
        ),
        ..._tiles(state, sections.pinned, isPinned: true),
        if (sections.others.isNotEmpty)
          _SectionHeader(label: l10n.timelineRecentSection),
      ],
      ..._tiles(state, sections.others, isPinned: false),
    ];
    return RefreshIndicator(
      onRefresh: () async => _controller.dispatch(const RefreshRequested()),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: rows,
      ),
    );
  }

  Iterable<Widget> _tiles(
    TimelineState state,
    List<CollectionSummary> collections, {
    required bool isPinned,
  }) sync* {
    for (var i = 0; i < collections.length; i++) {
      final summary = collections[i];
      // The header comes from the shared collection details (kept fresh by
      // every read and edit); the summary is the fallback before it lands.
      final header = TimelineScope.collectionDetails.of(summary.collectionId);
      final coverId = header == null
          ? summary.coverAttachmentId
          : header.coverAttachmentId;
      if (i > 0) yield const Divider(height: 1);
      yield _CollectionTile(
        key: ValueKey(summary.collectionId),
        summary: summary,
        title: header?.title ?? summary.title,
        coverBytes: coverId == null ? null : TimelineScope.images.of(coverId),
        onTap: () =>
            _controller.dispatch(CollectionTapped(summary.collectionId)),
        onLongPress: () => _openCollectionActions(summary, isPinned: isPinned),
      );
    }
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

/// A timeline section label ("Pinned" / "Recent").
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.primary,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: style?.color),
            const SizedBox(width: 6),
          ],
          Text(label, style: style),
        ],
      ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    super.key,
    required this.summary,
    required this.title,
    required this.coverBytes,
    required this.onTap,
    required this.onLongPress,
  });
  final CollectionSummary summary;

  /// The collection's current title (blank ⇒ shown as untitled).
  final String title;

  /// Decoded cover bytes, or null when the collection has no cover or its bytes
  /// haven't loaded — in which case the lettered-avatar placeholder is shown.
  final Uint8List? coverBytes;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final title = this.title.trim().isEmpty ? l10n.labelUntitled : this.title;
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

enum _CollectionAction { pin, unpin, delete }

/// Long-press actions sheet for a collection row (§4.1).
class _CollectionActionsSheet extends StatelessWidget {
  const _CollectionActionsSheet({required this.isPinned});

  /// Whether the row is pinned — offers Unpin instead of Pin.
  final bool isPinned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
            title: Text(isPinned ? l10n.actionUnpin : l10n.actionPin),
            onTap: () => Navigator.of(
              context,
            ).pop(isPinned ? _CollectionAction.unpin : _CollectionAction.pin),
          ),
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
