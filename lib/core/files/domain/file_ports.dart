import 'dart:typed_data';

import 'package:knit/core/files/domain/file_failure.dart';
import 'package:knit/core/files/domain/outgoing_file.dart';
import 'package:result_dart/result_dart.dart';

/// Hands an [OutgoingFile] to the platform so the user can store or send it
/// (the OS share sheet). The one place the system-share dependency lives.
abstract interface class FileDeliveryPort {
  Future<Result<void, FileFailure>> share(OutgoingFile file);
}

/// Saves an [OutgoingFile] to a user-chosen location (a save-file dialog).
/// Returns `true` when saved, `false` when the user cancelled — a cancel is
/// not a failure.
abstract interface class FileSavePort {
  Future<Result<bool, FileFailure>> save(OutgoingFile file);
}

/// Lets the user pick one file and reads its bytes (the file picker). Pass
/// [extensions] (without dots) to filter, or null for any file. Returns
/// `null` when the user cancels — a cancel is not a failure.
abstract interface class FileSourcePort {
  Future<Result<Uint8List?, FileFailure>> pick({List<String>? extensions});
}
