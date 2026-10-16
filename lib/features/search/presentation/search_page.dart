import 'package:flutter/material.dart' hide SearchController;
import 'package:knit/features/collection/presentation/collection_page.dart';
import 'package:knit/features/search/domain/search_models.dart';
import 'package:knit/features/search/presentation/search_controller.dart';
import 'package:knit/features/search/presentation/search_state.dart';
import 'package:knit/l10n/app_localizations.dart';

/// Full-screen search (§3.2/§4.1): type a query, submit it from the keyboard,
/// and get every matching collection and card ranked most relevant first.
/// Tapping a hit opens its collection (scrolled to the card for a card hit);
/// Back returns here with the results intact. Takes ownership of [controller]
/// and disposes it with the page.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.controller});

  final SearchController controller;

  static Route<void> route(SearchController controller) =>
      MaterialPageRoute<void>(
        builder: (_) => SearchPage(controller: controller),
      );

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _field = TextEditingController();

  SearchController get _controller => widget.controller;

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
    _controller.open(hit);
    Navigator.of(context).push(CollectionPage.route());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _field,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: _controller.submit,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
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
      ),
      body: ListenableBuilder(
        listenable: _controller.state,
        builder: (context, _) => _body(l10n, _controller.state),
      ),
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
        final hits = state.visibleHits;
        return Column(
          children: [
            _FilterChips(
              selected: state.filter,
              onSelected: _controller.setFilter,
            ),
            Expanded(
              child: hits.isEmpty
                  ? _Message(
                      icon: Icons.search_off,
                      text: l10n.searchNoResults(state.query),
                    )
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: hits.length,
                      itemBuilder: (context, i) =>
                          _HitTile(hit: hits[i], onTap: () => _open(hits[i])),
                    ),
            ),
          ],
        );
    }
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final SearchFilter selected;
  final ValueChanged<SearchFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Wrap(
        spacing: 8,
        children: [
          for (final filter in SearchFilter.values)
            ChoiceChip(
              label: Text(switch (filter) {
                SearchFilter.all => l10n.searchFilterAll,
                SearchFilter.collections => l10n.searchFilterCollections,
                SearchFilter.cards => l10n.searchFilterCards,
              }),
              selected: filter == selected,
              onSelected: (_) => onSelected(filter),
            ),
        ],
      ),
    );
  }
}

/// One result row. A collection hit shows its title, plus the matched snippet
/// when the match was in its description or a link label; a card hit shows the
/// matched snippet and the collection it lives in.
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
    final snippet = _HighlightedText(text: hit.snippet, ranges: hit.ranges);
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
      onTap: onTap,
    );
  }

  static IconData _iconFor(SearchHit hit) {
    if (hit.kind == SearchHitKind.collection) return Icons.folder_outlined;
    return switch (hit.cardKind) {
      'image' => Icons.image_outlined,
      'audio' => Icons.mic_none,
      'file' => Icons.insert_drive_file_outlined,
      'link' => Icons.link,
      _ => Icons.notes,
    };
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
