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
    required this.onMove,
  });

  /// Whether some cards are still unselected ("Select all" would do something).
  final bool canSelectAll;
  final VoidCallback onSelectAll;
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
              TextButton.icon(
                icon: const Icon(Icons.select_all),
                label: Text(l10n.collectionSelectAllTooltip),
                onPressed: canSelectAll ? onSelectAll : null,
              ),
              const Spacer(),
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
