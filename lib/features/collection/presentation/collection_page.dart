import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:knit/l10n/app_localizations.dart';
import 'package:knit/core/attachments/domain/image_picker_port.dart';
import 'package:knit/features/card_edit/presentation/card_edit_page.dart';
import 'package:knit/features/card_links/domain/card_links_models.dart';
import 'package:knit/features/card_links/presentation/link_picker_sheet.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_page.dart';
import 'package:knit/features/audio_playback/presentation/audio_mini_player.dart';
import 'package:knit/features/audio_playback/presentation/audio_playback_controller.dart';
import 'package:knit/features/collection/presentation/collection_action.dart';
import 'package:knit/features/collection/presentation/collection_controller.dart';
import 'package:knit/features/collection/presentation/collection_scope.dart';
import 'package:knit/features/collection/presentation/collection_state.dart';
import 'package:knit/features/collection/presentation/collection_ui_effect.dart';
import 'package:knit/features/collection/presentation/image_gallery_page.dart';
import 'package:knit/features/collection/presentation/widgets/add_block_sheet.dart';
import 'package:knit/features/collection/presentation/widgets/card_actions_sheet.dart';
import 'package:knit/features/collection/presentation/widgets/card_bubble.dart';
import 'package:knit/features/collection/presentation/widgets/card_connections_badge.dart';
import 'package:knit/features/collection/presentation/widgets/card_reorder_row.dart';
import 'package:knit/features/collection/presentation/widgets/collection_composer.dart';
import 'package:knit/features/collection/presentation/widgets/collection_error_view.dart';
import 'package:knit/features/collection/presentation/widgets/collection_feed.dart';
import 'package:knit/features/collection/presentation/widgets/collection_title_card.dart';
import 'package:knit/features/collection/presentation/widgets/move_target_sheet.dart';
import 'package:knit/features/collection/presentation/widgets/selectable_card_row.dart';
import 'package:knit/features/collection/presentation/widgets/text_prompt_dialog.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/features/connections/presentation/connections_page.dart';

/// The Collection screen (§4.2) — a chat-style card feed (oldest at top), a
/// bottom composer, a "+" add-block sheet, per-card actions, and drag-to-reorder
/// as a *mode* of this screen. The feed's own view state (animated list,
/// scrolling, paging, focus reveal) lives in [CollectionFeed].
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

  /// A card the route args asked to reveal on entry (e.g. a search hit). The
  /// feed reveals it when it first appears.
  late final String? _focusCardId = CollectionScope.routeArgs.focusCardId;

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

  @override
  void initState() {
    super.initState();
    _controller = CollectionScope.create()
      ..onAttach(_onUiEffect)
      ..dispatch(
        ViewAttached(
          CollectionScope.routeArgs.collectionId,
          focusCardId: _focusCardId,
        ),
      );
  }

  @override
  void dispose() {
    // Leaving the collection stops playback so audio doesn't trail the user out
    // (the player itself is an app-wide singleton — only the clip is released).
    unawaited(_playback.close());
    // Cancel any in-flight recording, then tear down the page-owned controller
    // (detaches the effect seam and disposes the state-holder notifier).
    _controller
      ..dispatch(const DeactivateFeature())
      ..dispose();
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
      case CollectionCardsMovedUiEffect(
        :final count,
        :final targetCollectionId,
        :final targetTitle,
      ):
        final l10n = AppLocalizations.of(context);
        // The snackbar outlives the page if the user leaves first; only a
        // still-mounted page opens the target (in its place on the stack).
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.collectionCardsMoved(count, targetTitle)),
            action: SnackBarAction(
              label: l10n.collectionCardsMovedOpen,
              onPressed: () => _openMovedTarget(targetCollectionId),
            ),
          ),
        );
    }
  }

  /// Open the collection the cards just moved into, replacing this page.
  void _openMovedTarget(String collectionId) {
    if (!mounted) return;
    CollectionScope.collectionRouteArgsWriter.open(collectionId);
    Navigator.of(context).pushReplacement(CollectionPage.route());
  }

  // --- intents ---------------------------------------------------------------

  void _submitComposer() {
    final text = _composer.text;
    // Keep the typed text when the send wouldn't go through (e.g. mid-recording).
    if (!_controller.stateHolder.value.canSendComposer(text)) return;
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
      builder: (_) => const AddBlockSheet(),
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
    final action = await showModalBottomSheet<CardAction>(
      context: context,
      builder: (_) => const CardActionsSheet(),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case CardAction.edit:
        await _openCardEdit(card);
      case CardAction.delete:
        _controller.dispatch(CardDeleteRequested(card.id));
      case CardAction.link:
        await _openLinkFinder(card);
      case CardAction.connections:
        await _openConnections(
          kind: ConnectedEntityKind.card,
          id: card.id,
          title: _cardLabel(AppLocalizations.of(context), card),
        );
      case CardAction.share:
        _controller.dispatch(CardShareRequested(card.id));
      case CardAction.reorder:
        _controller.dispatch(const StartReorder());
    }
  }

  /// Open the move picker over the selection: load the targets, let the user
  /// choose one, then move the selected cards there.
  Future<void> _openMovePicker() async {
    _controller.dispatch(const MoveTargetsRequested());
    final target = await showModalBottomSheet<MoveTarget>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ValueListenableBuilder<CollectionState>(
        valueListenable: _controller.stateHolder,
        builder: (context, state, _) => MoveTargetSheet(
          status: state.moveTargetsStatus,
          targets: state.moveTargets,
        ),
      ),
    );
    if (target == null || !mounted) return;
    _controller.dispatch(MoveTargetChosen(target));
  }

  /// Hand the card to the Card Edit carrier (cross_feature.md §2), then navigate
  /// to the dedicated edit page (§4.3). On return, resync from the projection so
  /// the saved change shows in the feed (projection-is-truth — no push needed).
  Future<void> _openCardEdit(FeedCard card) async {
    CollectionScope.cardEditRouteArgsWriter.open(
      cardId: card.id,
      collectionId: _controller.stateHolder.value.collectionId,
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
          heroTag: imageHeroTag(c.id),
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
          GalleryImage(bytes: bytes, heroTag: coverHeroTag(collectionId)),
        ],
      ),
    );
  }

  /// Hand the focused entity to the Connections carrier (cross_feature.md §2),
  /// then navigate (§4.4). The carrier is the payload — navigation stays empty.
  /// On return, resync: a link cleared there changes the connection badges.
  Future<void> _openConnections({
    required ConnectedEntityKind kind,
    required String id,
    required String title,
  }) async {
    CollectionScope.connectionsRouteArgsWriter.open(
      kind: kind,
      id: id,
      title: title,
    );
    await Navigator.of(context).push(ConnectionsPage.route());
    if (mounted) _controller.dispatch(const ReloadRequested());
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

  /// Open the shared link picker for [card]: link directly to a collection or
  /// drill in to pick any card (§4.4); each level loads lazily.
  Future<void> _openLinkFinder(FeedCard card) async {
    final picked = await LinkPickerSheet.show(
      context,
      links: CollectionScope.cardLinks,
      source: LinkSource(
        cardId: card.id,
        collectionId: _controller.stateHolder.value.collectionId,
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
    String? hint,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) =>
          TextPromptDialog(title: title, action: action, hint: hint),
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
        // System back leaves selection mode before it leaves the page.
        return PopScope(
          canPop: !state.selecting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _controller.dispatch(const SelectionCleared());
          },
          child: Scaffold(
            appBar: state.selecting
                ? _selectionAppBar(l10n, state)
                : AppBar(
                    title: Text(l10n.collectionAppBarTitle),
                    actions: [
                      if (state.status == CollectionStatus.ready &&
                          state.canReorder)
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
                if (!state.reordering && !state.selecting)
                  CollectionComposer(
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
                    onPickFromCamera: () =>
                        _pickImage(ImagePickerSource.camera),
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
          ),
        );
      },
    );
  }

  /// The app bar while cards are selected: a "✕" to leave, the count, and the
  /// bulk actions (select all, move).
  AppBar _selectionAppBar(AppLocalizations l10n, CollectionState state) =>
      AppBar(
        leading: IconButton(
          tooltip: l10n.collectionClearSelectionTooltip,
          icon: const Icon(Icons.close),
          onPressed: () => _controller.dispatch(const SelectionCleared()),
        ),
        title: Text(l10n.collectionSelectedCount(state.selectedCardIds.length)),
        actions: [
          if (state.selectedCardIds.length < state.cards.length)
            IconButton(
              tooltip: l10n.collectionSelectAllTooltip,
              icon: const Icon(Icons.select_all),
              onPressed: () => _controller.dispatch(const AllCardsSelected()),
            ),
          IconButton(
            tooltip: l10n.collectionMoveTooltip,
            icon: const Icon(Icons.drive_file_move_outline),
            onPressed: _openMovePicker,
          ),
        ],
      );

  Widget _body(CollectionState state) {
    switch (state.status) {
      case CollectionStatus.loading:
        if (state.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return _feed(state);
      case CollectionStatus.failed:
        return CollectionErrorView(
          message: AppLocalizations.of(context).collectionLoadError,
          onRetry: () => _controller.dispatch(const ReloadRequested()),
        );
      case CollectionStatus.ready:
        // The title card heads the feed even when there are no cards yet, so a
        // brand-new collection can still be opened to edit its title/cover.
        return _feed(state);
    }
  }

  Widget _feed(CollectionState state) => CollectionFeed(
    cards: state.cards,
    hasOlder: state.hasOlder,
    loadingOlder: state.loadingOlder,
    reordering: state.reordering,
    focusCardId: _focusCardId,
    header: _titleCard(state),
    cardBuilder: _cardRow,
    reorderRowBuilder: (card, index) => CardReorderRow(
      key: ValueKey(card.id),
      card: card,
      index: index,
      imageBytes: _bytesFor(card),
    ),
    onLoadOlder: () => _controller.dispatch(const OlderCardsRequested()),
    onRefresh: () => _controller.dispatch(const ReloadRequested()),
    onReorder: (oldIndex, newIndex) =>
        _controller.dispatch(CardMoved(oldIndex, newIndex)),
  );

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
        return CollectionTitleCard(
          title: title,
          description: header?.description,
          hasCover: coverId != null,
          coverBytes: coverBytes,
          coverHeroTag: coverHeroTag(state.collectionId),
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
  Widget _cardRow(FeedCard card) {
    final bytes = _bytesFor(card);
    final audioId = card.kind == CardKind.audio ? card.attachmentId : null;
    final bubble = CardBubble(
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
              CardConnectionsBadge(
                count: card.connectionCount,
                onTap: () => _openConnections(
                  kind: ConnectedEntityKind.card,
                  id: card.id,
                  title: _cardLabel(AppLocalizations.of(context), card),
                ),
              ),
            ],
          );
    // A long-press anywhere on the row starts (or extends) multi-select.
    void toggle() => _controller.dispatch(CardSelectionToggled(card.id));
    final selection = _controller.stateHolder.value.selectedCardIds;
    if (selection.isNotEmpty) {
      // While selecting, a tap anywhere on the row toggles it: the inner tap
      // targets (bubble, image, link, badge) are switched off.
      return SelectableCardRow(
        selected: selection.contains(card.id),
        onTap: toggle,
        child: IgnorePointer(child: item),
      );
    }
    // The whole feed row — not just the bubble — opens the card-actions
    // sheet: a tap on the empty space beside a short bubble lands here.
    // Inner tap targets (bubble, image, link, badge) still win the arena.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openCardActions(card),
      onLongPress: toggle,
      child: item,
    );
  }

  /// The cached decoded bytes for a card's image, if any (null ⇒ placeholder).
  static Uint8List? _bytesFor(FeedCard card) {
    final id = card.attachmentId;
    return id == null ? null : CollectionScope.images.of(id);
  }
}
