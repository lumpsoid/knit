import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:knit/l10n/app_localizations.dart';
import 'package:knit/core/attachments/domain/image_picker_port.dart';
import 'package:knit/core/attachments/presentation/attachment_image.dart';
import 'package:knit/features/card_edit/presentation/card_edit_page.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_page.dart';
import 'package:knit/features/collection/presentation/audio_mini_player.dart';
import 'package:knit/features/collection/presentation/audio_playback_controller.dart';
import 'package:knit/features/collection/presentation/collection_action.dart';
import 'package:knit/features/collection/presentation/collection_controller.dart';
import 'package:knit/features/collection/presentation/collection_scope.dart';
import 'package:knit/features/collection/presentation/collection_state.dart';
import 'package:knit/features/collection/presentation/collection_ui_effect.dart';
import 'package:knit/features/collection/presentation/image_gallery_page.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/features/connections/presentation/connections_page.dart';

/// The Collection screen (§4.2) — a chat-style card feed (oldest at top), a
/// bottom composer, a "+" add-block sheet, per-card actions, and drag-to-reorder
/// as a *mode* of this screen.
class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const CollectionPage());

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  // One controller per page instance (fcis.md §4), built in [initState] and
  // disposed in [dispose] — so a Collection page stacked over another (e.g.
  // pushed from Connections) never shares state with it. The audio player stays
  // an app-wide singleton.
  late final CollectionController _controller;
  AudioPlaybackController get _playback => CollectionScope.playbackController;
  final TextEditingController _composer = TextEditingController();

  /// Whether the inline gallery/camera options are shown above the composer.
  /// Pure UI state (like [_composer]): the user revealed them via "+" → Photo
  /// and dismisses them by picking a source. Kept local — no business decision.
  bool _showPhotoSources = false;

  /// Whether the inline audio-recording bar is revealed above the composer. Pure
  /// UI state (the "reveal" gesture from "+" → Audio); the *recording* sub-state
  /// itself lives in [CollectionState.recordingPhase] since it drives a real
  /// resource. Reset once a clip is captured (the pending preview takes over) or
  /// the user backs out.
  bool _showAudioBar = false;

  /// The feed's [SliverAnimatedList]. It owns its item count (initialItemCount
  /// is read once, at mount), so every change to the feed data must be mirrored
  /// into it via insertItem/removeItem — see [_syncFeedList].
  final GlobalKey<SliverAnimatedListState> _feedListKey = GlobalKey();

  /// The cards the animated list currently holds, oldest → newest (data order).
  /// The list is reversed, so data index `i` is list index `length - 1 - i`:
  /// the newest card is list item 0, at the bottom. Kept (not just ids) so a
  /// removed card can still be drawn while it animates out.
  List<FeedCard> _feedListCards = const [];

  /// The feed's scroll position — driven to reveal a focused card.
  final ScrollController _feedScroll = ScrollController();

  /// A card the route args asked to reveal on entry (e.g. a search hit),
  /// waiting for the first loaded feed; null once handled.
  String? _pendingFocusId;

  /// The revealed card: its row carries [_focusCardKey] (so it can be scrolled
  /// to) and, while [_highlightFocus] holds, a fading highlight.
  String? _focusCardId;
  bool _highlightFocus = false;
  final GlobalKey _focusCardKey = GlobalKey();
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    _pendingFocusId = CollectionScope.routeArgs.focusCardId;
    _controller = CollectionScope.create()
      ..onAttach(_onUiEffect)
      ..dispatch(
        ViewAttached(
          CollectionScope.routeArgs.collectionId,
          focusCardId: _pendingFocusId,
        ),
      );
    _controller.stateHolder
      ..addListener(_syncFeedList)
      ..addListener(_maybeRevealFocus)
      ..addListener(_scheduleLoadOlderCheck);
    _feedScroll.addListener(_maybeLoadOlder);
  }

  /// Page in older cards once the feed is scrolled within
  /// [_kLoadOlderExtent] of its loaded top (§8.7). The reversed scroll view's
  /// `extentAfter` is the distance left above the viewport. The updater
  /// dedupes, so repeated scroll ticks are harmless.
  void _maybeLoadOlder() {
    final state = _controller.stateHolder.value;
    if (!state.hasOlder || state.loadingOlder || !_feedScroll.hasClients) {
      return;
    }
    if (_feedScroll.position.extentAfter < _kLoadOlderExtent) {
      _controller.dispatch(const OlderCardsRequested());
    }
  }

  /// After a load lands, check again once it's laid out: a page that doesn't
  /// fill the screen, or a fling that already reached the top, needs the next
  /// page without waiting for another scroll event.
  void _scheduleLoadOlderCheck() {
    final state = _controller.stateHolder.value;
    if (!state.hasOlder || state.loadingOlder) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeLoadOlder();
    });
  }

  /// On the first loaded feed, mark the requested card (if it still exists) and
  /// scroll to it once the feed has been laid out. Runs before the rebuild the
  /// state change schedules, so the row picks up the key in that build.
  void _maybeRevealFocus() {
    final cardId = _pendingFocusId;
    final state = _controller.stateHolder.value;
    if (cardId == null || state.status != CollectionStatus.ready) return;
    _pendingFocusId = null;
    if (!state.cards.any((c) => c.id == cardId)) return;
    _focusCardId = cardId;
    _highlightFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealFocusedCard());
  }

  /// Scroll the focused card into view. The feed builds lazily, so an older
  /// card's row may not exist yet: step up the (reversed) feed a screen at a
  /// time until it is built, then center it. Then let the highlight fade.
  Future<void> _revealFocusedCard() async {
    for (var step = 0; step < _kRevealMaxSteps; step++) {
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
      if (!_feedScroll.hasClients) break;
      final position = _feedScroll.position;
      if (position.pixels >= position.maxScrollExtent) break;
      _feedScroll.jumpTo(
        (position.pixels + position.viewportDimension * 0.8)
            .clamp(0.0, position.maxScrollExtent)
            .toDouble(),
      );
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    if (!mounted) return;
    _highlightTimer = Timer(_kFocusHighlight, () {
      if (mounted) setState(() => _highlightFocus = false);
    });
  }

  /// Mirror the feed's cards into the animated list: an added card animates in,
  /// a removed one animates out. Runs on every state change, before the rebuild
  /// it schedules. While the list isn't mounted (loading, error, reorder mode)
  /// the cards are only recorded — they seed its initialItemCount on (re)mount,
  /// so the first load appears without animation.
  void _syncFeedList() {
    final next = _controller.stateHolder.value.cards;
    final list = _feedListKey.currentState;
    if (list == null) {
      _feedListCards = next;
      return;
    }
    final current = List.of(_feedListCards);
    final nextIds = {for (final c in next) c.id};
    for (var i = current.length - 1; i >= 0; i--) {
      final card = current[i];
      if (nextIds.contains(card.id)) continue;
      // The removed builder can't read the state (the card is gone from it), so
      // it draws the card captured here — inert while it animates out.
      final imageBytes = _bytesFor(card);
      list.removeItem(
        current.length - 1 - i,
        (context, animation) => _CardEntrance(
          animation: animation,
          child: IgnorePointer(child: _cardRow(card, imageBytes)),
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
    _feedListCards = next;
  }

  @override
  void dispose() {
    // Leaving the collection stops playback so audio doesn't trail the user out
    // (the player itself is an app-wide singleton — only the clip is released).
    unawaited(_playback.close());
    // Cancel any in-flight recording, then tear down the page-owned controller
    // (detaches the effect seam and disposes the state-holder notifier).
    _highlightTimer?.cancel();
    _controller
      ..stateHolder.removeListener(_syncFeedList)
      ..stateHolder.removeListener(_maybeRevealFocus)
      ..stateHolder.removeListener(_scheduleLoadOlderCheck)
      ..dispatch(const DeactivateFeature())
      ..dispose();
    _feedScroll.dispose();
    _composer.dispose();
    super.dispose();
  }

  void _onUiEffect(CollectionUiEffect effect) {
    if (!mounted) return;
    switch (effect) {
      case CollectionShowMessageUiEffect(:final message):
        final l10n = AppLocalizations.of(context);
        final text = switch (message) {
          CollectionMessage.saveFailed => l10n.collectionSaveFailed,
          CollectionMessage.micPermissionDenied =>
            l10n.collectionAudioPermissionDenied,
          CollectionMessage.linkOpenFailed => l10n.collectionLinkOpenFailed,
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  // --- intents ---------------------------------------------------------------

  void _submitComposer() {
    final state = _controller.stateHolder.value;
    // No send while a recording is in flight — the user stops it first.
    if (state.isRecordingAudio) return;
    final text = _composer.text;
    // A staged image, audio clip, or file makes an empty caption a valid send.
    final hasPending =
        state.pendingImage != null ||
        state.pendingAudio != null ||
        state.pendingFile != null;
    if (text.trim().isEmpty && !hasPending) return;
    _controller.dispatch(ComposerSubmitted(text));
    _composer.clear();
    if (_showPhotoSources || _showAudioBar) {
      setState(() {
        _showPhotoSources = false;
        _showAudioBar = false;
      });
    }
  }

  /// A source was chosen from the inline options: hide them and open the picker.
  void _pickImage(ImagePickerSource source) {
    setState(() => _showPhotoSources = false);
    _controller.dispatch(PickImageRequested(source));
  }

  /// Leave the photo-source mode without picking (the "✕" the "+" turns into).
  void _cancelPhotoSources() => setState(() => _showPhotoSources = false);

  // --- audio recording intents ----------------------------------------------

  /// Reveal the inline audio bar (from "+" → Audio); modes are exclusive.
  void _revealAudioBar() => setState(() {
    _showAudioBar = true;
    _showPhotoSources = false;
  });

  void _startRecording() =>
      _controller.dispatch(const AudioRecordingRequested());

  void _pauseRecording() =>
      _controller.dispatch(const AudioRecordingPauseRequested());

  void _resumeRecording() =>
      _controller.dispatch(const AudioRecordingResumeRequested());

  /// Stop capturing: hide the bar now (the captured clip arrives as a pending
  /// preview) and finish the recording.
  void _stopRecording() {
    setState(() => _showAudioBar = false);
    _controller.dispatch(const AudioRecordingStopRequested());
  }

  /// Back out of the audio bar (its "✕"): hide it, and discard an in-flight
  /// recording if one is running.
  void _cancelAudioMode() {
    final recording = _controller.stateHolder.value.isRecordingAudio;
    setState(() => _showAudioBar = false);
    if (recording) _controller.dispatch(const AudioRecordingCancelled());
  }

  void _clearPendingAudio() =>
      _controller.dispatch(const PendingAudioCleared());

  Future<void> _openAddBlock() async {
    final kind = await showModalBottomSheet<CardKind>(
      context: context,
      builder: (_) => const _AddBlockSheet(),
    );
    if (kind == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    switch (kind) {
      case CardKind.link:
        final url = await _promptText(
          title: l10n.collectionAddLinkTitle,
          hint: l10n.collectionAddLinkHint,
          action: l10n.actionAdd,
        );
        if (url != null) _controller.dispatch(LinkCardSubmitted(url));
      case CardKind.image:
        // Reveal the inline gallery/camera options above the composer; choosing
        // one opens the picker. The photo only becomes a card when the user
        // sends, so they can add a caption, clear it, or repick first.
        setState(() => _showPhotoSources = true);
      case CardKind.audio:
        // Reveal the inline recording bar above the composer; the user records,
        // optionally adds a caption, and sends — mirroring the photo flow.
        _revealAudioBar();
      case CardKind.file:
        // Open the platform picker straight away; the chosen file becomes a
        // pending preview above the composer (the user can caption it, then send).
        _controller.dispatch(const PickFileRequested());
      case CardKind.text:
      case CardKind.unknown:
        break;
    }
  }

  Future<void> _openCardActions(FeedCard card) async {
    final action = await showModalBottomSheet<_CardAction>(
      context: context,
      builder: (_) => const _CardActionsSheet(),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _CardAction.edit:
        await _openCardEdit(card);
      case _CardAction.delete:
        _controller.dispatch(CardDeleteRequested(card.id));
      case _CardAction.link:
        await _openLinkFinder(card);
      case _CardAction.connections:
        _openConnections(
          kind: ConnectedEntityKind.card,
          id: card.id,
          title: _cardLabel(AppLocalizations.of(context), card),
        );
      case _CardAction.share:
        _controller.dispatch(CardShareRequested(card.id));
      case _CardAction.reorder:
        _controller.dispatch(const StartReorder());
    }
  }

  /// Hand the card to the Card Edit carrier (cross_feature.md §2), then navigate
  /// to the dedicated edit page (§4.3). On return, resync from the projection so
  /// the saved change shows in the feed (projection-is-truth — no push needed).
  Future<void> _openCardEdit(FeedCard card) async {
    CollectionScope.cardEditRouteArgsWriter.open(
      cardId: card.id,
      initialText: card.text ?? '',
      initialAttachmentId: card.attachmentId,
      initialAttachmentKind: card.attachmentId == null ? null : card.kind,
      initialFileName: card.fileName,
      initialFileSize: card.fileSize,
    );
    await Navigator.of(context).push(CardEditPage.route());
    if (mounted) _controller.dispatch(const ReloadRequested());
  }

  /// Open a card's image full-screen in the swipeable zoom gallery (§4.2), over
  /// every loaded image card in feed order and starting at [card]. Each feed
  /// thumbnail shares a [Hero] with its gallery page, so the open/close animates.
  void _openImagePreview(FeedCard card) {
    final state = _controller.stateHolder.value;
    final images = <GalleryImage>[];
    var initialIndex = 0;
    for (final c in state.cards) {
      if (c.kind != CardKind.image) continue;
      final bytes = _bytesFor(c);
      if (bytes == null) continue;
      if (c.id == card.id) initialIndex = images.length;
      images.add(
        GalleryImage(
          bytes: bytes,
          heroTag: _imageHeroTag(c.id),
          caption: c.text,
        ),
      );
    }
    if (images.isEmpty) return;
    Navigator.of(
      context,
    ).push(ImageGalleryPage.route(images: images, initialIndex: initialIndex));
  }

  /// Open the collection's cover full-screen for zoom viewing — the same viewer
  /// as a card image (a single page), with the banner as its [Hero] source.
  void _openCoverPreview(String collectionId, Uint8List bytes) {
    Navigator.of(context).push(
      ImageGalleryPage.route(
        images: [
          GalleryImage(bytes: bytes, heroTag: _coverHeroTag(collectionId)),
        ],
      ),
    );
  }

  /// Hand the focused entity to the Connections carrier (cross_feature.md §2),
  /// then navigate (§4.4). The carrier is the payload — navigation stays empty.
  void _openConnections({
    required ConnectedEntityKind kind,
    required String id,
    required String title,
  }) {
    CollectionScope.connectionsRouteArgsWriter.open(
      kind: kind,
      id: id,
      title: title,
    );
    Navigator.of(context).push(ConnectionsPage.route());
  }

  /// A short label for a card, used to seed the Connections breadcrumb.
  static String _cardLabel(AppLocalizations l10n, FeedCard card) {
    final text = card.text?.trim();
    if (text != null && text.isNotEmpty) return text;
    return switch (card.kind) {
      CardKind.image => l10n.collectionCardPhoto,
      CardKind.audio => card.fileName ?? l10n.collectionCardAudio,
      CardKind.file => card.fileName ?? l10n.collectionCardFile,
      CardKind.link => l10n.collectionCardLink,
      CardKind.text || CardKind.unknown => l10n.labelEmptyNote,
    };
  }

  /// Open the link finder for [card]: load the first level (collections), then
  /// let the user link directly to a collection or drill in to pick any card
  /// (§4.4). The sheet observes controller state so each level loads lazily.
  Future<void> _openLinkFinder(FeedCard card) async {
    _controller.dispatch(const LinkFinderOpened());
    final picked = await showModalBottomSheet<LinkOption>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LinkFinderSheet(
        controller: _controller,
        sourceCardId: card.id,
        currentCollectionId: _controller.stateHolder.value.collectionId,
      ),
    );
    if (picked == null || !mounted) return;
    _controller.dispatch(
      LinkRequested(
        cardId: card.id,
        targetKind: picked.kind,
        targetId: picked.id,
      ),
    );
  }

  /// Hand the collection to the Collection Edit carrier (cross_feature.md §2),
  /// then navigate to the dedicated edit page (§4.2) — title, description, cover.
  /// The title card follows the shared collection details as they change; on
  /// return, resync from the projection so a new cover's bytes load.
  Future<void> _openCollectionEdit(String collectionId) async {
    CollectionScope.collectionEditRouteArgsWriter.open(
      collectionId: collectionId,
    );
    await Navigator.of(context).push(CollectionEditPage.route());
    if (mounted) _controller.dispatch(const ReloadRequested());
  }

  /// A simple single-field text prompt; returns null on cancel/empty.
  Future<String?> _promptText({
    required String title,
    required String action,
    String initial = '',
    String? hint,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _PromptDialog(
        title: title,
        action: action,
        initial: initial,
        hint: hint,
      ),
    );
    final trimmed = result?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  // --- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The feed also follows the shared image cache, so thumbnails appear as
    // their bytes land.
    return ListenableBuilder(
      listenable: Listenable.merge([
        _controller.stateHolder,
        CollectionScope.images,
      ]),
      builder: (context, _) {
        final state = _controller.stateHolder.value;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.collectionAppBarTitle),
            actions: [
              if (state.status == CollectionStatus.ready && state.canReorder)
                state.reordering
                    ? TextButton(
                        onPressed: () =>
                            _controller.dispatch(const EndReorder()),
                        child: Text(l10n.actionDone),
                      )
                    : IconButton(
                        tooltip: l10n.collectionReorderTooltip,
                        icon: const Icon(Icons.swap_vert),
                        onPressed: () =>
                            _controller.dispatch(const StartReorder()),
                      ),
            ],
          ),
          body: Column(
            children: [
              Expanded(child: _body(state)),
              // The persistent player sits between the feed and the composer so
              // it stays on screen as the feed scrolls — shown in reorder mode
              // too, so the user never loses what's playing.
              ValueListenableBuilder<PlaybackSnapshot>(
                valueListenable: _playback.snapshot,
                builder: (context, snap, _) {
                  if (!snap.isActive) return const SizedBox.shrink();
                  return AudioMiniPlayer(
                    phase: snap.phase,
                    position: snap.position,
                    duration: snap.duration,
                    onPlayPause: () => unawaited(_playback.togglePlayPause()),
                    onSeek: (d) => unawaited(_playback.seek(d)),
                    onClose: () => unawaited(_playback.close()),
                  );
                },
              ),
              if (!state.reordering)
                _Composer(
                  controller: _composer,
                  pendingImageBytes: state.pendingImage?.bytes,
                  pendingFileName: state.pendingFile?.name,
                  showPhotoSources: _showPhotoSources,
                  hasPendingAudio: state.pendingAudio != null,
                  showAudioBar: _showAudioBar,
                  recordingPhase: state.recordingPhase,
                  onSend: _submitComposer,
                  onAddBlock: _openAddBlock,
                  onCancelPhotoSources: _cancelPhotoSources,
                  onPickFromGallery: () =>
                      _pickImage(ImagePickerSource.gallery),
                  onPickFromCamera: () => _pickImage(ImagePickerSource.camera),
                  onClearImage: () =>
                      _controller.dispatch(const PendingImageCleared()),
                  onClearFile: () =>
                      _controller.dispatch(const PendingFileCleared()),
                  onStartRecording: _startRecording,
                  onPauseRecording: _pauseRecording,
                  onResumeRecording: _resumeRecording,
                  onStopRecording: _stopRecording,
                  onCancelAudio: _cancelAudioMode,
                  onClearAudio: _clearPendingAudio,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _body(CollectionState state) {
    switch (state.status) {
      case CollectionStatus.loading:
        if (state.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return _feed(state);
      case CollectionStatus.failed:
        return _ErrorView(
          message: AppLocalizations.of(context).collectionLoadError,
          onRetry: () => _controller.dispatch(const ReloadRequested()),
        );
      case CollectionStatus.ready:
        // The title card heads the feed even when there are no cards yet, so a
        // brand-new collection can still be opened to edit its title/cover.
        return _feed(state);
    }
  }

  Widget _feed(CollectionState state) {
    final titleCard = _titleCard(state);

    if (state.reordering) {
      // The title card heads the reorder list as a fixed, non-draggable header.
      return ReorderableListView.builder(
        header: titleCard,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.cards.length,
        onReorderItem: (oldIndex, newIndex) =>
            _controller.dispatch(CardMoved(oldIndex, newIndex)),
        itemBuilder: (context, i) {
          final card = state.cards[i];
          return _ReorderRow(
            key: ValueKey(card.id),
            card: card,
            index: i,
            imageBytes: _bytesFor(card),
          );
        },
      );
    }
    final cardCount = state.cards.length;
    // Card id → its (reversed) list index, built once per build so the key
    // lookup below stays O(1) however large the collection grows.
    final listIndexById = <String, int>{
      for (var i = 0; i < cardCount; i++) state.cards[i].id: cardCount - 1 - i,
    };
    return RefreshIndicator(
      onRefresh: () async => _controller.dispatch(const ReloadRequested()),
      // Chat-style: the scroll view is reversed, so its start — list item 0 —
      // sits at the bottom, right above the composer, and holds the *newest*
      // card. A new card is inserted at item 0: it appears in view, in place,
      // with no scrolling. The title card comes after the cards, so it heads the
      // feed once scrolled up; an empty feed shows a hint beneath it.
      child: CustomScrollView(
        controller: _feedScroll,
        reverse: true,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverPadding(padding: EdgeInsets.only(top: 8)),
          SliverAnimatedList(
            key: _feedListKey,
            initialItemCount: _feedListCards.length,
            // An insert at item 0 shifts every index: keep each card's element
            // (and its decoded image) attached to its id rather than its slot.
            findChildIndexCallback: (key) =>
                key is ValueKey<String> ? listIndexById[key.value] : null,
            itemBuilder: (context, i, animation) {
              final card = state.cards[cardCount - 1 - i];
              final row = _cardRow(card, _bytesFor(card));
              return _CardEntrance(
                key: ValueKey(card.id),
                animation: animation,
                child: card.id == _focusCardId
                    ? _FocusHighlight(
                        key: _focusCardKey,
                        active: _highlightFocus,
                        child: row,
                      )
                    : row,
              );
            },
          ),
          if (state.isEmpty) const SliverToBoxAdapter(child: _EmptyHint()),
          // The title card heads the *whole* feed, so it only appears once the
          // window reaches the oldest card; until then a loader marks the top.
          if (state.hasOlder)
            SliverToBoxAdapter(
              child: _OlderCardsLoader(loading: state.loadingOlder),
            )
          else
            SliverToBoxAdapter(child: titleCard),
          const SliverPadding(padding: EdgeInsets.only(top: 8)),
        ],
      ),
    );
  }

  /// The title card heading the feed: the collection's header from the shared
  /// collection details (it rebuilds when they change), plus this screen's
  /// connection count and decoded cover.
  Widget _titleCard(CollectionState state) {
    final details = CollectionScope.collectionDetails;
    return ListenableBuilder(
      listenable: Listenable.merge([details, CollectionScope.images]),
      builder: (context, _) {
        final header = details.of(state.collectionId);
        final title = header?.title ?? '';
        final coverId = header?.coverAttachmentId;
        final coverBytes = coverId == null
            ? null
            : CollectionScope.images.of(coverId);
        return _CollectionTitleCard(
          title: title,
          description: header?.description,
          hasCover: coverId != null,
          coverBytes: coverBytes,
          coverHeroTag: _coverHeroTag(state.collectionId),
          connectionCount: state.connectionCount,
          onTap: () => _openCollectionEdit(state.collectionId),
          onCoverTap: coverBytes == null
              ? null
              : () => _openCoverPreview(state.collectionId, coverBytes),
          onConnectionsTap: () => _openConnections(
            kind: ConnectedEntityKind.collection,
            id: state.collectionId,
            title: title,
          ),
        );
      },
    );
  }

  /// One feed row for [card]: its bubble, plus a connections badge when linked.
  Widget _cardRow(FeedCard card, Uint8List? bytes) {
    final audioId = card.kind == CardKind.audio ? card.attachmentId : null;
    final bubble = _CardBubble(
      card: card,
      imageBytes: bytes,
      onTap: () => _openCardActions(card),
      onImageTap: bytes == null ? null : () => _openImagePreview(card),
      // Tapping a captioned file card shares it through the system sheet
      // (which offers "Open with…"); the same path the actions-sheet Share
      // uses. A caption-less file card has no other tap target, so leave it
      // null: the tap falls through to the bubble's actions sheet (which
      // already carries Share) — otherwise the user could never reach
      // Delete to remove the card.
      onFileTap:
          card.kind == CardKind.file && (card.text?.trim().isNotEmpty ?? false)
          ? () => _controller.dispatch(CardShareRequested(card.id))
          : null,
      // Tapping a link card opens its URL in the browser (dispatched as an
      // intent — the launch itself lives behind the LinkLauncher port). A
      // label-less link has no URL to open, so it falls through to the
      // bubble's actions sheet (where Delete still lives).
      onLinkTap:
          card.kind == CardKind.link && (card.text?.trim().isNotEmpty ?? false)
          ? () => _controller.dispatch(LinkCardOpened(card.id))
          : null,
      // A playable audio card gets the shared player snapshot (to flip when
      // it's the one playing) and a tap-to-toggle on its play button.
      playback: audioId == null ? null : _playback.snapshot,
      onToggleAudio: audioId == null
          ? null
          : () => unawaited(_playback.toggle(card.id, audioId)),
    );
    // A card with links-out (§4.4) gets a count badge under its bubble;
    // tapping it opens the Connections page focused on that card — the
    // same destination as the actions sheet's "Connections".
    final item = card.connectionCount == 0
        ? bubble
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              bubble,
              _CardConnectionsBadge(
                count: card.connectionCount,
                onTap: () => _openConnections(
                  kind: ConnectedEntityKind.card,
                  id: card.id,
                  title: _cardLabel(AppLocalizations.of(context), card),
                ),
              ),
            ],
          );
    // The whole feed row — not just the bubble — opens the card-actions
    // sheet: a tap on the empty space beside a short bubble lands here.
    // Inner tap targets (bubble, image, link, badge) still win the arena.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openCardActions(card),
      child: item,
    );
  }

  /// The cached decoded bytes for a card's image, if any (null ⇒ placeholder).
  static Uint8List? _bytesFor(FeedCard card) {
    final id = card.attachmentId;
    return id == null ? null : CollectionScope.images.of(id);
  }
}

// --- card kinds for the sheets ---------------------------------------------

enum _CardAction { edit, delete, link, connections, share, reorder }

// --- widgets ---------------------------------------------------------------

/// How long a card takes to animate into (or out of) the feed.
const Duration _kFeedAnimation = Duration(milliseconds: 280);

/// How close (in pixels) to the loaded top of the feed the scroll must get
/// before the next older page is requested — about a screen of lead time, so
/// paging stays ahead of a normal scroll.
const double _kLoadOlderExtent = 800;

/// The top of a partially loaded feed: a spinner while an older page is in
/// flight, otherwise an empty slot of the same height. A sliver box child is
/// built even far off screen, so an always-on spinner would tick forever.
class _OlderCardsLoader extends StatelessWidget {
  const _OlderCardsLoader({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Center(
      child: SizedBox.square(
        dimension: 24,
        child: loading ? const CircularProgressIndicator(strokeWidth: 2) : null,
      ),
    ),
  );
}

/// How long a revealed (focused) card stays highlighted before it fades.
const Duration _kFocusHighlight = Duration(milliseconds: 1600);

/// Upper bound on screen-sized scroll steps while looking for a focused card
/// that hasn't been built yet — a guard, far above any real feed's need.
const int _kRevealMaxSteps = 500;

/// The tint behind a revealed card (e.g. opened from a search hit): shown at
/// once, then faded out when [active] turns false.
class _FocusHighlight extends StatelessWidget {
  const _FocusHighlight({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tint = Theme.of(context).colorScheme.primaryContainer;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: active ? 0.7 : 0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

/// A feed card's entrance/exit, driven by its [SliverAnimatedList] animation:
/// the row opens its space (nudging the cards above it up), while the card
/// fades in and rises slightly. Played in reverse when a card is removed. Initial
/// items get a completed animation, so they render as-is.
class _CardEntrance extends StatelessWidget {
  const _CardEntrance({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SizeTransition(
      sizeFactor: curved,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.25),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      ),
    );
  }
}

/// The shared [Hero] tag tying a card's feed thumbnail to its full-screen
/// preview, so the open/close transition flies between the two.
Object _imageHeroTag(String cardId) => 'card-image-$cardId';

/// The shared [Hero] tag tying a collection's cover banner to its full-screen
/// preview.
Object _coverHeroTag(String collectionId) => 'collection-cover-$collectionId';

/// The collection's header, rendered as a distinct top-most card in the feed
/// (§4.2) — visually set apart from the chat bubbles (a full-width elevated card
/// with an optional cover banner). Shows the cover (if set), the title, the
/// optional description, and a Connections affordance (with a count badge when
/// the collection itself is linked); tapping the card opens the collection-edit
/// page. Takes primitives only (widgets.md §1).
class _CollectionTitleCard extends StatelessWidget {
  const _CollectionTitleCard({
    required this.title,
    required this.description,
    required this.hasCover,
    required this.coverBytes,
    required this.coverHeroTag,
    required this.connectionCount,
    required this.onTap,
    required this.onConnectionsTap,
    this.onCoverTap,
  });

  final String title;
  final String? description;

  /// Whether a cover is set — drives the banner (a placeholder shows while its
  /// bytes load).
  final bool hasCover;
  final Uint8List? coverBytes;

  /// The [Hero] tag the cover shares with its full-screen preview.
  final Object coverHeroTag;

  /// Open the cover full-screen to zoom; null while its bytes are loading, so
  /// a tap on the placeholder falls through to [onTap].
  final VoidCallback? onCoverTap;

  /// How many links the collection itself takes part in (§4.4); a number rides
  /// next to the Connections icon when > 0.
  final int connectionCount;
  final VoidCallback onTap;

  /// Open the collection's Connections view (§4.4).
  final VoidCallback onConnectionsTap;

  /// The cover banner. Once loaded, tapping it opens the zoom viewer (its own
  /// GestureDetector wins over the card's InkWell, which opens the edit page).
  Widget _cover() {
    final image = AttachmentImage(
      bytes: coverBytes,
      height: 160,
      fit: BoxFit.cover,
    );
    final onCoverTap = this.onCoverTap;
    if (onCoverTap == null) return image;
    return GestureDetector(
      onTap: onCoverTap,
      child: Hero(tag: coverHeroTag, child: image),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final name = title.trim().isEmpty ? l10n.labelUntitled : title.trim();
    final blurb = description?.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Card(
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasCover) _cover(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (blurb != null && blurb.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              blurb,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // The collection's own Connections affordance (moved here
                    // from the app bar). A count rides next to the icon when the
                    // collection itself is linked; its own InkWell captures the
                    // tap, so it opens Connections rather than the card's edit.
                    Tooltip(
                      message: l10n.collectionConnectionsTooltip,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: onConnectionsTap,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.hub_outlined,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              if (connectionCount > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '$connectionCount',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
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

class _CardBubble extends StatelessWidget {
  const _CardBubble({
    required this.card,
    required this.imageBytes,
    required this.onTap,
    this.onImageTap,
    this.onFileTap,
    this.onLinkTap,
    this.playback,
    this.onToggleAudio,
  });
  final FeedCard card;

  /// Decoded bytes for an image card; null while loading or missing.
  final Uint8List? imageBytes;
  final VoidCallback onTap;

  /// Opens the full-screen image preview; null when the image hasn't loaded yet
  /// (a tap then falls through to [onTap], the card-actions sheet).
  final VoidCallback? onImageTap;

  /// Shares a file card through the system sheet; null for every other kind (a
  /// tap then falls through to [onTap], the card-actions sheet).
  final VoidCallback? onFileTap;

  /// Opens a link card's URL in the browser; null for every other kind and for
  /// label-less link cards (a tap then falls through to [onTap], the
  /// card-actions sheet, so Delete stays reachable).
  final VoidCallback? onLinkTap;

  /// The shared player snapshot for a playable audio card, so its chip flips to
  /// a now-playing state when this card is the one in the player. Null for every
  /// other card kind (and audio cards whose bytes are gone).
  final ValueListenable<PlaybackSnapshot>? playback;

  /// Toggle this audio card's playback (play / pause / replay); null when not a
  /// playable audio card.
  final VoidCallback? onToggleAudio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 64, 4),
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: _content(theme, l10n),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(ThemeData theme, AppLocalizations l10n) {
    switch (card.kind) {
      case CardKind.link:
        final link = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                card.text?.trim().isNotEmpty == true
                    ? card.text!.trim()
                    : l10n.collectionCardLink,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        );
        // Tap the link itself to open it in the browser; the gesture consumes
        // the tap so it won't bubble to the actions sheet. A label-less link
        // has no [onLinkTap], so its tap falls through to [onTap].
        final onLinkTap = this.onLinkTap;
        if (onLinkTap == null) return link;
        return GestureDetector(onTap: onLinkTap, child: link);
      case CardKind.image:
        final caption = card.text?.trim();
        Widget image = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AttachmentImage(
            bytes: imageBytes,
            width: 220,
            height: 220,
            placeholder: _placeholder(
              theme,
              Icons.image_outlined,
              l10n.collectionCardPhoto,
            ),
          ),
        );
        // Tap the image itself to view it full-screen; the Hero ties this
        // thumbnail to the preview so the transition flies between them.
        final onImageTap = this.onImageTap;
        if (onImageTap != null) {
          image = GestureDetector(
            onTap: onImageTap,
            child: Hero(tag: _imageHeroTag(card.id), child: image),
          );
        }
        if (caption == null || caption.isEmpty) return image;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            image,
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(caption),
            ),
          ],
        );
      case CardKind.audio:
        final audioCaption = card.text?.trim();
        final chip = _AudioCardChip(
          cardId: card.id,
          name: card.fileName?.trim(),
          playback: playback,
          onToggle: onToggleAudio,
        );
        if (audioCaption == null || audioCaption.isEmpty) return chip;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            chip,
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(audioCaption),
            ),
          ],
        );
      case CardKind.file:
        final fileCaption = card.text?.trim();
        final chip = _FileCardChip(card: card, onTap: onFileTap);
        if (fileCaption == null || fileCaption.isEmpty) return chip;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            chip,
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(fileCaption),
            ),
          ],
        );
      case CardKind.text:
      case CardKind.unknown:
        return Text(
          card.text?.trim().isNotEmpty == true
              ? card.text!.trim()
              : l10n.labelEmptyNote,
        );
    }
  }

  Widget _placeholder(ThemeData theme, IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
      const SizedBox(width: 8),
      Text(label),
    ],
  );
}

/// The links-out count under a card bubble (§4.4). Shown only when [count] > 0;
/// tapping opens the Connections page focused on that card. A calm, left-aligned
/// pill that tucks just under the bubble — a read affordance, not a loud action.
/// Takes primitives only (widgets.md §1).
class _CardConnectionsBadge extends StatelessWidget {
  const _CardConnectionsBadge({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final label = l10n.collectionCardConnections(count);
    return Padding(
      // Left-inset to sit under the bubble (which starts 12px in), with a touch
      // more so the icon aligns near the bubble's text.
      padding: const EdgeInsets.only(left: 16, top: 2, bottom: 4),
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.hub_outlined,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  semanticsLabel: label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
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

/// An audio card's in-feed chip. Tapping its icon starts/toggles playback in the
/// shared player; when this card is the one playing it flips — a primary-tinted
/// pause/play icon and a "Now playing" label — so the user can scroll back and
/// find it. [playback] null ⇒ no attachment to play: a plain, static mic chip.
class _AudioCardChip extends StatelessWidget {
  const _AudioCardChip({
    required this.cardId,
    required this.name,
    required this.playback,
    required this.onToggle,
  });

  final String cardId;

  /// The picked file's name, shown in place of the generic "Audio" label; null
  /// or empty for an in-app recording.
  final String? name;
  final ValueListenable<PlaybackSnapshot>? playback;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final playback = this.playback;
    if (playback == null) {
      return _chip(context, active: false, playing: false, loading: false);
    }
    return ValueListenableBuilder<PlaybackSnapshot>(
      valueListenable: playback,
      builder: (context, snap, _) {
        final active = snap.cardId == cardId;
        return _chip(
          context,
          active: active,
          playing: active && snap.isPlaying,
          loading: active && snap.isLoading,
        );
      },
    );
  }

  Widget _chip(
    BuildContext context, {
    required bool active,
    required bool playing,
    required bool loading,
  }) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = active
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Own circular Material so the tap ripple clips to a circle around the
        // button instead of splashing onto the bubble's rounded rectangle (where
        // it would spill past the left corner and clip square on the right).
        Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkResponse(
            onTap: onToggle,
            containedInkWell: true,
            radius: 30,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: loading
                  ? const SizedBox(
                      width: 48,
                      height: 48,
                      child: Padding(
                        padding: EdgeInsets.all(2),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Icon(
                      playing ? Icons.pause_circle : Icons.play_circle,
                      size: 48,
                      color: color,
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            active
                ? l10n.collectionAudioNowPlaying
                : (name?.isNotEmpty == true ? name! : l10n.collectionCardAudio),
            style: active ? TextStyle(color: color) : null,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// A file card's in-feed chip: a file-type icon, the attachment's name, and its
/// size. Tapping it shares the file through the system sheet (via [onTap]); a
/// null [onTap] (e.g. a missing attachment) leaves it inert so the bubble's own
/// tap (the actions sheet) still fires.
class _FileCardChip extends StatelessWidget {
  const _FileCardChip({required this.card, required this.onTap});

  final FeedCard card;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final name = card.fileName?.trim();
    final size = card.fileSize;
    final chip = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: 32,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name == null || name.isEmpty ? l10n.collectionCardFile : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (size != null)
                  Text(
                    _formatBytes(size),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return GestureDetector(onTap: onTap, child: chip);
  }
}

/// A compact, human-readable byte size (e.g. `1.2 MB`). Decimal units, pure.
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = value >= 10
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}

class _ReorderRow extends StatelessWidget {
  const _ReorderRow({
    required this.card,
    required this.index,
    required this.imageBytes,
    super.key,
  });
  final FeedCard card;
  final int index;

  /// Decoded bytes for an image card; null while loading or missing.
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = switch (card.kind) {
      CardKind.link =>
        card.text?.isNotEmpty == true ? card.text! : l10n.collectionCardLink,
      CardKind.image =>
        card.text?.isNotEmpty == true
            ? card.text!
            : l10n.collectionReorderPhoto,
      CardKind.audio =>
        card.text?.trim().isNotEmpty == true
            ? card.text!.trim()
            : (card.fileName?.trim().isNotEmpty == true
                  ? card.fileName!.trim()
                  : l10n.collectionCardAudio),
      CardKind.file =>
        card.fileName?.trim().isNotEmpty == true
            ? card.fileName!.trim()
            : (card.text?.trim().isNotEmpty == true
                  ? card.text!.trim()
                  : l10n.collectionCardFile),
      CardKind.text || CardKind.unknown =>
        card.text?.trim().isNotEmpty == true ? card.text! : l10n.labelEmptyNote,
    };
    return ListTile(
      key: ValueKey('tile-${card.id}'),
      leading: card.kind == CardKind.image
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: AttachmentImage(
                bytes: imageBytes,
                width: 24,
                height: 24,
                placeholder: const Icon(Icons.image_outlined),
              ),
            )
          : const Icon(Icons.drag_handle),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_indicator),
      ),
    );
  }
}

/// A single-field text prompt that owns its [TextEditingController], so the
/// controller is disposed when the dialog route is actually removed — disposing
/// it the moment `showDialog` returns races the route's exit animation, which
/// still rebuilds the `TextField` (TextEditingController used after dispose).
class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.action,
    required this.initial,
    required this.hint,
  });

  final String title;
  final String action;
  final String initial;
  final String? hint;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _field = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _field,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_field.text),
          child: Text(widget.action),
        ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.pendingImageBytes,
    required this.pendingFileName,
    required this.showPhotoSources,
    required this.hasPendingAudio,
    required this.showAudioBar,
    required this.recordingPhase,
    required this.onSend,
    required this.onAddBlock,
    required this.onCancelPhotoSources,
    required this.onPickFromGallery,
    required this.onPickFromCamera,
    required this.onClearImage,
    required this.onClearFile,
    required this.onStartRecording,
    required this.onPauseRecording,
    required this.onResumeRecording,
    required this.onStopRecording,
    required this.onCancelAudio,
    required this.onClearAudio,
  });
  final TextEditingController controller;

  /// Bytes of an image the user picked but hasn't sent yet; null ⇒ no preview.
  final Uint8List? pendingImageBytes;

  /// Name of a file the user picked but hasn't sent yet; null ⇒ no preview.
  final String? pendingFileName;

  /// Whether the gallery/camera options row is shown above the input row.
  final bool showPhotoSources;

  /// Whether a recorded-but-unsent audio clip is staged (shows its preview chip).
  final bool hasPendingAudio;

  /// Whether the audio bar was revealed via "+" → Audio (the idle reveal).
  final bool showAudioBar;

  /// The live capture sub-state; non-null while recording/paused. Combined with
  /// [showAudioBar] it decides whether the recording bar is shown.
  final AudioRecordingPhase? recordingPhase;
  final VoidCallback onSend;
  final VoidCallback onAddBlock;

  /// Leave photo-source mode without picking (the "+" becomes a "✕" in mode).
  final VoidCallback onCancelPhotoSources;
  final VoidCallback onPickFromGallery;
  final VoidCallback onPickFromCamera;
  final VoidCallback onClearImage;
  final VoidCallback onClearFile;
  final VoidCallback onStartRecording;
  final VoidCallback onPauseRecording;
  final VoidCallback onResumeRecording;
  final VoidCallback onStopRecording;

  /// Back out of the audio bar (its "✕"), cancelling any in-flight recording.
  final VoidCallback onCancelAudio;
  final VoidCallback onClearAudio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final bytes = pendingImageBytes;
    // The audio bar shows while revealed-idle or actively recording (but not once
    // a clip is staged — its preview chip takes over). Modes are exclusive.
    final inAudioMode = recordingPhase != null || showAudioBar;
    final inPickerMode = showPhotoSources || inAudioMode;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bytes != null)
              _PendingImagePreview(bytes: bytes, onClear: onClearImage),
            if (hasPendingAudio) _PendingAudioPreview(onClear: onClearAudio),
            if (pendingFileName != null)
              _PendingFilePreview(name: pendingFileName!, onClear: onClearFile),
            if (showPhotoSources)
              _PhotoSourceOptions(
                onGallery: onPickFromGallery,
                onCamera: onPickFromCamera,
              ),
            if (inAudioMode)
              _AudioRecordBar(
                phase: recordingPhase,
                onStart: onStartRecording,
                onPause: onPauseRecording,
                onResume: onResumeRecording,
                onStop: onStopRecording,
              ),
            Row(
              children: [
                // In a picker mode (photo sources or audio) the "+" becomes a
                // "✕" so the user can back out without committing.
                inPickerMode
                    ? IconButton(
                        tooltip: l10n.actionCancel,
                        icon: const Icon(Icons.close),
                        onPressed: showPhotoSources
                            ? onCancelPhotoSources
                            : onCancelAudio,
                      )
                    : IconButton(
                        tooltip: l10n.collectionAddBlockTooltip,
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: onAddBlock,
                      ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: l10n.collectionComposerHint,
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.collectionSendTooltip,
                  icon: const Icon(Icons.send),
                  onPressed: onSend,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The inline photo-source options shown above the composer when the user
/// chose Photo from "+": gallery on the left, camera on the right (§4.2). Takes
/// primitives only (widgets.md §1) — two callbacks, one per source.
class _PhotoSourceOptions extends StatelessWidget {
  const _PhotoSourceOptions({required this.onGallery, required this.onCamera});
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: onGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(l10n.collectionPhotoSourceGallery),
            ),
            TextButton.icon(
              onPressed: onCamera,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(l10n.collectionPhotoSourceCamera),
            ),
          ],
        ),
      ),
    );
  }
}

/// The picked-but-unsent image shown above the composer (§4.2). Tapping ✕ drops
/// it via [onClear]; the user keeps composing text or picks another from "+".
class _PendingImagePreview extends StatelessWidget {
  const _PendingImagePreview({required this.bytes, required this.onClear});
  final Uint8List bytes;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              bytes,
              width: 96,
              height: 96,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: theme.colorScheme.surface.withValues(alpha: 0.8),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onClear,
                child: Tooltip(
                  message: AppLocalizations.of(context).actionRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 18),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The inline audio-recording bar shown above the composer (§4.2). Idle (no
/// [phase]) it offers "Start recording"; while capturing it shows a live
/// indicator — a pulsing dot, an elapsing timer, and a status label — plus
/// Pause/Resume and Stop. Owns its own ticker + pulse (pure View concerns); the
/// logical phase is driven from state via [phase].
class _AudioRecordBar extends StatefulWidget {
  const _AudioRecordBar({
    required this.phase,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  /// Null ⇒ idle (revealed, not yet recording).
  final AudioRecordingPhase? phase;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  @override
  State<_AudioRecordBar> createState() => _AudioRecordBarState();
}

class _AudioRecordBarState extends State<_AudioRecordBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  /// Ticks once a second while recording; cancelled (freezing the display) while
  /// paused or idle.
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.phase == AudioRecordingPhase.recording) _sync();
  }

  @override
  void didUpdateWidget(_AudioRecordBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase == widget.phase) return;
    // A fresh recording (from idle) restarts the clock at zero; resuming from a
    // pause keeps the accumulated time.
    if (widget.phase == AudioRecordingPhase.recording &&
        oldWidget.phase != AudioRecordingPhase.paused) {
      _elapsed = Duration.zero;
    }
    _sync();
  }

  /// Reconcile the ticker + pulse with the current [widget.phase].
  void _sync() {
    if (widget.phase == AudioRecordingPhase.recording) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _elapsed += const Duration(seconds: 1));
      });
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _ticker?.cancel();
      _ticker = null;
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  static String _format(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final phase = widget.phase;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: phase == null
            ? _idle(theme, l10n)
            : _recording(theme, l10n, phase),
      ),
    );
  }

  Widget _idle(ThemeData theme, AppLocalizations l10n) => Row(
    children: [
      const SizedBox(width: 8),
      Icon(Icons.mic_none, color: theme.colorScheme.primary),
      const SizedBox(width: 10),
      Expanded(child: Text(l10n.collectionAudioMessage)),
      TextButton.icon(
        onPressed: widget.onStart,
        icon: const Icon(Icons.fiber_manual_record, color: Color(0xFFE53935)),
        label: Text(l10n.collectionAudioStart),
      ),
    ],
  );

  Widget _recording(
    ThemeData theme,
    AppLocalizations l10n,
    AudioRecordingPhase phase,
  ) {
    final recording = phase == AudioRecordingPhase.recording;
    return Row(
      children: [
        const SizedBox(width: 8),
        _PulsingDot(animation: _pulse, active: recording),
        const SizedBox(width: 10),
        Text(
          _format(_elapsed),
          style: theme.textTheme.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          recording
              ? l10n.collectionAudioRecording
              : l10n.collectionAudioPaused,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: recording
              ? l10n.collectionAudioPause
              : l10n.collectionAudioResume,
          icon: Icon(recording ? Icons.pause : Icons.play_arrow),
          onPressed: recording ? widget.onPause : widget.onResume,
        ),
        IconButton.filledTonal(
          tooltip: l10n.collectionAudioStop,
          icon: const Icon(Icons.stop),
          onPressed: widget.onStop,
        ),
      ],
    );
  }
}

/// A small dot that pulses (fades in/out) while [active], or sits dimmed and
/// still when paused — the at-a-glance "recording is happening" cue (§4.2).
class _PulsingDot extends StatelessWidget {
  const _PulsingDot({required this.animation, required this.active});
  final Animation<double> animation;
  final bool active;

  static const Color _color = Color(0xFFE53935); // red 600

  @override
  Widget build(BuildContext context) {
    const dot = SizedBox(
      width: 12,
      height: 12,
      child: DecoratedBox(
        decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
      ),
    );
    if (!active) {
      return Opacity(opacity: 0.4, child: dot);
    }
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.25).animate(animation),
      child: dot,
    );
  }
}

/// The recorded-but-unsent audio clip shown above the composer (§4.2) — the
/// audio twin of [_PendingImagePreview]. Tapping ✕ drops it via [onClear]; the
/// user can add a caption first, then send.
class _PendingAudioPreview extends StatelessWidget {
  const _PendingAudioPreview({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.mic, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(l10n.collectionAudioMessage)),
            IconButton(
              tooltip: l10n.actionRemove,
              icon: const Icon(Icons.close),
              onPressed: onClear,
            ),
          ],
        ),
      ),
    );
  }
}

/// The picked-but-unsent file shown above the composer (§4.2) — the file twin of
/// [_PendingAudioPreview]. Shows the file's name; tapping ✕ drops it via
/// [onClear]. The user can add a caption first, then send.
class _PendingFilePreview extends StatelessWidget {
  const _PendingFilePreview({required this.name, required this.onClear});
  final String name;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              tooltip: AppLocalizations.of(context).actionRemove,
              icon: const Icon(Icons.close),
              onPressed: onClear,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddBlockSheet extends StatelessWidget {
  const _AddBlockSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.link),
            title: Text(l10n.collectionBlockLink),
            subtitle: Text(l10n.collectionBlockLinkSubtitle),
            onTap: () => Navigator.of(context).pop(CardKind.link),
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: Text(l10n.collectionBlockPhoto),
            onTap: () => Navigator.of(context).pop(CardKind.image),
          ),
          ListTile(
            leading: const Icon(Icons.mic_none),
            title: Text(l10n.collectionBlockAudio),
            onTap: () => Navigator.of(context).pop(CardKind.audio),
          ),
          ListTile(
            leading: const Icon(Icons.attach_file),
            title: Text(l10n.collectionBlockFile),
            onTap: () => Navigator.of(context).pop(CardKind.file),
          ),
        ],
      ),
    );
  }
}

class _CardActionsSheet extends StatelessWidget {
  const _CardActionsSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(l10n.collectionActionEdit),
            onTap: () => Navigator.of(context).pop(_CardAction.edit),
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: Text(l10n.collectionActionMakeLink),
            onTap: () => Navigator.of(context).pop(_CardAction.link),
          ),
          ListTile(
            leading: const Icon(Icons.hub_outlined),
            title: Text(l10n.collectionActionConnections),
            onTap: () => Navigator.of(context).pop(_CardAction.connections),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: Text(l10n.collectionActionShare),
            onTap: () => Navigator.of(context).pop(_CardAction.share),
          ),
          ListTile(
            leading: const Icon(Icons.swap_vert),
            title: Text(l10n.collectionActionReorder),
            onTap: () => Navigator.of(context).pop(_CardAction.reorder),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text(
              l10n.collectionActionDelete,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () => Navigator.of(context).pop(_CardAction.delete),
          ),
        ],
      ),
    );
  }
}

/// Two-level link finder (§4.4): browse collections, link to one directly, or
/// drill into it to link to any card. Levels load lazily, so the sheet observes
/// the controller's state (collections + a per-collection card cache) and
/// dispatches drill loads; selecting a target pops the chosen [LinkOption] back
/// to the page, which dispatches the link write.
class _LinkFinderSheet extends StatefulWidget {
  const _LinkFinderSheet({
    required this.controller,
    required this.sourceCardId,
    required this.currentCollectionId,
  });

  final CollectionController controller;

  /// The card being linked — dropped from the drilled card list (no self-link).
  final String sourceCardId;

  /// The source card's own collection — its direct "link to collection" action
  /// is hidden (a card→its-own-collection link is meaningless), but it can still
  /// be drilled into to link to a sibling card.
  final String currentCollectionId;

  @override
  State<_LinkFinderSheet> createState() => _LinkFinderSheetState();
}

class _LinkFinderSheetState extends State<_LinkFinderSheet> {
  /// The collection currently drilled into; null ⇒ the collections list.
  String? _drilledId;

  void _drill(LinkOption collection) {
    setState(() => _drilledId = collection.id);
    widget.controller.dispatch(LinkCollectionOpened(collection.id));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: ValueListenableBuilder<CollectionState>(
          valueListenable: widget.controller.stateHolder,
          builder: (context, state, _) {
            final drilledId = _drilledId;
            if (drilledId == null) return _collectionsList(state);
            return _cardsList(state, drilledId);
          },
        ),
      ),
    );
  }

  Widget _collectionsList(CollectionState state) {
    final l10n = AppLocalizations.of(context);
    final collections = state.linkCollections;
    if (collections == null) {
      return const _SheetSpinner();
    }
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
              c.label.trim().isEmpty ? l10n.labelUntitled : c.label.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (c.id != widget.currentCollectionId)
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

  Widget _cardsList(CollectionState state, String collectionId) {
    final l10n = AppLocalizations.of(context);
    final collection = _collectionFor(state, collectionId);
    final label = (collection?.label.trim().isNotEmpty ?? false)
        ? collection!.label.trim()
        : l10n.labelUntitled;
    final cached = state.linkCardsByCollection[collectionId];
    final cards = cached
        ?.where((o) => o.id != widget.sourceCardId)
        .toList(growable: false);

    return ListView(
      shrinkWrap: true,
      children: [
        ListTile(
          leading: const Icon(Icons.arrow_back),
          title: Text(l10n.collectionBackToCollections),
          onTap: () => setState(() => _drilledId = null),
        ),
        const Divider(height: 1),
        // The collection itself is a valid target — unless it's the source
        // card's own collection (a card→own-collection link is meaningless).
        if (collection != null && collectionId != widget.currentCollectionId)
          ListTile(
            leading: const Icon(Icons.workspaces_outline),
            title: Text(
              l10n.collectionLinkToCollection(label),
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

  static LinkOption? _collectionFor(CollectionState state, String id) {
    for (final c in state.linkCollections ?? const <LinkOption>[]) {
      if (c.id == id) return c;
    }
    return null;
  }
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

/// The "no cards yet" hint shown beneath the title card on an empty collection
/// (§4.2). Top-aligned (not vertically centred) so it composes as a list item
/// under the header card.
class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).collectionEmptyTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).collectionEmptyBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).actionRetry),
            ),
          ],
        ),
      ),
    );
  }
}
