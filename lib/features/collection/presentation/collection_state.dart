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

/// State for the Collection screen (§4.2). [reordering] is the *mode* of this
/// screen (drag-to-reorder), not a separate screen — exactly as the spec frames
/// it. Sheets/dialogs (compose, add-block, actions, finder, edit) are transient
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
    this.imageBytes = const {},
    this.linkCollections,
    this.linkCardsByCollection = const {},
    this.reordering = false,
    this.pendingImage,
    this.recordingPhase,
    this.pendingAudio,
    this.pendingFile,
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

  /// Decoded bytes of image cards, keyed by `attachment_id`. Content-addressed,
  /// so an id's bytes are immutable — cached here to avoid reloading on every
  /// rebuild (and preserved across feed reloads). Absent ⇒ loading or missing,
  /// which renders the placeholder fallback.
  final Map<String, Uint8List> imageBytes;

  /// Link-finder first level: live collections to link to (§4.4). Null until the
  /// finder is first opened; loaded lazily so opening a collection never reads
  /// every other collection's cards.
  final List<LinkOption>? linkCollections;

  /// Link-finder drilled level: a collection's cards, keyed by collection id.
  /// Filled on drill and reused within the session; the source card is excluded
  /// at render (the cache is source-card-independent). Cleared on feed reload.
  final Map<String, List<LinkOption>> linkCardsByCollection;

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

  /// Whether an audio recording is actively being captured (not merely staged).
  bool get isRecordingAudio => recordingPhase != null;

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
    Map<String, Uint8List>? imageBytes,
    List<LinkOption>? linkCollections,
    Map<String, List<LinkOption>>? linkCardsByCollection,
    bool? reordering,
    PickedImage? pendingImage,
    bool clearPendingImage = false,
    AudioRecordingPhase? recordingPhase,
    bool clearRecordingPhase = false,
    PickedAudio? pendingAudio,
    bool clearPendingAudio = false,
    PickedFile? pendingFile,
    bool clearPendingFile = false,
  }) => CollectionState(
    status: status ?? this.status,
    collectionId: collectionId ?? this.collectionId,
    cards: cards ?? this.cards,
    olderBoundary: clearOlderBoundary
        ? null
        : (olderBoundary ?? this.olderBoundary),
    loadingOlder: loadingOlder ?? this.loadingOlder,
    connectionCount: connectionCount ?? this.connectionCount,
    imageBytes: imageBytes ?? this.imageBytes,
    linkCollections: linkCollections ?? this.linkCollections,
    linkCardsByCollection: linkCardsByCollection ?? this.linkCardsByCollection,
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
  );
}
