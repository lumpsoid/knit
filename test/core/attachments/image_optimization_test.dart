import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/attachments/domain/image_optimization.dart';

void main() {
  group('targetSize', () {
    test('a photo within the limit keeps its size', () {
      expect(ImageOptimization.targetSize(1600, 1200), (
        width: 1600,
        height: 1200,
      ));
    });

    test('a large photo fits its long edge to the limit, aspect kept', () {
      expect(ImageOptimization.targetSize(4032, 3024), (
        width: 2048,
        height: 1536,
      ));
      expect(ImageOptimization.targetSize(3024, 4032), (
        width: 1536,
        height: 2048,
      ));
    });

    test('a thin strip never drops below one pixel', () {
      expect(ImageOptimization.targetSize(10000, 1), (width: 2048, height: 1));
    });
  });

  test('transparency keeps PNG, opaque goes to JPEG', () {
    expect(
      ImageOptimization.formatFor(hasAlpha: true),
      OptimizedImageFormat.png,
    );
    expect(
      ImageOptimization.formatFor(hasAlpha: false),
      OptimizedImageFormat.jpeg,
    );
  });

  test('only decodable, still formats can be optimized', () {
    expect(ImageOptimization.canOptimize('image/jpeg'), isTrue);
    expect(ImageOptimization.canOptimize('IMAGE/PNG'), isTrue);
    expect(ImageOptimization.canOptimize('image/gif'), isFalse);
    expect(ImageOptimization.canOptimize('image/heic'), isFalse);
  });

  test('a result is kept only when it saves at least a tenth', () {
    expect(
      ImageOptimization.worthKeeping(originalBytes: 1000, optimizedBytes: 900),
      isTrue,
    );
    expect(
      ImageOptimization.worthKeeping(originalBytes: 1000, optimizedBytes: 901),
      isFalse,
    );
  });
}
