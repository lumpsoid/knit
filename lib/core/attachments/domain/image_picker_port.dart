import 'package:knit/core/attachments/domain/picked_image.dart';

/// Narrow port over the platform image picker (spec §4.3/§4.8 capture step),
/// kept abstract so features depend on the intent ("pick an image"), not on
/// `package:image_picker`, and tests can substitute a fake.
abstract class ImagePickerPort {
  /// Prompt the user to pick a single image. Returns `null` if they cancel.
  Future<PickedImage?> pickImage();
}
