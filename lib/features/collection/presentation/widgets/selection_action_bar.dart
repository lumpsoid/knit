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
    required this.onMove,
  });

  /// Whether some cards are still unselected; once all are, the button flips
  /// to "Unselect all".
  final bool canSelectAll;
  final VoidCallback onSelectAll;
  final VoidCallback onUnselectAll;

  /// Whether every selected card is settled (§3.3); the settle button then
  /// unsettles them.
  final bool allSettled;
  final VoidCallback onSettle;
  final VoidCallback onMove;

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
                  ? TextButton.icon(
                      icon: const Icon(Icons.select_all),
                      label: Text(l10n.collectionSelectAllTooltip),
                      onPressed: onSelectAll,
                    )
                  : TextButton.icon(
                      icon: const Icon(Icons.deselect),
                      label: Text(l10n.collectionUnselectAll),
                      onPressed: onUnselectAll,
                    ),
              const Spacer(),
              IconButton(
                tooltip: allSettled
                    ? l10n.collectionActionUnsettle
                    : l10n.collectionActionSettle,
                icon: Icon(allSettled ? Icons.eco : Icons.eco_outlined),
                onPressed: onSettle,
              ),
              const SizedBox(width: 4),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.drive_file_move_outline),
                label: Text(l10n.collectionMoveTooltip),
                onPressed: onMove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
