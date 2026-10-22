import 'package:flutter/foundation.dart';
import 'package:knit/core/ownership/collection_ownership.dart';
import 'package:knit/features/card_links/domain/card_links_models.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/domain/collection_outline.dart';

enum CollectionStatus { loading, ready, failed }

/// Where the move picker's list of target collections stands. [idle] until the
/// user asks to move the selection; the picker shows a spinner while [loading].
enum MoveTargetsStatus { idle, loading, ready, failed }

/// Where the Outline sheet's list stands (§4.2). [idle] until the user opens
/// it; the sheet shows a spinner while [loading].
enum OutlineStatus { idle, loading, ready, failed }

/// State for the Collection screen (§4.2). [reordering] is the *mode* of this
/// screen (drag-to-reorder), not a separate screen — exactly as the spec frames
/// it. Sheets/dialogs (compose, add-block, actions, link picker, edit) are transient
/// View concerns that dispatch intents; they are not modelled here. The header
/// (title, description, cover) is the shared collection details, not a copy here.
/// What the composer holds (staged attachments, the recording) is its own
/// `CollectionComposerState`.
@immutable
class CollectionState {
  const CollectionState({
    this.status = CollectionStatus.loading,
    this.collectionId = '',
    this.cards = const [],
    this.olderBoundary,
    this.loadingOlder = false,
    this.connectionCount = 0,
    this.reordering = false,
    this.selectedCardIds = const {},
    this.moveTargetsStatus = MoveTargetsStatus.idle,
    this.moveTargets = const [],
    this.moveRecents = const [],
    this.moveCardIds = const {},
    this.quickInput = false,
    this.ownership = CollectionOwnership.own,
    this.ownerHandle,
    this.outlineStatus = OutlineStatus.idle,
    this.outline = const [],
    this.focus,
  });

  final CollectionStatus status;
  final String collectionId;

  /// The loaded window of the feed, oldest → newest. A large collection is
  /// held as its newest end only; older cards page in on scroll (§8.7).
  final List<FeedCard> cards;

  /// Key of the newest *unloaded* card older than [cards]; null once [cards]
  /// reaches the head of the feed. Bounds a reorder to the top of the window.
  final FeedCursor? olderBoundary;

  /// Whether an older page is in flight (dedupes scroll-triggered requests).
  final bool loadingOlder;

  /// How many links the collection itself takes part in (§4.4) — shown as a
  /// badge on the title card. Zero ⇒ no badge.
  final int connectionCount;

  /// Whether drag-to-reorder mode is active (§4.2).
  final bool reordering;

  /// The cards picked in multi-select mode (§4.2), by id. Selection mode *is*
  /// a non-empty set: deselecting the last card leaves it, so an empty
  /// selection mode can't exist.
  final Set<String> selectedCardIds;

  /// The move picker's targets: every other live collection, most recently
  /// updated first. Meaningful once [moveTargetsStatus] is ready.
  final MoveTargetsStatus moveTargetsStatus;
  final List<MoveTarget> moveTargets;

  /// The picker's "Recent" row: up to three of [moveTargets] recently moved
  /// into, most recent first (device-local, like pins). Empty ⇒ no row.
  final List<MoveTarget> moveRecents;

  /// The cards the open move picker moves: the selection, or the one card
  /// whose actions sheet asked. Empty when no move is under way.
  final Set<String> moveCardIds;

  /// Opened from a home-screen widget's quick input: a sent text that is a
  /// bare URL becomes a link card, and the page leaves once the card is saved.
  final bool quickInput;

  /// Whose the collection is. An imported one is read-only: no composer,
  /// reorder, selection or header edit (docs/collection_share.md).
  final CollectionOwnership ownership;

  /// The creator's `nickname#fingerprint` when [ownership] is imported.
  final String? ownerHandle;

  /// The Outline (§4.2): the collection's emphasized cards, every one, in
  /// feed order. Meaningful once [outlineStatus] is ready.
  final OutlineStatus outlineStatus;
  final List<OutlineEntry> outline;

  /// The card the feed should reveal and highlight (an entry focus or an
  /// Outline jump); null when none. It may name a card not loaded yet: the
  /// load that reaches it is in flight, and the feed reveals it on arrival.
  final FeedFocus? focus;

  /// Whether cards and the header may be written here.
  bool get canEdit => ownership.canEdit;

  /// Whether multi-select mode is active.
  bool get selecting => selectedCardIds.isNotEmpty;

  /// Whether every selected card is settled, so the selection's action reads
  /// "Unsettle" (§3.3).
  bool get selectionAllSettled => SettleChange.allSettled(_selectedCards);

  /// Whether every selected card is emphasized, so the selection's action
  /// reads "Unemphasize" (§3.3).
  bool get selectionAllEmphasized =>
      EmphasisChange.allEmphasized(_selectedCards);

  /// What copying the selection puts on the clipboard: the selected cards'
  /// texts in feed order, one per line; empty when none has text.
  String get selectionCopyText => CardsCopyText.of(_selectedCards);

  /// What the selection's "Link to…" links from (§4.2): the selected cards,
  /// in feed order, each by the [LinkSource] rule.
  LinkSelection get linkSelection => LinkSelection(
    cardIds: [for (final c in _selectedCards) c.id],
    collectionId: collectionId,
  );

  Iterable<FeedCard> get _selectedCards =>
      cards.where((c) => selectedCardIds.contains(c.id));

  /// Whether "select all" would add anything: some loaded card is unselected.
  bool get canSelectAll => selectedCardIds.length < cards.length;

  bool get isEmpty => cards.isEmpty && !hasOlder;

  /// Whether older cards exist beyond the loaded window.
  bool get hasOlder => olderBoundary != null;

  bool get canReorder => canEdit && cards.length > 1;

  CollectionState copyWith({
    CollectionStatus? status,
    String? collectionId,
    List<FeedCard>? cards,
    FeedCursor? olderBoundary,
    bool clearOlderBoundary = false,
    bool? loadingOlder,
    int? connectionCount,
    bool? reordering,
    Set<String>? selectedCardIds,
    MoveTargetsStatus? moveTargetsStatus,
    List<MoveTarget>? moveTargets,
    List<MoveTarget>? moveRecents,
    Set<String>? moveCardIds,
    bool? quickInput,
    CollectionOwnership? ownership,
    String? ownerHandle,
    OutlineStatus? outlineStatus,
    List<OutlineEntry>? outline,
    FeedFocus? focus,
  }) => CollectionState(
    status: status ?? this.status,
    collectionId: collectionId ?? this.collectionId,
    cards: cards ?? this.cards,
    olderBoundary: clearOlderBoundary
        ? null
        : (olderBoundary ?? this.olderBoundary),
    loadingOlder: loadingOlder ?? this.loadingOlder,
    connectionCount: connectionCount ?? this.connectionCount,
    reordering: reordering ?? this.reordering,
    selectedCardIds: selectedCardIds ?? this.selectedCardIds,
    moveTargetsStatus: moveTargetsStatus ?? this.moveTargetsStatus,
    moveTargets: moveTargets ?? this.moveTargets,
    moveRecents: moveRecents ?? this.moveRecents,
    moveCardIds: moveCardIds ?? this.moveCardIds,
    quickInput: quickInput ?? this.quickInput,
    ownership: ownership ?? this.ownership,
    ownerHandle: ownerHandle ?? this.ownerHandle,
    outlineStatus: outlineStatus ?? this.outlineStatus,
    outline: outline ?? this.outline,
    focus: focus ?? this.focus,
  );
}
