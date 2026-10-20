import 'package:flutter/material.dart';
import 'package:knit/l10n/app_localizations.dart';

/// The bottom bar while cards are selected. It takes the composer's place with
/// the same padding and row height, so entering and leaving selection mode
/// doesn't make the feed jump.
class SelectionActionBar extends StatelessWidget {
  const SelectionActionBar({
    super.key,
    required this.canSelectAll,
    required this.onSelectAll,
    required this.onUnselectAll,
    required this.allSettled,
    required this.onSettle,
    required this.allEmphasized,
    required this.onEmphasize,
    required this.onMove,
    required this.onDelete,
  });

  /// Whether some cards are still unselected; once all are, the icon button
  /// flips to "Unselect all".
  final bool canSelectAll;
  final VoidCallback onSelectAll;
  final VoidCallback onUnselectAll;

  /// Whether every selected card is settled (§3.3); the settle button then
  /// unsettles them.
  final bool allSettled;
  final VoidCallback onSettle;

  /// Whether every selected card is emphasized (§3.3); the emphasize button
  /// then unemphasizes them.
  final bool allEmphasized;
  final VoidCallback onEmphasize;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        // Matches CollectionComposer's padding; its input row is one
        // interactive-dimension tall.
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: SizedBox(
          height: kMinInteractiveDimension,
          child: Row(
            children: [
              canSelectAll
                  ? IconButton(
                      tooltip: l10n.collectionSelectAllTooltip,
                      icon: const Icon(Icons.select_all),
                      onPressed: onSelectAll,
                    )
                  : IconButton(
                      tooltip: l10n.collectionUnselectAll,
                      icon: const Icon(Icons.deselect),
                      onPressed: onUnselectAll,
                    ),
              // The actions hug the right edge. Move carries a short label (the
              // full one is its tooltip) and still ellipsizes on a very narrow
              // screen, so nothing leaves it.
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: l10n.collectionDeleteSelectedTooltip,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onDelete,
                    ),
                    IconButton(
                      tooltip: allSettled
                          ? l10n.collectionActionUnsettle
                          : l10n.collectionActionSettle,
                      icon: Icon(allSettled ? Icons.eco : Icons.eco_outlined),
                      onPressed: onSettle,
                    ),
                    IconButton(
                      tooltip: allEmphasized
                          ? l10n.collectionActionUnemphasize
                          : l10n.collectionActionEmphasize,
                      icon: Icon(
                        allEmphasized
                            ? Icons.auto_awesome
                            : Icons.auto_awesome_outlined,
                      ),
                      onPressed: onEmphasize,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Tooltip(
                        message: l10n.collectionMoveTooltip,
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.drive_file_move_outline),
                          label: Text(
                            l10n.collectionMoveShort,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: onMove,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
