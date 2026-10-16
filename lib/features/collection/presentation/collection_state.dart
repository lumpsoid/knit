import 'package:flutter/foundation.dart';
import 'package:knit/core/attachments/domain/picked_audio.dart';
import 'package:knit/core/attachments/domain/picked_file.dart';
import 'package:knit/core/attachments/domain/picked_image.dart';
import 'package:knit/features/collection/domain/collection_models.dart';

enum CollectionStatus { loading, ready, failed }

/// Whether an audio message is actively being captured, and if so its sub-state
/// (§4.2). Null (the field is nullable) ⇒ no recording in flight: either the bar
/// is idle/hidden or a recorded clip is already staged in [CollectionState.pendingAudio].
enum AudioRecordingPhase { recording, paused }

/// Where the move picker's list of target collections stands. [idle] until the
/// user asks to move the selection; the picker shows a spinner while [loading].
enum MoveTargetsStatus { idle, loading, ready, failed }

/// State for the Collection screen (§4.2). [reordering] is the *mode* of this
/// screen (drag-to-reorder), not a separate screen — exactly as the spec frames
/// it. Sheets/dialogs (compose, add-block, actions, link picker, edit) are transient
/// View concerns that dispatch intents; they are not modelled here. The header
/// (title, description, cover) is the shared collection details, not a copy here.
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
    this.pendingImage,
    this.recordingPhase,
    this.pendingAudio,
    this.pendingFile,
    this.selectedCardIds = const {},
    this.moveTargetsStatus = MoveTargetsStatus.idle,
    this.moveTargets = const [],
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

  /// An image the user picked from the composer's "+" and is still composing a
  /// caption for, held in memory and shown as a preview above the input field.
  /// It is not stored or attached to any card until the composer is sent;
  /// clearing or repicking just drops these bytes — no attachment is written.
  final PickedImage? pendingImage;

  /// The live audio-capture sub-state (§4.2): non-null while recording or paused,
  /// driving the recording controls above the composer. Null once stopped — the
  /// captured clip then lives in [pendingAudio].
  final AudioRecordingPhase? recordingPhase;

  /// An audio message the user recorded but hasn't sent yet — the audio twin of
  /// [pendingImage]. Held in memory and shown as a preview chip; the user can add
  /// a caption before sending. Clearing it just drops these bytes — no attachment
  /// is written until the composer is sent.
  final PickedAudio? pendingAudio;

  /// A file the user picked but hasn't sent yet — the file twin of [pendingImage].
  /// Held in memory and shown as a preview chip (its name); the user can add a
  /// caption before sending. Clearing it just drops these bytes — no attachment
  /// is written until the composer is sent.
  final PickedFile? pendingFile;

  /// The cards picked in multi-select mode (§4.2), by id. Selection mode *is*
  /// a non-empty set: deselecting the last card leaves it, so an empty
  /// selection mode can't exist.
  final Set<String> selectedCardIds;

  /// The move picker's targets: every other live collection, most recently
  /// updated first. Meaningful once [moveTargetsStatus] is ready.
  final MoveTargetsStatus moveTargetsStatus;
  final List<MoveTarget> moveTargets;

  /// Whether multi-select mode is active.
  bool get selecting => selectedCardIds.isNotEmpty;

  /// Whether an audio recording is actively being captured (not merely staged).
  bool get isRecordingAudio => recordingPhase != null;

  /// Whether the composer's send goes through with [text]: never while a
  /// recording is in flight (the user stops it first); otherwise a non-blank
  /// [text] or a staged image, audio clip, or file (which makes an empty
  /// caption a valid send).
  bool canSendComposer(String text) =>
      !isRecordingAudio &&
      (text.trim().isNotEmpty ||
          pendingImage != null ||
          pendingAudio != null ||
          pendingFile != null);

  bool get isEmpty => cards.isEmpty && !hasOlder;

  /// Whether older cards exist beyond the loaded window.
  bool get hasOlder => olderBoundary != null;

  bool get canReorder => cards.length > 1;

  CollectionState copyWith({
    CollectionStatus? status,
    String? collectionId,
    List<FeedCard>? cards,
    FeedCursor? olderBoundary,
    bool clearOlderBoundary = false,
    bool? loadingOlder,
    int? connectionCount,
    bool? reordering,
    PickedImage? pendingImage,
    bool clearPendingImage = false,
    AudioRecordingPhase? recordingPhase,
    bool clearRecordingPhase = false,
    PickedAudio? pendingAudio,
    bool clearPendingAudio = false,
    PickedFile? pendingFile,
    bool clearPendingFile = false,
    Set<String>? selectedCardIds,
    MoveTargetsStatus? moveTargetsStatus,
    List<MoveTarget>? moveTargets,
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
    // Nullable fields: the matching `clear…` flag drops them (the `?? this`
    // idiom can't express "set to null").
    pendingImage: clearPendingImage
        ? null
        : (pendingImage ?? this.pendingImage),
    recordingPhase: clearRecordingPhase
        ? null
        : (recordingPhase ?? this.recordingPhase),
    pendingAudio: clearPendingAudio
        ? null
        : (pendingAudio ?? this.pendingAudio),
    pendingFile: clearPendingFile ? null : (pendingFile ?? this.pendingFile),
    selectedCardIds: selectedCardIds ?? this.selectedCardIds,
    moveTargetsStatus: moveTargetsStatus ?? this.moveTargetsStatus,
    moveTargets: moveTargets ?? this.moveTargets,
  );
}
