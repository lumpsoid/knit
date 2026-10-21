import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:knit/core/attachments/domain/image_picker_port.dart';
import 'package:knit/core/attachments/domain/picked_image.dart';

/// [ImagePickerPort] that keeps gallery photos byte-for-byte original. A gallery
/// pick goes through `package:file_picker` (no compression), which hands back
/// the original file — `package:image_picker` always decodes and re-encodes on
/// iOS (HEIC → JPEG, HDR/depth/Live Photo data dropped), shrinking the photo.
/// The camera stays on `package:image_picker`: a fresh shot has no original
/// file to preserve. Either way the bytes are read into memory and a mime type
/// is derived from the extension (neither picker surfaces one), then handed on
/// to the hashing + blob-store path.
class ImagePickerAdapter implements ImagePickerPort {
  ImagePickerAdapter({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const Map<String, String> _mimeByExtension = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'bmp': 'image/bmp',
    'heic': 'image/heic',
    'heif': 'image/heif',
  };

  @override
  Future<PickedImage?> pickImage({
    ImagePickerSource source = ImagePickerSource.gallery,
  }) => switch (source) {
    ImagePickerSource.gallery => _pickFromGallery(),
    ImagePickerSource.camera => _pickFromCamera(),
  };

  Future<PickedImage?> _pickFromGallery() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return PickedImage(bytes: bytes, mime: _mimeOf(file.name));
  }

  @override
  Future<List<PickedImage>> pickImages() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result == null) return const [];
    return [
      for (final file in result.files)
        PickedImage(bytes: await file.readAsBytes(), mime: _mimeOf(file.name)),
    ];
  }

  Future<PickedImage?> _pickFromCamera() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return PickedImage(bytes: bytes, mime: _mimeOf(file.name));
  }

  static String _mimeOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot == -1) return 'application/octet-stream';
    final ext = name.substring(dot + 1).toLowerCase();
    return _mimeByExtension[ext] ?? 'application/octet-stream';
  }
}
