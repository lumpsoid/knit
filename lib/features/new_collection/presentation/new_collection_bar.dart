import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:knit/features/new_collection/domain/similar_collection.dart';
import 'package:knit/l10n/app_localizations.dart';

/// What the user chose in the new-collection bar.
sealed class NewCollectionChoice {
  const NewCollectionChoice();
}

/// Create a collection with this (trimmed, non-empty) [title].
class NewCollectionCreate extends NewCollectionChoice {
  const NewCollectionCreate(this.title);
  final String title;
}

/// Use the existing collection the bar suggested instead.
class NewCollectionUseExisting extends NewCollectionChoice {
  const NewCollectionUseExisting(this.collectionId);
  final String collectionId;
}

/// Inline collection creation (§4.1): the button that was tapped grows into a
/// composer line docked above the keyboard — an icon, the title/theme field
/// and a send arrow — over a dimmed page. Sending creates; back, a tap outside
/// or an empty title shrinks the line back into [origin] and creates nothing.
/// While the title reads like one of [existing], a hint above the line offers
/// that collection instead ([existingActionLabel]).
///
/// [origin] is the tapped button's global rect, painted from [originColor]
/// with [originRadius]; null grows the line from the bottom centre.
Future<NewCollectionChoice?> showNewCollectionBar(
  BuildContext context, {
  required Rect? origin,
  required List<CollectionTitle> existing,
  required String existingActionLabel,
  Color? originColor,
  double originRadius = 16,
}) {
  final scheme = Theme.of(context).colorScheme;
  return Navigator.of(context).push(
    _NewCollectionRoute(
      origin: origin,
      originColor: originColor ?? scheme.primaryContainer,
      originRadius: originRadius,
      existing: existing,
      existingActionLabel: existingActionLabel,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      scrim: scheme.scrim.withValues(alpha: 0.32),
    ),
  );
}

class _NewCollectionRoute extends PopupRoute<NewCollectionChoice> {
  _NewCollectionRoute({
    required this.origin,
    required this.originColor,
    required this.originRadius,
    required this.existing,
    required this.existingActionLabel,
    required this.barrierLabel,
    required Color scrim,
  }) : _scrim = scrim;

  final Rect? origin;
  final Color originColor;
  final double originRadius;
  final List<CollectionTitle> existing;
  final String existingActionLabel;
  final Color _scrim;

  /// Set once the user sends: the line then leaves upward, toward the
  /// collection it became, instead of shrinking back into [origin].
  final ValueNotifier<bool> _sent = ValueNotifier(false);

  @override
  final String barrierLabel;

  @override
  Color get barrierColor => _scrim;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 340);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 260);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _NewCollectionLayer(
      animation: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      sent: _sent,
      origin: origin,
      originColor: originColor,
      originRadius: originRadius,
      existing: existing,
      existingActionLabel: existingActionLabel,
    );
  }

  @override
  void dispose() {
    _sent.dispose();
    super.dispose();
  }
}

/// Positions the line: lerps it between [origin] and its dock above the
/// keyboard as [animation] runs, and keeps the hint just above it.
class _NewCollectionLayer extends StatelessWidget {
  const _NewCollectionLayer({
    required this.animation,
    required this.sent,
    required this.origin,
    required this.originColor,
    required this.originRadius,
    required this.existing,
    required this.existingActionLabel,
  });

  static const double barHeight = 56;
  static const double gutter = 12;
  static const double dockRadius = 28;

  /// How far a sent line rises as it leaves.
  static const double sentRise = 96;

  final Animation<double> animation;
  final ValueNotifier<bool> sent;
  final Rect? origin;
  final Color originColor;
  final double originRadius;
  final List<CollectionTitle> existing;
  final String existingActionLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final bottom =
        math.max(media.viewInsets.bottom, media.viewPadding.bottom) + gutter;
    // The line's own content builds once; the animation only moves its frame.
    final content = _NewCollectionLine(
      sent: sent,
      existing: existing,
      existingActionLabel: existingActionLabel,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final dock = Rect.fromLTRB(
          gutter,
          size.height - bottom - barHeight,
          size.width - gutter,
          size.height - bottom,
        );
        final from =
            origin ??
            Rect.fromCenter(
              center: Offset(size.width / 2, dock.center.dy),
              width: barHeight,
              height: barHeight,
            );
        return AnimatedBuilder(
          animation: Listenable.merge([animation, sent]),
          builder: (context, child) {
            final t = animation.value;
            final leaving =
                sent.value && animation.status == AnimationStatus.reverse;
            final Rect rect;
            final double radius;
            final Color color;
            final double opacity;
            if (leaving) {
              rect = dock.translate(0, -sentRise * (1 - t));
              radius = dockRadius;
              color = scheme.surfaceContainerHigh;
              opacity = t;
            } else {
              rect = Rect.lerp(from, dock, t)!;
              radius = originRadius + (dockRadius - originRadius) * t;
              color = Color.lerp(originColor, scheme.surfaceContainerHigh, t)!;
              // Fade the frame in over the button first, so it reads as the
              // button growing rather than a box dropped on top of it.
              opacity = (t * 4).clamp(0.0, 1.0);
            }
            final contentOpacity = leaving
                ? t
                : const Interval(0.45, 1).transform(t);
            return Stack(
              children: [
                Positioned.fromRect(
                  rect: rect,
                  child: Opacity(
                    opacity: opacity,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: color,
                        // A solid ring, no shadow (no blur in Knit's UI).
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radius),
                          side: BorderSide(
                            color: scheme.outlineVariant.withValues(alpha: t),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: dock.left,
                  right: size.width - dock.right,
                  bottom: size.height - rect.bottom,
                  child: Opacity(opacity: contentOpacity, child: child),
                ),
              ],
            );
          },
          // The frame paints the surface; this only gives the field and
          // buttons the Material ancestor they need.
          child: Material(type: MaterialType.transparency, child: content),
        );
      },
    );
  }
}

/// The line's content: the hint (when the title matches an existing
/// collection) stacked over the icon · field · send row.
class _NewCollectionLine extends StatefulWidget {
  const _NewCollectionLine({
    required this.sent,
    required this.existing,
    required this.existingActionLabel,
  });

  final ValueNotifier<bool> sent;
  final List<CollectionTitle> existing;
  final String existingActionLabel;

  @override
  State<_NewCollectionLine> createState() => _NewCollectionLineState();
}

class _NewCollectionLineState extends State<_NewCollectionLine> {
  // Disposed with the route's widget, not when the push future completes — the
  // exit animation still rebuilds the field.
  final TextEditingController _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _field.text.trim();
    if (title.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    widget.sent.value = true;
    Navigator.of(context).pop(NewCollectionCreate(title));
  }

  void _useExisting(CollectionTitle match) {
    widget.sent.value = true;
    Navigator.of(context).pop(NewCollectionUseExisting(match.collectionId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _field,
      builder: (context, value, _) {
        final hasTitle = value.text.trim().isNotEmpty;
        final match = SimilarCollectionFinder.find(value.text, widget.existing);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.bottomCenter,
              child: match == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ExistingHint(
                        title: match.title,
                        actionLabel: widget.existingActionLabel,
                        onUse: () => _useExisting(match),
                      ),
                    ),
            ),
            SizedBox(
              height: _NewCollectionLayer.barHeight,
              child: Row(
                children: [
                  const SizedBox(width: 18),
                  Icon(
                    Icons.collections_bookmark_outlined,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _field,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      style: theme.textTheme.titleMedium,
                      decoration: InputDecoration(
                        hintText: l10n.newCollectionHint,
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: AnimatedScale(
                      scale: hasTitle ? 1 : 0.86,
                      duration: const Duration(milliseconds: 160),
                      child: IconButton.filled(
                        tooltip: l10n.newCollectionCreateTooltip,
                        icon: const Icon(Icons.arrow_upward),
                        onPressed: hasTitle ? _submit : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// "You already have **Title**" with a button that takes that one instead.
class _ExistingHint extends StatelessWidget {
  const _ExistingHint({
    required this.title,
    required this.actionLabel,
    required this.onUse,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerHighest,
        shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 6, 4),
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: '${l10n.newCollectionExistingLead} ',
                  children: [
                    TextSpan(
                      text: title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(onPressed: onUse, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
