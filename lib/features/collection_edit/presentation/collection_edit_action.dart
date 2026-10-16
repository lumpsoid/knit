import 'dart:typed_data';

import 'package:knit/features/collection_media/domain/collection_media_models.dart';

/// Intents + async-result deliveries for the Collection Edit page (fcis.md §6.4).
/// All payloads are scalars (no sync-core types).
sealed class CollectionEditAction {
  const CollectionEditAction();
}

/// View attached for [collectionId] (read from the route-args carrier,
/// cross_feature.md §2) with its current [coverAttachmentId] from the shared
/// collection details. Kicks off loading the cover image bytes when there's a
/// cover.
class ViewAttached extends CollectionEditAction {
  const ViewAttached({required this.collectionId, this.coverAttachmentId});
  final String collectionId;
  final String? coverAttachmentId;
}

/// Save tapped with the composed [title] and [description].
class SaveRequested extends CollectionEditAction {
  const SaveRequested({required this.title, this.description});
  final String title;
  final String? description;
}

/// The details write committed; the page pops (driven by a UI effect from the
/// shell).
class SaveSucceeded extends CollectionEditAction {
  const SaveSucceeded();
}

/// The details write failed; stay on the page so the edit isn't lost.
class SaveFailed extends CollectionEditAction {
  const SaveFailed();
}

// --- cover image -----------------------------------------------------------

/// Add or replace the collection's cover with a photo — opens the image picker,
/// stores the bytes, points the header at the new attachment.
class PickCoverRequested extends CollectionEditAction {
  const PickCoverRequested();
}

/// Remove the collection's cover image.
class RemoveCoverRequested extends CollectionEditAction {
  const RemoveCoverRequested();
}

/// The cover settled, carrying its decoded [bytes] for the preview (null =
/// removed). Used both for the initial load and after a pick/remove, so the
/// section never needs a follow-up reload. The cover id itself lives in the
/// shared collection details.
class CoverResolved extends CollectionEditAction {
  const CoverResolved({this.bytes});
  final Uint8List? bytes;
}

/// A cover edit ended without changing anything (cancelled pick or failure) —
/// drop the busy flag, leave the current cover in place.
class CoverEditEnded extends CollectionEditAction {
  const CoverEditEnded();
}

// --- media summary ---------------------------------------------------------

/// Re-read the media summary — after returning from the Media page, where a
/// card edit may have changed it.
class MediaSummaryReloadRequested extends CollectionEditAction {
  const MediaSummaryReloadRequested();
}

/// The media summary resolved: per-kind [counts] plus the decoded bytes of the
/// newest photos for the thumbnail strip ([previews], newest first; photos whose
/// blob is missing on this device are skipped).
class MediaSummaryLoaded extends CollectionEditAction {
  const MediaSummaryLoaded({required this.counts, required this.previews});
  final MediaCounts counts;
  final List<Uint8List> previews;
}

class DeactivateFeature extends CollectionEditAction {
  const DeactivateFeature();
}
