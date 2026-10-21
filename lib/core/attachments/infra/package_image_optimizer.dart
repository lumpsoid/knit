import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:knit/core/attachments/domain/image_optimization.dart';
import 'package:knit/core/attachments/domain/image_optimizer_port.dart';
import 'package:knit/core/attachments/domain/picked_image.dart';

/// [ImageOptimizerPort] over pure-Dart `package:image`, so it runs the same on
/// every platform. Decoding and encoding a full-size photo takes a while, so
/// the work runs on a background isolate. The EXIF orientation is baked into
/// the pixels. The rest of the metadata (camera, date, location) is carried
/// over while [keepMetadata] says so (the Settings toggle, read per photo),
/// minus the embedded thumbnail of the original. A PNG result carries none:
/// the encoder doesn't write EXIF.
class PackageImageOptimizer implements ImageOptimizerPort {
  const PackageImageOptimizer({bool Function()? keepMetadata})
    : _keepMetadata = keepMetadata;

  final bool Function()? _keepMetadata;

  @override
  Future<PickedImage?> optimize(PickedImage image) async {
    if (!ImageOptimization.canOptimize(image.mime)) return null;
    final bytes = image.bytes;
    final keepMetadata = _keepMetadata?.call() ?? true;
    return Isolate.run(() => _optimize(bytes, keepMetadata: keepMetadata));
  }

  static PickedImage? _optimize(Uint8List bytes, {required bool keepMetadata}) {
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } on Object {
      return null; // not an image it can read (a decoder may throw on junk)
    }
    if (decoded == null) return null;
    final metadata = keepMetadata
        ? _carriedMetadata(decoded.exif)
        : img.ExifData();
    final oriented = img.bakeOrientation(decoded);
    final size = ImageOptimization.targetSize(oriented.width, oriented.height);
    final resized =
        size.width == oriented.width && size.height == oriented.height
        ? oriented
        : img.copyResize(
            oriented,
            width: size.width,
            height: size.height,
            interpolation: img.Interpolation.average,
          );
    if (metadata.exifIfd.containsKey(_exifImageWidth)) {
      metadata.exifIfd[_exifImageWidth] = resized.width;
    }
    if (metadata.exifIfd.containsKey(_exifImageHeight)) {
      metadata.exifIfd[_exifImageHeight] = resized.height;
    }
    resized.exif = metadata;
    final format = ImageOptimization.formatFor(
      hasAlpha: _isTranslucent(resized),
    );
    final encoded = switch (format) {
      OptimizedImageFormat.jpeg => img.encodeJpg(
        resized,
        quality: ImageOptimization.jpegQuality,
      ),
      OptimizedImageFormat.png => img.encodePng(resized),
    };
    if (!ImageOptimization.worthKeeping(
      originalBytes: bytes.length,
      optimizedBytes: encoded.length,
    )) {
      return null;
    }
    return PickedImage(bytes: encoded, mime: format.mime);
  }

  static const int _exifImageWidth = 0xa002;
  static const int _exifImageHeight = 0xa003;

  /// The original's metadata minus what no longer holds once the pixels are
  /// turned upright and scaled: the orientation and the embedded thumbnail.
  static img.ExifData _carriedMetadata(img.ExifData original) {
    final metadata = img.ExifData.from(original);
    metadata.imageIfd.orientation = null;
    metadata.directories.remove('ifd1');
    return metadata;
  }

  /// Whether any pixel is see-through: many opaque screenshots still carry an
  /// alpha channel, and they can go to JPEG.
  static bool _isTranslucent(img.Image image) {
    if (!image.hasAlpha) return false;
    final opaque = image.maxChannelValue;
    for (final pixel in image) {
      if (pixel.a < opaque) return true;
    }
    return false;
  }
}
