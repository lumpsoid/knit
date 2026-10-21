/// The format an optimised photo is re-encoded as.
enum OptimizedImageFormat {
  jpeg('image/jpeg'),
  png('image/png');

  const OptimizedImageFormat(this.mime);
  final String mime;
}

/// The rules for the opt-in "Optimise size" of a photo added to a card. Pure:
/// the [ImageOptimizerPort] adapter does the pixel work and asks these.
///
/// A photo is scaled down to fit [maxEdge] on its long side and re-encoded:
/// JPEG at [jpegQuality] when it is opaque, PNG when it has transparency (JPEG
/// would flatten it). The result is kept only when it saves at least
/// [minSavingRatio] of the original, so an already small photo stays as it is.
class ImageOptimization {
  const ImageOptimization._();

  static const int maxEdge = 2048;
  static const int jpegQuality = 82;
  static const double minSavingRatio = 0.1;

  /// Formats the adapter can decode. GIF is left out (only its first frame
  /// would survive), and so is HEIC (no decoder, and it is compact already).
  static const Set<String> optimizableMimes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/bmp',
  };

  static bool canOptimize(String mime) =>
      optimizableMimes.contains(mime.toLowerCase());

  /// The size a [width]×[height] photo is scaled to: fit within [maxEdge],
  /// aspect kept, never enlarged.
  static ({int width, int height}) targetSize(int width, int height) {
    final longEdge = width > height ? width : height;
    if (longEdge <= maxEdge) return (width: width, height: height);
    final scale = maxEdge / longEdge;
    int scaled(int edge) {
      final value = (edge * scale).round();
      return value < 1 ? 1 : value;
    }

    return (width: scaled(width), height: scaled(height));
  }

  static OptimizedImageFormat formatFor({required bool hasAlpha}) =>
      hasAlpha ? OptimizedImageFormat.png : OptimizedImageFormat.jpeg;

  /// Whether an [optimizedBytes] result is worth keeping over the
  /// [originalBytes] it came from.
  static bool worthKeeping({
    required int originalBytes,
    required int optimizedBytes,
  }) => optimizedBytes <= originalBytes * (1 - minSavingRatio);
}
