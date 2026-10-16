import 'package:flutter/material.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/presentation/collection_state.dart';
import 'package:knit/l10n/app_localizations.dart';

/// The move picker (bottom sheet): every other collection, most recently
/// updated first. Choosing one pops its [MoveTarget] back to the page.
class MoveTargetSheet extends StatelessWidget {
  const MoveTargetSheet({
    super.key,
    required this.status,
    required this.targets,
  });

  final MoveTargetsStatus status;
  final List<MoveTarget> targets;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final Widget body = switch (status) {
      MoveTargetsStatus.idle || MoveTargetsStatus.loading => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      MoveTargetsStatus.failed => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l10n.collectionMoveTargetsError),
      ),
      MoveTargetsStatus.ready when targets.isEmpty => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l10n.collectionMoveNoTargets),
      ),
      MoveTargetsStatus.ready => Flexible(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: targets.length,
          itemBuilder: (context, i) {
            final target = targets[i];
            return ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(
                target.title.isEmpty ? l10n.labelUntitled : target.title,
              ),
              onTap: () => Navigator.of(context).pop(target),
            );
          },
        ),
      ),
    };
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                l10n.collectionMoveSheetTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            body,
          ],
        ),
      ),
    );
  }
}
