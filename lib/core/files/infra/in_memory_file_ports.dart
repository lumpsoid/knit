import 'dart:typed_data';

import 'package:knit/core/files/domain/domain.dart';
import 'package:result_dart/result_dart.dart';

/// In-memory [FileDeliveryPort] for tests/dev — captures the last shared file
/// instead of touching the OS share sheet.
class RecordingFileDeliveryPort implements FileDeliveryPort {
  OutgoingFile? lastShared;

  @override
  Future<Result<void, FileFailure>> share(OutgoingFile file) async {
    lastShared = file;
    return const Ok<void, FileFailure>(null);
  }
}

/// In-memory [FileSourcePort] for tests/dev — returns preset [bytes] (or
/// `null` to simulate a cancel) instead of opening the file picker.
class StubFileSourcePort implements FileSourcePort {
  StubFileSourcePort([this.bytes]);

  Uint8List? bytes;

  /// The extensions of the last [pick].
  List<String>? lastExtensions;

  @override
  Future<Result<Uint8List?, FileFailure>> pick({
    List<String>? extensions,
  }) async {
    lastExtensions = extensions;
    return Ok<Uint8List?, FileFailure>(bytes);
  }
}

/// In-memory [FileSavePort] for tests/dev — captures the last saved file and
/// reports it as saved ([saved] = `false` simulates a cancelled dialog).
class RecordingFileSavePort implements FileSavePort {
  RecordingFileSavePort({this.saved = true});

  OutgoingFile? lastSaved;
  bool saved;

  @override
  Future<Result<bool, FileFailure>> save(OutgoingFile file) async {
    lastSaved = file;
    return Ok<bool, FileFailure>(saved);
  }
}
