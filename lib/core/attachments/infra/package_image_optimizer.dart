import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:knit/core/attachments/domain/image_optimization.dart';
import 'package:knit/core/attachments/domain/image_optimizer_port.dart';
import 'package:knit/core/attachments/domain/picked_image.dart';

/// [ImageOptimizerPort] over pure-Dart `package:image`, so it runs the same on
/// every platform. Decoding and encoding a full-size photo takes a while, so
/// the work runs on a background isolate. The EXIF orientation is baked into
/// the pixels, and the metadata (camera, location) is not carried over.
class PackageImageOptimizer implements ImageOptimizerPort {
  const PackageImageOptimizer();

  @override
  Future<PickedImage?> optimize(PickedImage image) async {
    if (!ImageOptimization.canOptimize(image.mime)) return null;
    final bytes = image.bytes;
    return Isolate.run(() => _optimize(bytes));
  }

  static PickedImage? _optimize(Uint8List bytes) {
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } on Object {
      return null; // not an image it can read (a decoder may throw on junk)
    }
    if (decoded == null) return null;
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
    resized.exif = img.ExifData();
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
