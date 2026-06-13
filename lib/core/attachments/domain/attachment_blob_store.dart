import 'dart:typed_data';

/// The out-of-band, content-addressed byte store for attachment payloads
/// (spec §6.4/§7.4.8: "bytes live on the filesystem", keyed by `content_hash`).
///
/// Bytes never enter a signed op — only the metadata record (kind/mime/
/// content_hash/size) is signed and synced. The store is keyed by the caller-
/// computed `content_hash`, which makes [put] naturally idempotent and lets
/// identical images dedupe to one blob. Abstracted per the storage convention:
/// a filesystem impl for the running app, an in-memory impl for dev/tests, both
/// asserting the same contract.
abstract class AttachmentBlobStore {
  /// Write [bytes] under [contentHash]. Idempotent: writing the same hash again
  /// is a no-op (content-addressed — the bytes are by definition identical).
  Future<void> put(String contentHash, Uint8List bytes);

  /// The bytes stored under [contentHash], or `null` if absent.
  Future<Uint8List?> readBytes(String contentHash);

  /// Whether a blob exists for [contentHash].
  Future<bool> exists(String contentHash);

  /// Remove the blob for [contentHash]. A no-op if it is already absent — the
  /// caller is responsible for ref-counting before deleting a shared blob.
  Future<void> delete(String contentHash);
}
