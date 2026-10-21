import 'package:knit/core/attachments/domain/picked_image.dart';

/// Where a picked image comes from — the camera or the on-device gallery. Kept
/// here (not `package:image_picker`'s `ImageSource`) so features depend on the
/// intent, not the package; the adapter maps it to the platform enum.
enum ImagePickerSource { gallery, camera }

/// Narrow port over the platform image picker (spec §4.3/§4.8 capture step),
/// kept abstract so features depend on the intent ("pick an image"), not on
/// `package:image_picker`, and tests can substitute a fake.
abstract class ImagePickerPort {
  /// Prompt the user to pick a single image from [source]. Returns `null` if
  /// they cancel.
  Future<PickedImage?> pickImage({
    ImagePickerSource source = ImagePickerSource.gallery,
  });

  /// Prompt the user to pick one or more images from the gallery, in the
  /// order they chose them. Returns an empty list if they cancel.
  Future<List<PickedImage>> pickImages();
}
