import 'dart:typed_data';

import 'package:knit/core/relay/domain/publication_snapshot.dart';
import 'package:knit/core/relay/domain/relay_failure.dart';
import 'package:result_dart/result_dart.dart';

/// A freshly created relay topic plus the owner's WRITE token (relay §2.1). The
/// token is opaque and capability-only — it names a grant on the relay and is
/// what every subsequent publish/blob call authenticates with.
class RelayTopic {
  const RelayTopic({required this.topicId, required this.writeToken});

  final String topicId;
  final String writeToken;
}

/// A published collection's web address + state (relay §2.6 response). [url] is
/// absolute, ready to share; [slug] is its stable public address at `/c/<slug>`.
class PublishedRef {
  const PublishedRef({
    required this.slug,
    required this.url,
    required this.visibility,
    required this.revoked,
    required this.publishedAt,
  });

  final String slug;
  final String url;
  final PublishVisibility visibility;
  final bool revoked;
  final int publishedAt;
}

/// Narrow client port for the relay's publish + blob API (relay §2.6,
/// business_logic.md §5). One method per endpoint; every fallible call returns a
/// [Result] so the caller never sees a thrown transport/HTTP error.
///
/// The relay is a dumb op router — these endpoints are the one place it accepts
/// a rendered view of a collection ([putPublication]) and its image bytes
/// ([putBlob]) for the web view, keyed by the opaque write token.
abstract interface class RelayPublishClient {
  /// `POST /v1/topics` — create a topic bound to [ownerPubkey], returning the
  /// owner's write token (relay §2.1).
  Future<Result<RelayTopic, RelayFailure>> createTopic(String ownerPubkey);

  /// `PUT /v1/topics/:topic/blobs/:hash` — upload content-addressed [bytes]
  /// (relay §7.7). The relay verifies `sha256(bytes) == hash`.
  Future<Result<void, RelayFailure>> putBlob({
    required String topic,
    required String writeToken,
    required String hash,
    required String mime,
    required Uint8List bytes,
  });

  /// `PUT /v1/topics/:topic/publication` — publish/update the web [snapshot] and
  /// set [visibility] (relay §2.6). Returns the public address.
  Future<Result<PublishedRef, RelayFailure>> putPublication({
    required String topic,
    required String writeToken,
    required PublishVisibility visibility,
    String? title,
    required PublicationSnapshot snapshot,
  });

  /// `GET /v1/topics/:topic/publication` — the current publication state, or
  /// `null` when the collection has never been published (relay §2.6).
  Future<Result<PublishedRef?, RelayFailure>> getPublication({
    required String topic,
    required String writeToken,
  });

  /// `DELETE /v1/topics/:topic/publication` — take the web page offline
  /// (relay §2.6). The `/c/:slug` link goes dead.
  Future<Result<void, RelayFailure>> deletePublication({
    required String topic,
    required String writeToken,
  });
}
