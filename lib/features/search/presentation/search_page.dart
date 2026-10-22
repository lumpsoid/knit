import 'dart:async';

import 'package:flutter/material.dart' hide SearchController;
import 'package:knit/features/card_links/domain/card_links_models.dart';
import 'package:knit/features/card_links/presentation/card_links_controller.dart';
import 'package:knit/features/card_links/presentation/link_picker_sheet.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/features/collection/presentation/collection_page.dart';
import 'package:knit/features/search/domain/search_filter.dart';
import 'package:knit/features/search/domain/search_models.dart';
import 'package:knit/features/search/presentation/search_controller.dart';
import 'package:knit/features/search/presentation/search_state.dart';
import 'package:knit/l10n/app_localizations.dart';

/// Full-screen search (§3.2/§4.1): type a query, submit it from the keyboard,
/// and get every matching collection and card ranked most relevant first,
/// narrowed by the filter chips (kind, settled, archived, linked to). Opened
/// from a collection (§4.2) it searches only that collection's cards, under an
/// "In: <title>" chip whose ✕ widens it to everything. With a "Linked to…"
/// target set, an empty query lists everything linked to it, newest first —
/// opened that way ("Find linked cards"), it shows the list at once.
///
/// Tapping a hit opens its collection (scrolled to the card for a card hit);
/// Back returns here with the results intact. A hit inside the collection the
/// search was opened from pops back to it instead, with the card to reveal as
/// the route's result. Takes ownership of [controller] and disposes it with
/// the page.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.controller});

  final SearchController controller;

  /// Pops with the card to reveal when a hit returns to the origin collection.
  static Route<String> route(SearchController controller) =>
      MaterialPageRoute<String>(
        builder: (_) => SearchPage(controller: controller),
      );

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _field = TextEditingController();

  SearchController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.start());
  }

  @override
  void dispose() {
    _field.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _field.clear();
    _controller.submit('');
  }

  void _open(SearchHit hit) {
    switch (_controller.open(hit)) {
      case ReturnToOrigin(:final focusCardId):
        Navigator.of(context).pop(focusCardId);
      case OpenCollection():
        Navigator.of(context).push(CollectionPage.route());
    }
  }

  /// The "Linked to…" chip: pick a collection or a card in the shared link
  /// picker, the chosen ones checked; a tap toggles it in the filter.
  Future<void> _pickLinkedTo(CardLinksController links) async {
    final choice = await LinkPickerSheet.show(
      context,
      links: links,
      source: LinkFilterPick(
        chosen: {
          for (final t in _controller.state.filter.linkedTo)
            (_connectedKind(t.kind), t.id),
        },
      ),
    );
    final target = switch (choice) {
      LinkTargetPicked(:final target) => target,
      LinkTargetUnpicked(:final target) => target,
      _ => null,
    };
    if (target == null || !mounted) return;
    _controller.toggleLinkedTo(
      SearchLinkTarget(
        kind: target.kind == ConnectedEntityKind.collection
            ? SearchHitKind.collection
            : SearchHitKind.card,
        id: target.id,
        label: target.label,
      ),
    );
  }

  static ConnectedEntityKind _connectedKind(SearchHitKind kind) =>
      switch (kind) {
        SearchHitKind.collection => ConnectedEntityKind.collection,
        SearchHitKind.card => ConnectedEntityKind.card,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = _controller.state;
    final links = _controller.links;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final scope = state.scope;
        return Scaffold(
          appBar: AppBar(
            title: TextField(
              controller: _field,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: _controller.submit,
              decoration: InputDecoration(
                hintText: scope == null
                    ? l10n.searchHint
                    : l10n.searchHintScoped,
                border: InputBorder.none,
              ),
            ),
            actions: [
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _field,
                builder: (context, value, _) => value.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: l10n.actionClear,
                        icon: const Icon(Icons.close),
                        onPressed: _clear,
                      ),
              ),
            ],
            bottom: scope == null
                ? null
                : _ScopeChip(
                    title: scope.title,
                    onClear: _controller.clearScope,
                  ),
          ),
          body: Column(
            children: [
              _FilterBar(
                filter: state.filter,
                scoped: scope != null,
                onResultType: _controller.setResultType,
                onKind: _controller.toggleKind,
                onSettled: _controller.cycleSettled,
                onArchived: _controller.setIncludeArchived,
              ),
              if (links != null)
                _LinkedToBar(
                  targets: [
                    for (final t in state.filter.linkedTo)
                      (
                        label: t.label,
                        isCollection: t.kind == SearchHitKind.collection,
                      ),
                  ],
                  onPick: () => _pickLinkedTo(links),
                  onRemove: (i) => _controller.toggleLinkedTo(
                    state.filter.linkedTo.elementAt(i),
                  ),
                ),
              Expanded(child: _body(l10n, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(AppLocalizations l10n, SearchState state) {
    switch (state.status) {
      case SearchStatus.idle:
        return _Message(icon: Icons.search, text: l10n.searchIdle);
      case SearchStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case SearchStatus.failed:
        return _Message(
          icon: Icons.error_outline,
          text: l10n.searchFailed,
          action: TextButton(
            onPressed: _controller.retry,
            child: Text(l10n.actionRetry),
          ),
        );
      case SearchStatus.ready:
        final hits = state.hits;
        return hits.isEmpty
            ? _Message(
                icon: Icons.search_off,
                text: state.query.trim().isEmpty
                    ? l10n.searchNothingLinked
                    : l10n.searchNoResults(state.query),
              )
            : ListView.builder(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: hits.length,
                itemBuilder: (context, i) =>
                    _HitTile(hit: hits[i], onTap: () => _open(hits[i])),
              );
    }
  }
}

/// The "In: <title>" chip under the search field (§4.2); its ✕ widens the
/// search to everything.
class _ScopeChip extends StatelessWidget implements PreferredSizeWidget {
  const _ScopeChip({required this.title, required this.onClear});

  final String title;
  final VoidCallback onClear;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = title.trim().isEmpty ? l10n.labelUntitled : title;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
        child: InputChip(
          avatar: const Icon(Icons.folder_outlined, size: 18),
          label: Text(
            l10n.searchScopeChip(name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onDeleted: onClear,
          deleteButtonTooltipMessage: l10n.searchScopeClear,
        ),
      ),
    );
  }
}

/// The filter chips (§3.2/§4.1). A global search first picks the result type
/// (all · collections · cards); then, in one scrolling row, the card kinds
/// (none on = every kind), the cycling Settled chip and — globally — whether
/// archived collections are included.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.scoped,
    required this.onResultType,
    required this.onKind,
    required this.onSettled,
    required this.onArchived,
  });

  final SearchFilter filter;

  /// A scoped search has no collection hits and one collection, so it shows
  /// neither the result-type nor the archived chip.
  final bool scoped;
  final ValueChanged<SearchResultType> onResultType;
  final ValueChanged<SearchCardKind> onKind;
  final VoidCallback onSettled;
  final ValueChanged<bool> onArchived;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!scoped)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 8,
              children: [
                for (final type in SearchResultType.values)
                  ChoiceChip(
                    label: Text(switch (type) {
                      SearchResultType.all => l10n.searchFilterAll,
                      SearchResultType.collections =>
                        l10n.searchFilterCollections,
                      SearchResultType.cards => l10n.searchFilterCards,
                    }),
                    selected: type == filter.type,
                    onSelected: (_) => onResultType(type),
                  ),
              ],
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              for (final kind in SearchCardKind.values) ...[
                FilterChip(
                  avatar: Icon(_HitTile.iconForKind(kind.tag), size: 18),
                  showCheckmark: false,
                  label: Text(switch (kind) {
                    SearchCardKind.text => l10n.searchKindText,
                    SearchCardKind.image => l10n.searchKindImage,
                    SearchCardKind.link => l10n.searchKindLink,
                    SearchCardKind.file => l10n.searchKindFile,
                    SearchCardKind.audio => l10n.searchKindAudio,
                  }),
                  selected: filter.kinds.contains(kind),
                  onSelected: (_) => onKind(kind),
                ),
                const SizedBox(width: 8),
              ],
              FilterChip(
                avatar: const Icon(Icons.spa_outlined, size: 18),
                showCheckmark: false,
                label: Text(switch (filter.settled) {
                  SettledFilter.any => l10n.searchSettledAny,
                  SettledFilter.live => l10n.searchSettledLive,
                  SettledFilter.settled => l10n.searchSettledOnly,
                }),
                selected: filter.settled != SettledFilter.any,
                onSelected: (_) => onSettled(),
              ),
              if (!scoped) ...[
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.archive_outlined, size: 18),
                  showCheckmark: false,
                  label: Text(l10n.searchIncludeArchived),
                  selected: filter.includeArchived,
                  onSelected: onArchived,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The "Linked to…" row (§4.1): the chip that opens the link picker, then
/// one removable "→ <label>" chip per chosen target, in the order chosen.
class _LinkedToBar extends StatelessWidget {
  const _LinkedToBar({
    required this.targets,
    required this.onPick,
    required this.onRemove,
  });

  final List<({String label, bool isCollection})> targets;
  final VoidCallback onPick;

  /// The ✕ on the target at this index.
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          ActionChip(
            avatar: const Icon(Icons.link, size: 18),
            label: Text(l10n.searchLinkedTo),
            onPressed: onPick,
          ),
          for (var i = 0; i < targets.length; i++)
            InputChip(
              avatar: Icon(
                targets[i].isCollection
                    ? Icons.workspaces_outline
                    : Icons.sticky_note_2_outlined,
                size: 18,
              ),
              label: Text(
                l10n.searchLinkedToChip(
                  targets[i].label.trim().isEmpty
                      ? (targets[i].isCollection
                            ? l10n.labelUntitled
                            : l10n.labelEmptyNote)
                      : targets[i].label.trim(),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              selected: true,
              showCheckmark: false,
              onPressed: onPick,
              onDeleted: () => onRemove(i),
              deleteButtonTooltipMessage: l10n.searchLinkedToRemove,
            ),
        ],
      ),
    );
  }
}

/// One result row. A collection hit shows its title, plus the matched snippet
/// when the match was in its description or a link label; a card hit shows the
/// matched snippet and the collection it lives in. A hit in an archived
/// collection (§3.4) is marked as such.
class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit, required this.onTap});

  final SearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final collectionTitle = hit.collectionTitle.trim().isEmpty
        ? l10n.labelUntitled
        : hit.collectionTitle;
    final isCollection = hit.kind == SearchHitKind.collection;
    // A browsed hit (no query) with no text — an untitled collection, a bare
    // photo — still needs a line.
    final Widget snippet = hit.snippet.isEmpty
        ? Text(
            isCollection
                ? collectionTitle
                : switch (SearchCardKind.fromTag(hit.cardKind)) {
                    SearchCardKind.text => l10n.labelEmptyNote,
                    SearchCardKind.image => l10n.searchKindImage,
                    SearchCardKind.link => l10n.searchKindLink,
                    SearchCardKind.file => l10n.searchKindFile,
                    SearchCardKind.audio => l10n.searchKindAudio,
                  },
            maxLines: 1,
          )
        : _HighlightedText(text: hit.snippet, ranges: hit.ranges);
    return ListTile(
      leading: Icon(_iconFor(hit)),
      title: isCollection
          ? (hit.field == SearchField.collectionTitle
                ? snippet
                : Text(collectionTitle, maxLines: 1))
          : snippet,
      subtitle: isCollection
          ? (hit.field == SearchField.collectionTitle ? null : snippet)
          : Text(
              l10n.searchInCollection(collectionTitle),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: hit.archived ? const _ArchivedMark() : null,
      onTap: onTap,
    );
  }

  static IconData _iconFor(SearchHit hit) =>
      hit.kind == SearchHitKind.collection
      ? Icons.folder_outlined
      : iconForKind(hit.cardKind);

  /// A card kind's icon, shared with the Kind chips.
  static IconData iconForKind(String? cardKind) => switch (cardKind) {
    'image' => Icons.image_outlined,
    'audio' => Icons.mic_none,
    'file' => Icons.insert_drive_file_outlined,
    'link' => Icons.link,
    _ => Icons.notes,
  };
}

/// A small "Archived" label on a hit in an archived collection (§3.4).
class _ArchivedMark extends StatelessWidget {
  const _ArchivedMark();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.archive_outlined, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          AppLocalizations.of(context).searchArchived,
          style: theme.textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// [text] with the [ranges] drawn bold on a tinted background.
class _HighlightedText extends StatelessWidget {
  const _HighlightedText({required this.text, required this.ranges});

  final String text;
  final List<MatchRange> ranges;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highlight = TextStyle(
      fontWeight: FontWeight.bold,
      backgroundColor: scheme.primaryContainer,
      color: scheme.onPrimaryContainer,
    );
    final spans = <TextSpan>[];
    var at = 0;
    for (final r in ranges) {
      if (r.start > at) spans.add(TextSpan(text: text.substring(at, r.start)));
      spans.add(
        TextSpan(text: text.substring(r.start, r.end), style: highlight),
      );
      at = r.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}
