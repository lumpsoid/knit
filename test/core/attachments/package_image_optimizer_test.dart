import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:knit/core/attachments/attachments.dart';

/// A [width]×[height] photo-like image: a gradient with sensor-like noise, so
/// the encoders can't squash it to nothing.
img.Image _photo(int width, int height, {int channels = 3}) {
  final random = Random(7);
  final image = img.Image(width: width, height: height, numChannels: channels);
  for (final pixel in image) {
    final noise = random.nextInt(24);
    pixel
      ..r = (pixel.x * 255 ~/ width + noise) % 256
      ..g = (pixel.y * 255 ~/ height + noise) % 256
      ..b = noise * 11 % 256;
    if (channels == 4) pixel.a = pixel.x < width ~/ 2 ? 128 : 255;
  }
  return image;
}

void main() {
  const optimizer = PackageImageOptimizer();

  test('a large photo is scaled to fit and re-encoded as JPEG', () async {
    final original = PickedImage(
      bytes: img.encodePng(_photo(3000, 2000)),
      mime: 'image/png',
    );
    final optimized = await optimizer.optimize(original);
    expect(optimized, isNotNull);
    expect(optimized!.mime, 'image/jpeg');
    expect(optimized.bytes.length, lessThan(original.bytes.length));
    final decoded = img.decodeImage(optimized.bytes)!;
    expect((decoded.width, decoded.height), (1600, 1067));
  });

  test('a see-through image stays PNG', () async {
    final original = PickedImage(
      bytes: img.encodePng(_photo(3000, 1000, channels: 4)),
      mime: 'image/png',
    );
    final optimized = await optimizer.optimize(original);
    expect(optimized?.mime, 'image/png');
  });

  test('the EXIF orientation is baked into the pixels', () async {
    final photo = _photo(3000, 1000)..exif.imageIfd.orientation = 6;
    final original = PickedImage(
      bytes: img.encodeJpg(photo, quality: 100),
      mime: 'image/jpeg',
    );
    final optimized = await optimizer.optimize(original);
    final decoded = img.decodeImage(optimized!.bytes)!;
    expect((decoded.width, decoded.height), (533, 1600));
    expect(decoded.exif.imageIfd.hasOrientation, isFalse);
  });

  group('metadata', () {
    PickedImage cameraPhoto() {
      final photo = _photo(3000, 2000);
      photo.exif.imageIfd['Make'] = 'Pixel';
      photo.exif.imageIfd.orientation = 1;
      // GPS tags have no names in package:image; 1 is GPSLatitudeRef.
      photo.exif.gpsIfd[1] = img.IfdValueAscii('N');
      return PickedImage(
        bytes: img.encodeJpg(photo, quality: 100),
        mime: 'image/jpeg',
      );
    }

    test('is kept by default, minus the orientation', () async {
      final optimized = await optimizer.optimize(cameraPhoto());
      final exif = img.decodeJpgExif(optimized!.bytes)!;
      expect(exif.imageIfd['Make']?.toString(), 'Pixel');
      expect(exif.gpsIfd[1]?.toString(), 'N');
      expect(exif.imageIfd.hasOrientation, isFalse);
    });

    test('is dropped when the setting says so', () async {
      final stripping = PackageImageOptimizer(keepMetadata: () => false);
      final optimized = await stripping.optimize(cameraPhoto());
      final exif = img.decodeJpgExif(optimized!.bytes);
      expect(exif == null || exif.isEmpty, isTrue);
    });
  });

  test('an already small photo is left alone', () async {
    final original = PickedImage(
      bytes: img.encodeJpg(_photo(64, 64), quality: 60),
      mime: 'image/jpeg',
    );
    expect(await optimizer.optimize(original), isNull);
  });

  test('unreadable bytes and unsupported formats give nothing', () async {
    expect(
      await optimizer.optimize(
        PickedImage(bytes: Uint8List.fromList([1, 2, 3]), mime: 'image/jpeg'),
      ),
      isNull,
    );
    expect(
      await optimizer.optimize(
        PickedImage(
          bytes: img.encodeGif(_photo(3000, 2000)),
          mime: 'image/gif',
        ),
      ),
      isNull,
    );
  });
}
