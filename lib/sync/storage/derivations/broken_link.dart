/// Broken-link resolution — spec §8.6.1 / §8.6.2. A read-time derivation, never
/// synced and never signed: a link's endpoints are resolved against the live
/// projection, and a missing-or-tombstoned endpoint marks the link broken. The
/// link itself is never auto-deleted (spec §8.6.1).
library;

import 'package:knit/core/storage/domain/storage_context.dart';
import 'package:knit/sync/snapshot.dart';
import 'package:knit/sync/storage/projection/domain/projection_storage.dart';

/// Liveness of a link's two endpoints (spec §8.6.1). Drives the broken-link chip
/// (§4.8): a link with either end broken renders broken (offer repair/clear),
/// but is never removed. For a backlink (§8.6.2) the relevant end is the
/// **source** — a backlink with a tombstoned/missing source renders broken too.
class LinkEndpointStatus {
  const LinkEndpointStatus({
    required this.sourceBroken,
    required this.targetBroken,
  });

  /// The link's `source_*` endpoint is missing or tombstoned.
  final bool sourceBroken;

  /// The link's `target_*` endpoint is missing or tombstoned.
  final bool targetBroken;

  /// Either end broken → render the broken-link chip (spec §8.6.1).
  bool get isBroken => sourceBroken || targetBroken;
}

/// The §8.6.1 endpoint rule, as a pure decision: an endpoint is broken when its
/// projection row is absent or carries a tombstone (`deleted=1`).
bool endpointBroken(Snapshot? endpoint) => endpoint == null || endpoint.deleted;

/// Resolves a link's endpoint liveness against a [ProjectionStorage] (spec
/// §8.6.1). Reads each endpoint's row via its `*_type` table — never the link
/// row itself — so the chip reflects the *current* projection, not the link's
/// own (possibly stale) view of its ends.
class BrokenLinkResolver {
  const BrokenLinkResolver(this._projection);

  final ProjectionStorage _projection;

  /// Resolve both endpoints of [link]. [link] is expected to be a live link
  /// (`deleted=0`); callers get live links from
  /// [ProjectionStorage.backlinks]/[ProjectionStorage.linksOut].
  Future<LinkEndpointStatus> resolve(
    Snapshot link, {
    StorageContext? ctx,
  }) async {
    assert(link.type == EntityType.link, 'broken-link resolution is link-only');
    final source = await _endpoint(
      link.content['source_type'] as String,
      link.content['source_id'] as String,
      ctx: ctx,
    );
    final target = await _endpoint(
      link.content['target_type'] as String,
      link.content['target_id'] as String,
      ctx: ctx,
    );
    return LinkEndpointStatus(
      sourceBroken: endpointBroken(source),
      targetBroken: endpointBroken(target),
    );
  }

  Future<Snapshot?> _endpoint(
    String typeTag,
    String id, {
    StorageContext? ctx,
  }) => _projection.get(EntityType.fromTag(typeTag), id, ctx: ctx);
}
