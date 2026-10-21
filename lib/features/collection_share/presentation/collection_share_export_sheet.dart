import 'dart:async';

import 'package:flutter/material.dart';
import 'package:knit/core/attachments/presentation/byte_size.dart';
import 'package:knit/features/collection_share/presentation/collection_share_export_controller.dart';
import 'package:knit/features/collection_share/presentation/collection_share_export_state.dart';
import 'package:knit/l10n/app_localizations.dart';

/// The Collection ⋮ → "Share as file" sheet (docs/collection_share.md
/// "Export"): the collection, its file size, the **Include media** toggle,
/// then **Send** (the OS share sheet) or **Save to file**. Owns and disposes
/// its [controller]; pops with the [ShareExportOutcome] once the file went
/// out.
class CollectionShareExportSheet extends StatefulWidget {
  const CollectionShareExportSheet({super.key, required this.controller});

  final CollectionShareExportController controller;

  /// Shows the sheet; resolves to how it ended (null when dismissed).
  static Future<ShareExportOutcome?> show(
    BuildContext context,
    CollectionShareExportController controller,
  ) => showModalBottomSheet<ShareExportOutcome>(
    context: context,
    isScrollControlled: true,
    builder: (_) => CollectionShareExportSheet(controller: controller),
  );

  @override
  State<CollectionShareExportSheet> createState() =>
      _CollectionShareExportSheetState();
}

class _CollectionShareExportSheetState
    extends State<CollectionShareExportSheet> {
  CollectionShareExportController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _deliver(ShareExportDestination destination) async {
    final outcome = await _controller.deliver(destination);
    if (!mounted) return;
    if (outcome == ShareExportOutcome.sent ||
        outcome == ShareExportOutcome.saved) {
      Navigator.of(context).pop(outcome);
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
                Text(l10n.shareExportTitle, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                ...switch (state.status) {
                  ShareExportStatus.loading => const [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                  ShareExportStatus.failed => [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(l10n.shareExportLoadFailed),
                    ),
                  ],
                  ShareExportStatus.ready => _ready(context, state),
                },
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _ready(BuildContext context, CollectionShareExportState state) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final estimate = state.estimate!;
    final title = estimate.title.isEmpty ? l10n.labelUntitled : estimate.title;
    return [
      Text(
        l10n.shareExportSummary(title, estimate.cardCount),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 8),
      if (state.hasMedia)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.shareExportIncludeMedia),
          subtitle: Text(
            l10n.shareExportMediaSummary(
              estimate.mediaCount,
              formatByteSize(estimate.mediaBytes),
            ),
          ),
          value: state.includeMedia,
          onChanged: state.busy ? null : _controller.setIncludeMedia,
        ),
      Text(l10n.shareExportSize(formatByteSize(state.size ?? 0))),
      const SizedBox(height: 8),
      Text(
        l10n.shareExportHint,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      if (state.failed) ...[
        const SizedBox(height: 8),
        Text(
          l10n.shareExportFailed,
          style: TextStyle(color: theme.colorScheme.error),
        ),
      ],
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: state.busy
                ? null
                : () => unawaited(_deliver(ShareExportDestination.save)),
            icon: const Icon(Icons.save_alt),
            label: Text(l10n.shareExportSave),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: state.busy
                ? null
                : () => unawaited(_deliver(ShareExportDestination.send)),
            icon: state.busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(l10n.shareExportSend),
          ),
        ],
      ),
    ];
  }
}
