import 'dart:async';

import 'package:flutter/material.dart';
import 'package:knit/features/card_links/domain/card_links_models.dart';
import 'package:knit/features/card_links/presentation/card_links_controller.dart';
import 'package:knit/features/card_links/presentation/card_links_state.dart';
import 'package:knit/l10n/app_localizations.dart';

/// The one link picker (§4.4) the Collection screen and the Card Edit page both
/// open: browse the collections, link to one directly, or drill into one to
/// pick a card in it. Renders the shared [CardLinksState]; drilling asks for a
/// collection's cards through [onOpenCollection]. Pops the picked
/// [LinkTarget] (null when dismissed).
class LinkPickerSheet extends StatefulWidget {
  const LinkPickerSheet({
    super.key,
    required this.state,
    required this.onOpenCollection,
  });

  final CardLinksState state;
  final ValueChanged<String> onOpenCollection;

  /// Open the picker for [source] over [links] and return the picked target.
  static Future<LinkTarget?> show(
    BuildContext context, {
    required CardLinksController links,
    required LinkSource source,
  }) {
    unawaited(links.openPicker(source));
    return showModalBottomSheet<LinkTarget>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LinkPickerSheet(
        state: links.state,
        onOpenCollection: (id) => unawaited(links.openCollection(id)),
      ),
    );
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
    if (collections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l10n.collectionNothingToLink),
      );
    }
    return ListView(
      shrinkWrap: true,
      children: [
        _SheetHeader(l10n.collectionLinkFinderTitle),
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
                if (state.canLinkToCollection(c.id))
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(c),
                    child: Text(l10n.actionLink),
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
              l10n.collectionLinkToCollection(
                _collectionLabel(l10n, collection),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => Navigator.of(context).pop(collection),
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
              onTap: () => Navigator.of(context).pop(card),
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
