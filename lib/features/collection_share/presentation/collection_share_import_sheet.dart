import 'dart:async';

import 'package:flutter/material.dart';
import 'package:knit/features/collection/presentation/collection_page.dart';
import 'package:knit/features/collection_share/presentation/collection_share_import_controller.dart';
import 'package:knit/features/collection_share/presentation/collection_share_import_state.dart';
import 'package:knit/l10n/app_localizations.dart';

/// The import preview (docs/collection_share.md "Import" step 3): "Trip to
/// Kyoto · 24 cards · from mira#9f86 · + 2 linked collections · media not
/// included", then **Import**
/// (or **Update** when the collection is already here). Owns and disposes
/// its [controller]; pops with the imported collection id.
class CollectionShareImportSheet extends StatefulWidget {
  const CollectionShareImportSheet({super.key, required this.controller});

  final CollectionShareImportController controller;

  /// Shows the sheet over a controller that is reading (or has read) a file;
  /// resolves to the imported collection id, or null.
  static Future<String?> show(
    BuildContext context,
    CollectionShareImportController controller,
  ) => showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => CollectionShareImportSheet(controller: controller),
  );

  /// [show], then open the imported collection (its carrier is already
  /// written).
  static Future<void> showAndOpen(
    BuildContext context,
    CollectionShareImportController controller,
  ) async {
    final navigator = Navigator.of(context);
    final collectionId = await show(context, controller);
    if (collectionId == null) return;
    await navigator.push(CollectionPage.route());
  }

  @override
  State<CollectionShareImportSheet> createState() =>
      _CollectionShareImportSheetState();
}

class _CollectionShareImportSheetState
    extends State<CollectionShareImportSheet> {
  CollectionShareImportController get _controller => widget.controller;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final collectionId = await _controller.confirm();
    if (collectionId != null && mounted) {
      Navigator.of(context).pop(collectionId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: ListenableBuilder(
          listenable: _controller.state,
          builder: (context, _) {
            final state = _controller.state;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.shareImportTitle, style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                ...switch (state.status) {
                  ShareImportStatus.reading => [
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 12),
                    Text(l10n.shareImportReading, textAlign: TextAlign.center),
                  ],
                  ShareImportStatus.failed => [
                    Text(_problemText(l10n, state.problem)),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.actionClose),
                      ),
                    ),
                  ],
                  ShareImportStatus.ready ||
                  ShareImportStatus.importing => _preview(context, state),
                },
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _preview(
    BuildContext context,
    CollectionShareImportState state,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final plan = state.plan!;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final busy = state.status == ShareImportStatus.importing;
    return [
      Text(
        plan.title.isEmpty ? l10n.labelUntitled : plan.title,
        style: theme.textTheme.titleMedium,
      ),
      const SizedBox(height: 4),
      Text(
        l10n.shareImportSummary(
          plan.cardCount,
          '${plan.ownerNickname ?? ''}#${plan.ownerFingerprint}',
        ),
        style: muted,
      ),
      if (plan.linkedCollectionCount > 0)
        Text(l10n.shareImportLinked(plan.linkedCollectionCount), style: muted),
      if (!plan.mediaIncluded) Text(l10n.shareImportNoMedia, style: muted),
      const SizedBox(height: 12),
      Text(
        plan.isOwn ? l10n.shareImportOwnHint : l10n.shareImportReadOnlyHint,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.actionCancel),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: busy ? null : () => unawaited(_confirm()),
            child: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    plan.isUpdate
                        ? l10n.shareImportUpdate
                        : l10n.shareImportAction,
                  ),
          ),
        ],
      ),
    ];
  }

  static String _problemText(
    AppLocalizations l10n,
    ShareImportProblem? problem,
  ) => switch (problem) {
    ShareImportProblem.newerVersion => l10n.shareImportNewer,
    ShareImportProblem.refused => l10n.shareImportRefused,
    ShareImportProblem.importFailed => l10n.shareImportFailed,
    ShareImportProblem.unreadable || null => l10n.shareImportUnreadable,
  };
}
