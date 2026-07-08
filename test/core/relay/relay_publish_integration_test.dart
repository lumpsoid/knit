import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/attachments/domain/attachment_hashing.dart';
import 'package:knit/core/relay/relay.dart';

/// Cross-stack interop check: drives the real [FetchRelayPublishClient] over HTTP
/// against a live Knit relay, proving the mobile client and the Phoenix server
/// agree on the §2.6 contract. Skipped unless `RELAY_URL` is set, e.g.:
///
///   flutter test test/core/relay/relay_publish_integration_test.dart \
///     --dart-define=RELAY_URL=http://localhost:4000
void main() {
  const relayUrl = String.fromEnvironment('RELAY_URL');
  if (relayUrl.isEmpty) {
    // No live relay configured — nothing to check.
    return;
  }

  test('publishes end-to-end against a live relay', () async {
    final client = FetchRelayPublishClient(baseUrl: Uri.parse(relayUrl));

    // 1. create a topic (owner pubkey is opaque to the relay in v1).
    final topic = (await client.createTopic('deadbeef')).getOrThrow();
    expect(topic.topicId, isNotEmpty);
    expect(topic.writeToken, isNotEmpty);

    // 2. upload a content-addressed blob (a tiny 1x1 gif).
    final gif = Uint8List.fromList(base64Decode(
      'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
    ));
    final hash = await sha256Hex(gif);
    final blob = await client.putBlob(
      topic: topic.topicId,
      writeToken: topic.writeToken,
      hash: hash,
      mime: 'image/gif',
      bytes: gif,
    );
    expect(blob.isSuccess, isTrue);

    // 3. publish a public snapshot that references the blob as its cover.
    final published = (await client.putPublication(
      topic: topic.topicId,
      writeToken: topic.writeToken,
      visibility: PublishVisibility.public,
      title: 'Integration',
      snapshot: PublicationSnapshot(
        title: 'Integration',
        cover: SnapshotBlob(hash: hash, mime: 'image/gif'),
        cards: const [
          SnapshotCard(id: 'k1', kind: 'text', text: 'hello from mobile'),
        ],
      ),
    )).getOrThrow();
    expect(published.slug, isNotEmpty);
    expect(published.visibility, PublishVisibility.public);
    expect(published.url, contains('/c/${published.slug}'));

    // 4. read it back — the relay reports the same public state.
    final status = (await client.getPublication(
      topic: topic.topicId,
      writeToken: topic.writeToken,
    )).getOrThrow();
    expect(status, isNotNull);
    expect(status!.slug, published.slug);
    expect(status.visibility, PublishVisibility.public);

    // 5. flip to private, then unpublish.
    final flipped = (await client.putPublication(
      topic: topic.topicId,
      writeToken: topic.writeToken,
      visibility: PublishVisibility.private,
      snapshot: const PublicationSnapshot(title: 'Integration'),
    )).getOrThrow();
    expect(flipped.visibility, PublishVisibility.private);
    expect(flipped.slug, published.slug); // stable slug

    final deleted = await client.deletePublication(
      topic: topic.topicId,
      writeToken: topic.writeToken,
    );
    expect(deleted.isSuccess, isTrue);
  });
}
