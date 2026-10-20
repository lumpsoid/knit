import 'package:flutter/material.dart';
import 'package:knit/features/timeline/presentation/timeline_action.dart';
import 'package:knit/features/timeline/presentation/timeline_controller.dart';
import 'package:knit/features/timeline/presentation/timeline_scope.dart';
import 'package:knit/features/timeline/presentation/widgets/timeline_collection_actions.dart';
import 'package:knit/features/timeline/presentation/widgets/timeline_collection_tile.dart';
import 'package:knit/l10n/app_localizations.dart';
import 'package:knit/sync/sync.dart';

/// The Archive (§3.4): the archived collections, in the same recency order as
/// Home. A view over the Timeline's own state — opening, unarchiving and
/// deleting go through the Timeline controller, whose page (still beneath this
/// one) handles the navigation and messages.
class TimelineArchivePage extends StatelessWidget {
  const TimelineArchivePage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const TimelineArchivePage());

  TimelineController get _controller => TimelineScope.controller;

  Future<void> _openActions(
    BuildContext context,
    CollectionSummary summary,
  ) async {
    final action = await showTimelineCollectionActions(
      context,
      title:
          TimelineScope.collectionDetails.of(summary.collectionId)?.title ??
          summary.title,
      isPinned: false,
      isArchived: true,
    );
    if (action == null) return;
    _controller.dispatch(action.toAction(summary.collectionId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.archiveTitle)),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          _controller.stateHolder,
          TimelineScope.collectionDetails,
          TimelineScope.images,
        ]),
        builder: (context, _) {
          final archived = _controller.stateHolder.value.sections.archived;
          if (archived.isEmpty) return const _EmptyArchive();
          return ListView.separated(
            itemCount: archived.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final summary = archived[i];
              return TimelineCollectionTile.fromScope(
                key: ValueKey(summary.collectionId),
                summary: summary,
                onTap: () => _controller.dispatch(
                  CollectionTapped(summary.collectionId),
                ),
                onLongPress: () => _openActions(context, summary),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyArchive extends StatelessWidget {
  const _EmptyArchive();

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
              Icons.archive_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).archiveEmpty,
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
