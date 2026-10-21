import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/presentation/widgets/card_entrance.dart';
import 'package:knit/features/collection/presentation/widgets/collection_empty_hint.dart';
import 'package:knit/features/collection/presentation/widgets/focus_highlight.dart';
import 'package:knit/features/collection/presentation/widgets/older_cards_loader.dart';

/// How long a card takes to animate into (or out of) the feed.
const Duration _kFeedAnimation = Duration(milliseconds: 280);

/// How close (in pixels) to the loaded top of the feed the scroll must get
/// before the next older page is requested — about a screen of lead time, so
/// paging stays ahead of a normal scroll.
const double _kLoadOlderExtent = 800;

/// How long a revealed (focused) card stays highlighted before it fades.
const Duration _kFocusHighlight = Duration(milliseconds: 1600);

/// Upper bound on screen-sized scroll steps while looking for a focused card
/// that hasn't been built yet — a guard, far above any real feed's need.
const int _kRevealMaxSteps = 500;

/// The padding before the first and after the last feed item.
const double _kFeedEdgePadding = 8;

/// The Collection feed (§4.2): the chat-style card list with the title card at
/// its head, or — in reorder mode — the drag-to-reorder list.
///
/// Owns the feed's view-only state: the [SliverAnimatedList] mirror of
/// [cards] (cards animate in and out), the scroll position, paging older cards
/// in near the top (§8.7), and revealing each [focus] request once its card is
/// loaded (a search hit on entry, an Outline jump, §4.2). The rows
/// themselves come from [cardBuilder] / [reorderRowBuilder].
class CollectionFeed extends StatefulWidget {
  const CollectionFeed({
    super.key,
    required this.cards,
    required this.hasOlder,
    required this.loadingOlder,
    required this.reordering,
    required this.header,
    required this.cardBuilder,
    required this.reorderRowBuilder,
    required this.onLoadOlder,
    required this.onRefresh,
    required this.onReorder,
    required this.onHeaderMoved,
    this.focus,
  });

  /// The loaded window of the feed, oldest → newest.
  final List<FeedCard> cards;

  /// Whether older cards exist beyond [cards]; the title card shows only once
  /// the window reaches the oldest card.
  final bool hasOlder;

  /// Whether an older page is in flight.
  final bool loadingOlder;

  /// Whether drag-to-reorder mode is active.
  final bool reordering;

  /// The title card heading the feed.
  final Widget header;

  /// The header may have moved on screen: called on every layout of the chat
  /// feed's header and every scroll of the reorder list, so the page can carry
  /// the collection name into its app bar in step. Called during layout.
  final VoidCallback onHeaderMoved;

  /// One feed row for a card.
  final Widget Function(FeedCard card) cardBuilder;

  /// One reorder-mode row for the card at [index].
  final Widget Function(FeedCard card, int index) reorderRowBuilder;

  /// Ask for the next older page.
  final VoidCallback onLoadOlder;

  /// Pull-to-refresh.
  final VoidCallback onRefresh;

  /// A reorder-mode drag ended: move the card at `oldIndex` to `newIndex`.
  final void Function(int oldIndex, int newIndex) onReorder;

  /// A card to reveal and highlight (e.g. a search hit or an Outline jump).
  /// Each request is revealed once, as soon as its card is in [cards].
  final FeedFocus? focus;

  @override
  State<CollectionFeed> createState() => _CollectionFeedState();
}

class _CollectionFeedState extends State<CollectionFeed> {
  /// The feed's [SliverAnimatedList]. It owns its item count (initialItemCount
  /// is read once, at mount), so every change to [CollectionFeed.cards] must be
  /// mirrored into it via insertItem/removeItem — see [_syncList].
  final GlobalKey<SliverAnimatedListState> _listKey = GlobalKey();

  /// The cards the animated list currently holds, oldest → newest (data order).
  /// The list is reversed, so data index `i` is list index `length - 1 - i`:
  /// the newest card is list item 0, at the bottom. Kept (not just ids) so a
  /// removed card can still be drawn while it animates out.
  late List<FeedCard> _listCards = widget.cards;

  /// The feed's scroll position — driven to reveal a focused card.
  final ScrollController _scroll = ScrollController();

  /// The reorder list's scroll position, followed only for the header.
  final ScrollController _reorderScroll = ScrollController();

  /// The revealed card: its row carries [_focusCardKey] (so it can be scrolled
  /// to) and, while [_highlightFocus] holds, a fading highlight.
  String? _focusCardId;
  bool _highlightFocus = false;
  final GlobalKey _focusCardKey = GlobalKey();
  Timer? _highlightTimer;

  /// The last [CollectionFeed.focus] revealed, so each request runs once.
  FeedFocus? _revealedFocus;

  /// Bumped per reveal, so an older reveal still stepping stops.
  int _revealRun = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadOlder);
    _reorderScroll.addListener(_reportHeaderMoved);
    _maybeRevealFocus();
    _scheduleLoadOlderCheck();
  }

  @override
  void didUpdateWidget(CollectionFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.cards, widget.cards)) _syncList();
    _maybeRevealFocus();
    _scheduleLoadOlderCheck();
  }

  /// Start revealing [CollectionFeed.focus] if it is a new request and its
  /// card is loaded; a request whose card isn't loaded yet waits for the load
  /// that brings it. Runs before the build that marks the row.
  void _maybeRevealFocus() {
    final focus = widget.focus;
    if (focus == null || focus == _revealedFocus || widget.reordering) return;
    if (!widget.cards.any((c) => c.id == focus.cardId)) return;
    _revealedFocus = focus;
    _highlightTimer?.cancel();
    _focusCardId = focus.cardId;
    _highlightFocus = true;
    final run = ++_revealRun;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _revealFocusedCard(run);
    });
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _scroll.dispose();
    _reorderScroll.dispose();
    super.dispose();
  }

  /// Page in older cards once the feed is scrolled within [_kLoadOlderExtent]
  /// of its loaded top (§8.7). The reversed scroll view's `extentAfter` is the
  /// distance left above the viewport. The updater dedupes, so repeated scroll
  /// ticks are harmless.
  void _maybeLoadOlder() {
    if (!widget.hasOlder || widget.loadingOlder || !_scroll.hasClients) return;
    if (_scroll.position.extentAfter < _kLoadOlderExtent) widget.onLoadOlder();
  }

  /// After a load lands, check again once it's laid out: a page that doesn't
  /// fill the screen, or a fling that already reached the top, needs the next
  /// page without waiting for another scroll event.
  void _scheduleLoadOlderCheck() {
    if (!widget.hasOlder || widget.loadingOlder) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeLoadOlder();
    });
  }

  void _reportHeaderMoved() => widget.onHeaderMoved();

  /// Scroll the focused card into view. The feed builds lazily, so an older
  /// card's row may not exist yet: step up the (reversed) feed a screen at a
  /// time until it is built, then center it — or, once the top is reached
  /// without it (a newer card, below the viewport), step back down. Then let
  /// the highlight fade. A newer reveal ([run] behind [_revealRun]) takes over.
  Future<void> _revealFocusedCard(int run) async {
    var up = true;
    for (var step = 0; step < _kRevealMaxSteps; step++) {
      if (run != _revealRun) return;
      final target = _focusCardKey.currentContext;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(
          target,
          alignment: 0.5,
          duration: _kFeedAnimation,
          curve: Curves.easeOutCubic,
        );
        break;
      }
      if (!_scroll.hasClients) break;
      final position = _scroll.position;
      if (up && position.pixels >= position.maxScrollExtent) up = false;
      if (!up && position.pixels <= position.minScrollExtent) break;
      final stride = position.viewportDimension * 0.8;
      _scroll.jumpTo(
        (position.pixels + (up ? stride : -stride))
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
      );
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    if (!mounted || run != _revealRun) return;
    _highlightTimer?.cancel();
    _highlightTimer = Timer(_kFocusHighlight, () {
      if (mounted) setState(() => _highlightFocus = false);
    });
  }

  /// Mirror [CollectionFeed.cards] into the animated list: an added card
  /// animates in, a removed one animates out. Runs before the rebuild that
  /// shows the new cards. While the list isn't mounted (reorder mode) the cards
  /// are only recorded — they seed its initialItemCount on remount, so they
  /// appear without animation.
  void _syncList() {
    final next = widget.cards;
    final list = _listKey.currentState;
    if (list == null) {
      _listCards = next;
      return;
    }
    final current = List.of(_listCards);
    final nextIds = {for (final c in next) c.id};
    for (var i = current.length - 1; i >= 0; i--) {
      final card = current[i];
      if (nextIds.contains(card.id)) continue;
      // The removed builder can't read the new cards (the card is gone from
      // them), so it draws the row built here — inert while it animates out.
      final row = widget.cardBuilder(card);
      list.removeItem(
        current.length - 1 - i,
        (context, animation) => CardEntrance(
          animation: animation,
          child: IgnorePointer(child: row),
        ),
        duration: _kFeedAnimation,
      );
      current.removeAt(i);
    }
    final currentIds = {for (final c in current) c.id};
    // Cards ahead of the first one already shown are an older page scrolled
    // in at the top — they appear instantly; only genuinely new cards animate.
    final firstKept = current.isEmpty
        ? 0
        : next.indexWhere((c) => currentIds.contains(c.id));
    for (var j = 0; j < next.length; j++) {
      if (currentIds.contains(next[j].id)) continue;
      current.insert(j, next[j]);
      list.insertItem(
        current.length - 1 - j,
        duration: j < firstKept ? Duration.zero : _kFeedAnimation,
      );
    }
    _listCards = next;
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards;
    if (widget.reordering) {
      // The title card heads the reorder list as a fixed, non-draggable header.
      return ReorderableListView.builder(
        scrollController: _reorderScroll,
        header: widget.header,
        padding: const EdgeInsets.symmetric(vertical: _kFeedEdgePadding),
        itemCount: cards.length,
        onReorderItem: widget.onReorder,
        itemBuilder: (context, i) => widget.reorderRowBuilder(cards[i], i),
      );
    }
    final cardCount = cards.length;
    // Card id → its (reversed) list index, built once per build so the key
    // lookup below stays O(1) however large the collection grows.
    final listIndexById = <String, int>{
      for (var i = 0; i < cardCount; i++) cards[i].id: cardCount - 1 - i,
    };
    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      // Chat-style: the scroll view is reversed, so its start — list item 0 —
      // sits at the bottom, right above the composer, and holds the *newest*
      // card. A new card is inserted at item 0: it appears in view, in place,
      // with no scrolling. The title card comes after the cards, so it heads the
      // feed once scrolled up; an empty feed shows a hint beneath it.
      child: CustomScrollView(
        controller: _scroll,
        reverse: true,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverPadding(padding: EdgeInsets.only(top: 8)),
          SliverAnimatedList(
            key: _listKey,
            initialItemCount: _listCards.length,
            // An insert at item 0 shifts every index: keep each card's element
            // (and its decoded image) attached to its id rather than its slot.
            findChildIndexCallback: (key) =>
                key is ValueKey<String> ? listIndexById[key.value] : null,
            itemBuilder: (context, i, animation) {
              final card = cards[cardCount - 1 - i];
              final row = widget.cardBuilder(card);
              return CardEntrance(
                key: ValueKey(card.id),
                animation: animation,
                child: card.id == _focusCardId
                    ? FocusHighlight(
                        key: _focusCardKey,
                        active: _highlightFocus,
                        child: row,
                      )
                    : row,
              );
            },
          ),
          if (cards.isEmpty && !widget.hasOlder)
            const SliverToBoxAdapter(child: CollectionEmptyHint()),
          // The title card heads the *whole* feed, so it only appears once the
          // window reaches the oldest card; until then a loader marks the top.
          if (widget.hasOlder)
            SliverToBoxAdapter(
              child: OlderCardsLoader(loading: widget.loadingOlder),
            )
          else
            _HeaderSliver(onLayout: _reportHeaderMoved, child: widget.header),
          const SliverPadding(padding: EdgeInsets.only(top: _kFeedEdgePadding)),
        ],
      ),
    );
  }
}

/// The title card's sliver: a [SliverToBoxAdapter] that reports each of its
/// layouts. The viewport lays it out whenever its place on screen may change —
/// a scroll, a card animating in below it, the feed resizing — so the report
/// lands in the same frame, before paint.
class _HeaderSliver extends SingleChildRenderObjectWidget {
  const _HeaderSliver({required this.onLayout, required Widget super.child});

  final VoidCallback onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHeaderSliver(onLayout);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHeaderSliver renderObject,
  ) => renderObject.onLayout = onLayout;
}

class _RenderHeaderSliver extends RenderSliverToBoxAdapter {
  _RenderHeaderSliver(this.onLayout);

  VoidCallback onLayout;

  @override
  void performLayout() {
    super.performLayout();
    onLayout();
  }
}
