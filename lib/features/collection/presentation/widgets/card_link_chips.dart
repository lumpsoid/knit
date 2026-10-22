import 'package:flutter/material.dart';

/// One link chip under a card bubble (§4.2), already labelled: "→ Trips".
/// [muted] draws it quieter (a broken target, §8.6.1); [archived] also adds a
/// small archive glyph (§3.4). A widget-owned view-model (widgets.md §1).
@immutable
class LinkChipView {
  const LinkChipView({
    required this.label,
    required this.onTap,
    this.muted = false,
    this.archived = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback onTap;
  final bool muted;
  final bool archived;

  /// What assistive tech reads instead of [label], when set.
  final String? semanticLabel;
}

/// The row under a card bubble (§4.2): its link chips, then [trailing] (the
/// backlinks badge). The chips wrap onto more lines and each ellipsizes, so
/// the row never runs wider than the feed. A solid, translucent outline sets
/// each chip apart; no shadow, no blur.
class CardLinkChips extends StatelessWidget {
  const CardLinkChips({super.key, required this.chips, this.trailing});

  final List<LinkChipView> chips;
  final Widget? trailing;

  static const double _maxChipWidth = 220;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Left-inset to sit under the bubble (which starts 12px in), with a
      // touch more so the chips align near the bubble's text.
      padding: const EdgeInsets.only(left: 16, right: 12, top: 2, bottom: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth < _maxChipWidth
              ? constraints.maxWidth
              : _maxChipWidth;
          return Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final chip in chips) _LinkChip(chip, maxWidth: maxWidth),
              ?trailing,
            ],
          );
        },
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip(this.chip, {required this.maxWidth});

  final LinkChipView chip;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final quiet = chip.muted || chip.archived;
    final color = quiet
        ? scheme.onSurfaceVariant.withValues(alpha: 0.7)
        : scheme.primary;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: (quiet ? scheme.outlineVariant : scheme.primary).withValues(
          alpha: 0.4,
        ),
      ),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Material(
        type: MaterialType.transparency,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: chip.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (chip.archived) ...[
                  Icon(Icons.inventory_2_outlined, size: 12, color: color),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    chip.label,
                    semanticsLabel: chip.semanticLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
