import 'package:logging/logging.dart';

/// One live card's reference to an attachment — a `(cardId, attachmentId)` pair
/// the migration groups by attachment to find records shared by >1 card.
class CardAttachmentRef {
  const CardAttachmentRef({required this.cardId, required this.attachmentId});

  final String cardId;
  final String attachmentId;
}

/// The signed content of an attachment record the migration copies when it
/// clones a shared record (spec §7.4.8). Primitives only — the sync `Snapshot`
/// never crosses into the use case (business_logic.md §5). The bytes are *not*
/// here: a clone reuses the same `contentHash`, so it shares the existing
/// ref-counted blob and duplicates no data.
class AttachmentRecordContent {
  const AttachmentRecordContent({
    required this.kind,
    required this.mime,
    required this.contentHash,
    required this.size,
    this.name,
  });

  final String kind;
  final String mime;
  final String contentHash;
  final int size;
  final String? name;
}

/// Narrow port for the one-time legacy attachment split (business_logic.md §5).
/// Every read/write goes through the signed local write path, so the split is
/// recorded in the change log and survives a rebuild-from-log (spec §8.9) — it
/// is real history, not a projection-only patch.
abstract interface class LegacyAttachmentMigrationPort {
  /// Every live card that points at an attachment, as `(cardId, attachmentId)`
  /// pairs ordered by `cardId` ascending — so the card kept on a shared record
  /// is deterministic (the earliest-created, since ids are time-ordered §6.1).
  Future<List<CardAttachmentRef>> liveCardAttachmentRefs();

  /// The signed content of the live attachment [attachmentId], or null when it
  /// is missing or soft-deleted (a broken reference — left untouched).
  Future<AttachmentRecordContent?> attachmentContent(String attachmentId);

  /// Mint a fresh attachment record copying [content], returning its new id.
  /// Same `contentHash` ⇒ same ref-counted blob, so no bytes are duplicated.
  Future<String> cloneAttachment(AttachmentRecordContent content);

  /// Point live card [cardId] at [attachmentId] — a signed edit that preserves
  /// the card's other content and its feed placement (spec §8.4).
  Future<void> repointCard(String cardId, String attachmentId);
}

/// Splits every attachment record shared by more than one live card so each
/// card owns its own record — restoring the **1 referent : 1 record** invariant
/// (commit `83a99bc`) for data captured before it held. The fix was forward-only
/// (new captures mint their own record); this heals records already on the
/// device so the per-card GC can reclaim a deleted card's attachment without the
/// reference guard, and `card_edit`'s replace/remove can no longer orphan a
/// sibling that reused the same photo.
///
/// Idempotent: a no-op once every record is uniquely owned, so it is safe to run
/// on every launch. With no relay yet (a single, authoritative device), the
/// fresh ids it mints can never collide with another device's split, so no
/// determinism/merge handling is needed — it is a plain local pass.
class LegacyAttachmentSplitMigration {
  LegacyAttachmentSplitMigration(this._port, {Logger? logger})
    : _log = logger ?? Logger('knit.attachment_migration');

  final LegacyAttachmentMigrationPort _port;
  final Logger _log;

  /// Run the split; returns the number of cards repointed onto a fresh record
  /// (0 when nothing was shared).
  Future<int> run() async {
    final refs = await _port.liveCardAttachmentRefs();

    // Group live cards by the attachment they reference (refs arrive sorted by
    // cardId, so each group's order — and thus which card is kept — is stable).
    final cardsByAttachment = <String, List<String>>{};
    for (final ref in refs) {
      (cardsByAttachment[ref.attachmentId] ??= <String>[]).add(ref.cardId);
    }

    var repointed = 0;
    for (final entry in cardsByAttachment.entries) {
      final cardIds = entry.value;
      if (cardIds.length < 2) continue; // uniquely owned → already 1:1.

      final content = await _port.attachmentContent(entry.key);
      if (content == null) {
        continue; // broken/dangling reference → nothing to split.
      }

      // Keep the first card on the original record; give every other card its
      // own fresh record (same blob, ref-counted) so each ends up 1:1.
      for (final cardId in cardIds.skip(1)) {
        final newId = await _port.cloneAttachment(content);
        await _port.repointCard(cardId, newId);
        repointed++;
      }
    }

    if (repointed > 0) {
      _log.info(
        'Split legacy attachment records: repointed $repointed card(s)',
      );
    }
    return repointed;
  }
}
