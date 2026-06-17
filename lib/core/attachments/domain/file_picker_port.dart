import 'package:knit/core/attachments/domain/picked_file.dart';

/// Narrow port over the platform file picker (spec §4.2 capture step), kept
/// abstract so features depend on the intent ("pick a file"), not on
/// `package:file_picker`, and tests can substitute a fake.
abstract class FilePickerPort {
  /// Prompt the user to pick a single file of any type. Returns `null` if they
  /// cancel (or if the platform returned no readable bytes).
  Future<PickedFile?> pickFile();
}
