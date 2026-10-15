import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/backup/infra/backup_archive_codec.dart';

void main() {
  const codec = BackupArchiveCodec();

  BackupManifest manifest({
    String format = kBackupFormat,
    int version = kBackupVersion,
  }) => BackupManifest(
    format: format,
    version: version,
    createdAtMs: 123,
    author: 'abcd1234',
    opCount: 2,
    blobCount: 1,
  );

  test('round-trips manifest, op lines, and blobs', () {
    final opLines = ['{"a":1}', '{"b":2}'];
    final blobs = {
      'hash1': Uint8List.fromList([1, 2, 3, 4]),
    };

    final bytes = codec.encode(
      manifest: manifest(),
      opLines: opLines,
      blobs: blobs,
    );
    final parsed = codec.decode(bytes);

    expect(parsed.manifest.format, kBackupFormat);
    expect(parsed.manifest.version, kBackupVersion);
    expect(parsed.manifest.author, 'abcd1234');
    expect(parsed.opLines, opLines);
    expect(parsed.blobs.keys, ['hash1']);
    expect(parsed.blobs['hash1'], [1, 2, 3, 4]);
  });

  test('round-trips an empty bundle (no ops, no blobs)', () {
    final bytes = codec.encode(
      manifest: manifest(),
      opLines: const [],
      blobs: const {},
    );
    final parsed = codec.decode(bytes);

    expect(parsed.opLines, isEmpty);
    expect(parsed.blobs, isEmpty);
  });

  test('decode rejects bytes that are not a zip', () {
    expect(
      () => codec.decode(Uint8List.fromList([1, 2, 3, 4, 5])),
      throwsFormatException,
    );
  });

  test('decode rejects a zip without a manifest', () {
    final archive = Archive()..addFile(ArchiveFile.string('log.jsonl', 'x'));
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));

    expect(() => codec.decode(bytes), throwsFormatException);
  });

  test('decode rejects an unrecognized format', () {
    final bytes = codec.encode(
      manifest: manifest(format: 'something-else'),
      opLines: const [],
      blobs: const {},
    );

    expect(() => codec.decode(bytes), throwsFormatException);
  });

  test('decode rejects a future bundle version', () {
    final bytes = codec.encode(
      manifest: manifest(version: kBackupVersion + 1),
      opLines: const [],
      blobs: const {},
    );

    expect(() => codec.decode(bytes), throwsFormatException);
  });
}
