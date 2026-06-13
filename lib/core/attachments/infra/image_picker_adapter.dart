import 'package:image_picker/image_picker.dart';
import 'package:knit/core/attachments/domain/image_picker_port.dart';
import 'package:knit/core/attachments/domain/picked_image.dart';

/// [ImagePickerPort] over `package:image_picker`. Reads the picked file's bytes
/// into memory and derives a mime type from its extension (the picker does not
/// surface one). The bytes are handed on to the hashing + blob-store path.
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
  };

  @override
  Future<PickedImage?> pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
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
