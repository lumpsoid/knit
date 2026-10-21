import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

const String _manifestEntry = 'manifest.json';
const String _logEntry = 'log.jsonl';
const String _blobsPrefix = 'blobs/';

/// The entries of a signed-log zip, the shape the backup bundle and the
/// collection share file both use:
/// - `manifest.json` — the format header ([manifest])
/// - `log.jsonl` — one signed PersistedOp row per line, verbatim ([opLines])
/// - `blobs/<content_hash>` — raw attachment bytes ([blobs])
/// - any [extras]: further JSON text entries by name (the backup's
///   `identity.json`)
class LogArchiveEntries {
  const LogArchiveEntries({
    required this.manifest,
    required this.opLines,
    required this.blobs,
    this.extras = const {},
  });

  final Map<String, Object?> manifest;
  final List<String> opLines;
  final Map<String, Uint8List> blobs;
  final Map<String, String> extras;
}

/// Pure zip (de)serialization of [LogArchiveEntries] — `package:archive` is
/// pure Dart, so it runs verbatim in unit tests. The callers check the
/// manifest's format and version.
abstract final class LogArchive {
  static Uint8List encode(LogArchiveEntries entries) {
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(_manifestEntry, jsonEncode(entries.manifest)),
      )
      ..addFile(ArchiveFile.string(_logEntry, entries.opLines.join('\n')));
    entries.extras.forEach((name, text) {
      archive.addFile(ArchiveFile.string(name, text));
    });
    entries.blobs.forEach((hash, bytes) {
      archive.addFile(ArchiveFile.bytes('$_blobsPrefix$hash', bytes));
    });
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// Decode a zip, reading the [extras] entries by name when present. Throws
  /// [FormatException] when the bytes are not a valid zip or the manifest is
  /// missing or not a JSON object.
  static LogArchiveEntries decode(
    Uint8List zip, {
    Set<String> extras = const {},
  }) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zip);
    } catch (e) {
      throw const FormatException('not a valid zip archive');
    }

    final manifestFile = archive.findFile(_manifestEntry);
    if (manifestFile == null) {
      throw const FormatException('missing manifest.json');
    }
    final Object? manifest;
    try {
      manifest = jsonDecode(utf8.decode(manifestFile.content));
    } on FormatException {
      throw const FormatException('malformed manifest.json');
    }
    if (manifest is! Map<String, Object?>) {
      throw const FormatException('malformed manifest.json');
    }

    final logFile = archive.findFile(_logEntry);
    final opLines = logFile == null
        ? const <String>[]
        : const LineSplitter()
              .convert(utf8.decode(logFile.content))
              .where((line) => line.trim().isNotEmpty)
              .toList(growable: false);

    final blobs = <String, Uint8List>{};
    for (final file in archive.files) {
      if (!file.name.startsWith(_blobsPrefix)) continue;
      final hash = file.name.substring(_blobsPrefix.length);
      if (hash.isEmpty) continue;
      final bytes = file.readBytes();
      if (bytes == null) continue;
      blobs[hash] = bytes;
    }

    return LogArchiveEntries(
      manifest: manifest,
      opLines: opLines,
      blobs: blobs,
      extras: {
        for (final name in extras)
          if (archive.findFile(name) case final file?)
            name: utf8.decode(file.content),
      },
    );
  }
}
