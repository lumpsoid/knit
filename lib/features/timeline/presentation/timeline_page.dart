import 'package:flutter/material.dart';
import 'package:knit/l10n/app_localizations.dart';
import 'package:knit/features/collection/presentation/collection_page.dart';
import 'package:knit/features/collection_widget/presentation/collection_widget_gate.dart';
import 'package:knit/features/new_collection/new_collection.dart';
import 'package:knit/features/profile/presentation/profile_page.dart';
import 'package:knit/features/search/presentation/search_page.dart';
import 'package:knit/features/settings/presentation/settings_page.dart';
import 'package:knit/features/share_capture/presentation/incoming_share_gate.dart';
import 'package:knit/features/sync_status/presentation/sync_status_indicator.dart';
import 'package:knit/features/timeline/presentation/timeline_action.dart';
import 'package:knit/features/timeline/presentation/timeline_archive_page.dart';
import 'package:knit/features/timeline/presentation/timeline_controller.dart';
import 'package:knit/features/timeline/presentation/timeline_scope.dart';
import 'package:knit/features/timeline/presentation/timeline_state.dart';
import 'package:knit/features/timeline/presentation/timeline_ui_effect.dart';
import 'package:knit/features/timeline/presentation/widgets/timeline_archive_row.dart';
import 'package:knit/features/timeline/presentation/widgets/timeline_collection_actions.dart';
import 'package:knit/features/timeline/presentation/widgets/timeline_collection_tile.dart';
import 'package:knit/features/timeline/presentation/widgets/pull_reveal_list.dart';
import 'package:knit/sync/sync.dart';

/// The Home / collections timeline (§4.1) — newest-updated first, not
/// reorderable. Rows show title · last-card preview · count · last-updated.
/// Collections pinned on this device sit in a "Pinned" section above the rest.
/// Archived collections (§3.4) leave the list; pulling it down reveals an
/// Archive row that opens them.
class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const TimelinePage());

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  TimelineController get _controller => TimelineScope.controller;

  /// The FAB the new-collection line grows out of.
  final _fabKey = GlobalKey();

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
          TimelineMessage.archiveFailed => l10n.timelineArchiveFailed,
          TimelineMessage.orderFailed => l10n.timelineOrderFailed,
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  /// Long-press a row → actions sheet (§4.1): Pin / Unpin, Archive (§3.4), and
  /// Delete (guarded by a confirmation dialog since it's destructive).
  Future<void> _openCollectionActions(
    CollectionSummary summary, {
    required bool isPinned,
  }) async {
    final action = await showTimelineCollectionActions(
      context,
      title:
          TimelineScope.collectionDetails.of(summary.collectionId)?.title ??
          summary.title,
      isPinned: isPinned,
      isArchived: false,
      canDelete: _controller.stateHolder.value
          .ownershipOf(summary.collectionId)
          .canEdit,
    );
    if (action == null || !mounted) return;
    _controller.dispatch(action.toAction(summary.collectionId));
  }

  /// Inline collection creation (§4.1): the FAB grows into a title/theme line
  /// → create → open. A title that reads like an existing collection offers
  /// to open that one instead.
  Future<void> _createCollection() async {
    final choice = await showNewCollectionBar(
      context,
      origin: _globalRect(_fabKey),
      existing: [
        for (final summary in _controller.stateHolder.value.collections)
          CollectionTitle(
            collectionId: summary.collectionId,
            title:
                TimelineScope.collectionDetails
                    .of(summary.collectionId)
                    ?.title ??
                summary.title,
          ),
      ],
      existingActionLabel: AppLocalizations.of(
        context,
      ).newCollectionOpenExisting,
    );
    if (!mounted) return;
    switch (choice) {
      case NewCollectionCreate(:final title):
        _controller.dispatch(CreateCollectionRequested(title));
      case NewCollectionUseExisting(:final collectionId):
        _controller.dispatch(CollectionTapped(collectionId));
      case null:
        break;
    }
  }

  static Rect? _globalRect(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
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
            key: _fabKey,
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
      if (sections.homeIsEmpty) const _EmptyView(),
      if (sections.hasPinned) ...[
        _SectionHeader(
          label: l10n.timelinePinnedSection,
          icon: Icons.push_pin_outlined,
        ),
        ..._tiles(sections.pinned, isPinned: true),
        if (sections.others.isNotEmpty)
          _SectionHeader(label: l10n.timelineRecentSection),
      ],
      ..._tiles(sections.others, isPinned: false),
    ];
    // The Archive row (§3.4) hides above the list until a pull reveals it.
    // With everything archived Home has no rows, so it shows outright.
    return PullRevealList(
      header: sections.hasArchived
          ? TimelineArchiveRow(
              count: sections.archived.length,
              onTap: () =>
                  Navigator.of(context).push(TimelineArchivePage.route()),
            )
          : null,
      headerHeight: TimelineArchiveRow.height,
      alwaysShowHeader: sections.homeIsEmpty,
      onRefresh: () async => _controller.dispatch(const RefreshRequested()),
      children: rows,
    );
  }

  Iterable<Widget> _tiles(
    List<CollectionSummary> collections, {
    required bool isPinned,
  }) sync* {
    for (var i = 0; i < collections.length; i++) {
      final summary = collections[i];
      if (i > 0) yield const Divider(height: 1);
      yield TimelineCollectionTile.fromScope(
        key: ValueKey(summary.collectionId),
        summary: summary,
        onTap: () =>
            _controller.dispatch(CollectionTapped(summary.collectionId)),
        onLongPress: () => _openCollectionActions(summary, isPinned: isPinned),
        fromHandle:
            _controller.stateHolder.value.importedOwners[summary.collectionId],
        hubs: _controller.stateHolder.value.hubsOf(summary.collectionId),
      );
    }
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
