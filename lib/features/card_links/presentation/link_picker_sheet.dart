import 'dart:async';

import 'package:flutter/material.dart';
import 'package:knit/core/recents/presentation/recent_targets_row.dart';
import 'package:knit/features/card_links/domain/card_links_models.dart';
import 'package:knit/features/card_links/presentation/card_links_controller.dart';
import 'package:knit/features/card_links/presentation/card_links_state.dart';
import 'package:knit/features/new_collection/new_collection.dart';
import 'package:knit/l10n/app_localizations.dart';

/// The one link picker (§4.4) the Collection screen and the Card Edit page both
/// open: browse the collections, link to one directly (the "Recent" row offers
/// the ones last linked to), or drill into one to pick a card in it. Renders
/// the shared [CardLinksState]; drilling asks for a collection's cards
/// through [onOpenCollection]. A target the source card already links to shows
/// a ✓, and tapping it again picks its removal. Pops the [LinkPickerChoice]
/// (null when dismissed). With [onNewCollection], the collections level leads
/// with a "New collection" row: tapping it closes the sheet and reports the
/// row's global rect. Search's "Linked to…" chip opens it to pick filter
/// targets ([LinkFilterPick]): its ✓ marks the chosen ones.
class LinkPickerSheet extends StatefulWidget {
  const LinkPickerSheet({
    super.key,
    required this.state,
    required this.onOpenCollection,
    this.onNewCollection,
  });

  final CardLinksState state;
  final ValueChanged<String> onOpenCollection;
  final ValueChanged<Rect?>? onNewCollection;

  /// Open the picker for [source] over [links] and return the choice: a
  /// target to link, a ✓ one to unlink, or — when the [source] offers it — a
  /// new collection: its row grows into the shared title line (§4.1), whose
  /// similar-title offer picks that existing collection instead.
  static Future<LinkPickerChoice?> show(
    BuildContext context, {
    required CardLinksController links,
    required LinkPick source,
  }) async {
    unawaited(links.openPicker(source));
    var wantsNew = false;
    Rect? newFrom;
    final choice = await showModalBottomSheet<LinkPickerChoice>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LinkPickerSheet(
        state: links.state,
        onOpenCollection: (id) => unawaited(links.openCollection(id)),
        onNewCollection: source.offersNewCollection
            ? (origin) {
                wantsNew = true;
                newFrom = origin;
              }
            : null,
      ),
    );
    if (!wantsNew || !context.mounted) return choice;
    return _newCollection(context, links.state, newFrom);
  }

  /// The "New collection" line grown from [origin]: a title to create, or one
  /// of the collections [state] may link to when the title reads like it.
  static Future<LinkPickerChoice?> _newCollection(
    BuildContext context,
    CardLinksState state,
    Rect? origin,
  ) async {
    final offered = [
      for (final c in state.collections ?? const <LinkTarget>[])
        if (state.canLinkToCollection(c.id)) c,
    ];
    final made = await showNewCollectionBar(
      context,
      origin: origin,
      originColor: Theme.of(context).colorScheme.surfaceContainerLow,
      originRadius: 0,
      existing: [
        for (final c in offered)
          CollectionTitle(collectionId: c.id, title: c.label),
      ],
      existingActionLabel: AppLocalizations.of(context).linkPickerLinkThere,
    );
    return switch (made) {
      NewCollectionCreate(:final title) => LinkToNewCollection(title),
      // Picked, never toggled: a ✓ collection stays linked (§6.4).
      NewCollectionUseExisting(:final collectionId) => LinkTargetPicked(
        offered.firstWhere((c) => c.id == collectionId),
      ),
      null => null,
    };
  }

  @override
  State<LinkPickerSheet> createState() => _LinkPickerSheetState();
}

class _LinkPickerSheetState extends State<LinkPickerSheet> {
  /// The collection currently drilled into; null ⇒ the collections list.
  String? _drilledId;

  void _drill(LinkTarget collection) {
    setState(() => _drilledId = collection.id);
    widget.onOpenCollection(collection.id);
  }

  /// Pop what tapping [target] means: link it, or unlink a ✓ one.
  void _choose(LinkTarget target) =>
      Navigator.of(context).pop(widget.state.choose(target));

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: ListenableBuilder(
          listenable: widget.state,
          builder: (context, _) {
            final drilledId = _drilledId;
            if (drilledId == null) return _collectionsList();
            return _cardsList(drilledId);
          },
        ),
      ),
    );
  }

  Widget _collectionsList() {
    final l10n = AppLocalizations.of(context);
    final state = widget.state;
    final collections = state.collections;
    if (collections == null) return const _SheetSpinner();
    final recents = state.recentCollections;
    final onNew = widget.onNewCollection;
    final filtering = state.source is LinkFilterPick;
    final nothingToLink = Padding(
      padding: const EdgeInsets.all(24),
      child: Text(l10n.collectionNothingToLink),
    );
    // With nothing to link to yet, a new collection is still offered.
    if (collections.isEmpty && onNew == null) return nothingToLink;
    return ListView(
      shrinkWrap: true,
      children: [
        _SheetHeader(switch (state.source) {
          LinkFromMine() => l10n.collectionLinkFromMineTitle,
          NewConnection() => l10n.collectionConnectionPickerTitle,
          LinkSelection(:final cardIds) => l10n.collectionLinkSelectedTitle(
            cardIds.length,
          ),
          LinkFilterPick() => l10n.searchLinkedTo,
          _ => l10n.collectionLinkFinderTitle,
        }),
        RecentTargetsRow(
          labels: [for (final c in recents) _collectionLabel(l10n, c)],
          checked: {
            for (var i = 0; i < recents.length; i++)
              if (state.isLinked(recents[i])) i,
          },
          onSelected: (i) => _choose(recents[i]),
        ),
        if (onNew != null)
          Builder(
            builder: (rowContext) => ListTile(
              leading: const Icon(Icons.add),
              title: Text(l10n.linkPickerNewCollection),
              onTap: () {
                final box = rowContext.findRenderObject() as RenderBox?;
                onNew(
                  box == null || !box.hasSize
                      ? null
                      : box.localToGlobal(Offset.zero) & box.size,
                );
                Navigator.of(context).pop();
              },
            ),
          ),
        if (collections.isEmpty) nothingToLink,
        for (final c in collections)
          ListTile(
            leading: const Icon(Icons.workspaces_outline),
            title: Text(
              _collectionLabel(l10n, c),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.isLinked(c))
                  TextButton.icon(
                    onPressed: () => _choose(c),
                    icon: const Icon(Icons.check),
                    label: Text(
                      filtering ? l10n.linkPickerChosen : l10n.linkPickerLinked,
                    ),
                  )
                else if (state.canLinkToCollection(c.id))
                  TextButton(
                    onPressed: () => _choose(c),
                    child: Text(
                      filtering ? l10n.linkPickerChoose : l10n.actionLink,
                    ),
                  ),
                IconButton(
                  tooltip: l10n.actionOpen,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _drill(c),
                ),
              ],
            ),
            onTap: () => _drill(c),
          ),
      ],
    );
  }

  Widget _cardsList(String collectionId) {
    final l10n = AppLocalizations.of(context);
    final state = widget.state;
    final collection = state.collection(collectionId);
    final cards = state.cardsIn(collectionId);
    return ListView(
      shrinkWrap: true,
      children: [
        ListTile(
          leading: const Icon(Icons.arrow_back),
          title: Text(l10n.collectionBackToCollections),
          onTap: () => setState(() => _drilledId = null),
        ),
        const Divider(height: 1),
        if (collection != null && state.canLinkToCollection(collectionId))
          ListTile(
            leading: const Icon(Icons.workspaces_outline),
            title: Text(
              (state.source is LinkFilterPick
                  ? l10n.linkPickerChooseCollection
                  : l10n.collectionLinkToCollection)(
                _collectionLabel(l10n, collection),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: state.isLinked(collection)
                ? Icon(Icons.check, semanticLabel: l10n.linkPickerLinked)
                : null,
            onTap: () => _choose(collection),
          ),
        if (cards == null)
          const _SheetSpinner()
        else if (cards.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.collectionNoCardsToLink),
          )
        else ...[
          _SheetHeader(l10n.collectionOrACardInIt),
          for (final card in cards)
            ListTile(
              leading: const Icon(Icons.sticky_note_2_outlined),
              title: Text(
                card.label.trim().isEmpty
                    ? l10n.labelEmptyNote
                    : card.label.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: state.isLinked(card)
                  ? Icon(Icons.check, semanticLabel: l10n.linkPickerLinked)
                  : null,
              onTap: () => _choose(card),
            ),
        ],
      ],
    );
  }

  static String _collectionLabel(AppLocalizations l10n, LinkTarget c) =>
      c.label.trim().isEmpty ? l10n.labelUntitled : c.label.trim();
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(label, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _SheetSpinner extends StatelessWidget {
  const _SheetSpinner();

  // heightFactor: 1 hugs the indicator's height (still centred horizontally) so
  // the sheet doesn't balloon to the ConstrainedBox max while a level loads —
  // and stays valid inside the drilled-cards ListView (unbounded height).
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Center(heightFactor: 1, child: CircularProgressIndicator()),
  );
}
