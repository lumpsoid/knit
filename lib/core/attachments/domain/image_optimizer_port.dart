import 'package:knit/core/attachments/domain/picked_image.dart';

/// Narrow port that shrinks a photo before it is stored (the opt-in "Optimise
/// size", following [ImageOptimization]'s rules). Kept abstract so features
/// depend on the intent, not on `package:image`, and tests can substitute a
/// fake.
abstract class ImageOptimizerPort {
  /// A smaller copy of [image], or `null` when it can't be read or the result
  /// would not be meaningfully smaller (the caller then keeps the original).
  Future<PickedImage?> optimize(PickedImage image);
}
